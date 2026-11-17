-- Brainrot Bay: the server.
-- One script runs the whole game: it spawns brainrots on the conveyor,
-- sells them to players, pays income every second, lets players steal from
-- each other (unless the base is locked), sells base locks and rebirths,
-- and sweeps the map with a tsunami every few minutes.
--
-- State lives here, in playerData, and nowhere else: the client only draws
-- what the server tells it through StateUpdate and Notify.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BrainrotCatalog"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local Events = ReplicatedStorage:WaitForChild("BrainrotEvents")
local BuyBrainrotEvent = Events:WaitForChild("BuyBrainrot")
local BuyLockEvent = Events:WaitForChild("BuyLock")
local BuyRebirthEvent = Events:WaitForChild("BuyRebirth")
local NotifyEvent = Events:WaitForChild("Notify")
local StateUpdateEvent = Events:WaitForChild("StateUpdate")

local BASE_NAMES = { "BaseRed", "BaseBlue", "BaseYellow", "BaseGreen" }
local BASE_COLORS = {
	Color3.fromRGB(220, 50, 50),
	Color3.fromRGB(50, 115, 230),
	Color3.fromRGB(240, 205, 40),
	Color3.fromRGB(50, 180, 75),
}

-- player -> { Cash, Rebirths, Brainrots = { [slot] = entry }, BaseIndex, LockedUntil, LastSteal }
local playerData = {}
-- baseIndex -> player
local baseOwners = {}
-- conveyor entries: { Model, Uid, CharacterId, Mutation, Price, Income, X }
local conveyor = {}
local spawnCounter = 0
local tsunamiRunning = false

--------------------------------------------------------------------------------
-- Small helpers
--------------------------------------------------------------------------------

local function notify(player, title, body, kind)
	NotifyEvent:FireClient(player, title, body, kind or "info")
end

local function notifyAll(title, body, kind)
	NotifyEvent:FireAllClients(title, body, kind or "info")
end

local function slotPosition(baseIndex: number, slot: number): Vector3
	local center = Config.BASE_CENTERS[baseIndex]
	local col = (slot - 1) % 3
	local row = math.floor((slot - 1) / 3)
	return Vector3.new(
		center.X + (col - 1) * Config.SLOT_SPACING_X,
		2.5,
		center.Z + (row - 0.5) * Config.SLOT_SPACING_Z
	)
end

local function isBaseLocked(data): boolean
	return data.LockedUntil > os.time()
end

local function freeSlot(data): number?
	for slot = 1, Config.BASE_SLOTS do
		if data.Brainrots[slot] == nil then
			return slot
		end
	end
	return nil
end

local function ownedIncome(data): number
	local total = 0
	for _, entry in pairs(data.Brainrots) do
		total += entry.Income
	end
	return total * Config.rebirthMultiplier(data.Rebirths)
end

--------------------------------------------------------------------------------
-- Building a brainrot's 3D model from the catalog
--------------------------------------------------------------------------------

-- Hat toppers, each a list of small parts sitting on (or in front of) the head.
-- Offsets are relative to the body centre; the head sits at y 2.6.
local function hatParts(hat: string): { { Size: Vector3, Offset: Vector3, Color: Color3, Shape: string?, Neon: boolean? } }
	if hat == "Crown" then
		return { { Size = Vector3.new(1.8, 0.8, 1.8), Offset = Vector3.new(0, 4.1, 0), Color = Color3.fromRGB(255, 215, 0) } }
	elseif hat == "Tie" then
		return { { Size = Vector3.new(0.6, 1.6, 0.2), Offset = Vector3.new(0, -0.3, 1.15), Color = Color3.fromRGB(220, 40, 40) } }
	elseif hat == "Headphones" then
		return {
			{ Size = Vector3.new(0.5, 1.1, 0.5), Offset = Vector3.new(-1.2, 2.6, 0), Color = Color3.fromRGB(40, 40, 50) },
			{ Size = Vector3.new(0.5, 1.1, 0.5), Offset = Vector3.new(1.2, 2.6, 0), Color = Color3.fromRGB(40, 40, 50) },
			{ Size = Vector3.new(2.9, 0.4, 0.6), Offset = Vector3.new(0, 3.6, 0), Color = Color3.fromRGB(40, 40, 50) },
		}
	elseif hat == "Bowl" then
		return { { Size = Vector3.new(2.4, 0.6, 2.4), Offset = Vector3.new(0, 3.9, 0), Color = Color3.fromRGB(240, 240, 240) } }
	elseif hat == "Swirl" then
		return { { Size = Vector3.new(1.2, 1.2, 1.2), Offset = Vector3.new(0, 4.0, 0), Color = Color3.fromRGB(120, 200, 240), Shape = "Ball", Neon = true } }
	elseif hat == "Bun" then
		return { { Size = Vector3.new(1.1, 1.1, 1.1), Offset = Vector3.new(0, 4.0, 0), Color = Color3.fromRGB(120, 70, 40), Shape = "Ball" } }
	elseif hat == "Mortarboard" then
		return { { Size = Vector3.new(2.8, 0.3, 2.8), Offset = Vector3.new(0, 3.9, 0), Color = Color3.fromRGB(25, 25, 30) } }
	elseif hat == "Foil" then
		return { { Size = Vector3.new(2.4, 0.5, 2.4), Offset = Vector3.new(0, 3.9, 0), Color = Color3.fromRGB(210, 215, 220) } }
	elseif hat == "Antenna" then
		return {
			{ Size = Vector3.new(0.3, 1.6, 0.3), Offset = Vector3.new(0, 4.4, 0), Color = Color3.fromRGB(60, 60, 70) },
			{ Size = Vector3.new(0.8, 0.8, 0.8), Offset = Vector3.new(0, 5.3, 0), Color = Color3.fromRGB(255, 90, 90), Shape = "Ball", Neon = true },
		}
	elseif hat == "Halo" then
		return { { Size = Vector3.new(2.8, 0.3, 2.8), Offset = Vector3.new(0, 4.6, 0), Color = Color3.fromRGB(255, 230, 120), Neon = true } }
	end
	return {}
end

local function makePart(name: string, size: Vector3, offset: Vector3, color: Color3, shape: string?, neon: boolean?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = offset
	part.Color = color
	part.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	if shape == "Ball" then
		part.Shape = Enum.PartType.Ball
	end
	return part
end

-- Build the model for one brainrot. Parts sit around the body centre, so the
-- model can be dropped anywhere with Model:PivotTo.
local function buildBrainrotModel(character, mutationName: string, uid: string): Model
	local mutation = Catalog.getMutation(mutationName)
	local model = Instance.new("Model")
	model.Name = character.Name

	local body = makePart("Body", Vector3.new(3, 3, 2), Vector3.new(0, 0, 0), character.Body)
	body.Parent = model
	model.PrimaryPart = body

	local belly = makePart("Belly", Vector3.new(2.2, 2, 0.2), Vector3.new(0, -0.2, 1.05), character.Belly)
	belly.Parent = model

	local head = makePart("Head", Vector3.new(2.2, 2.2, 2.2), Vector3.new(0, 2.6, 0), character.Body, "Ball")
	head.Parent = model

	local eyeLeft = makePart("EyeLeft", Vector3.new(0.35, 0.5, 0.2), Vector3.new(-0.5, 2.7, 1.05), Color3.fromRGB(20, 20, 20))
	eyeLeft.Parent = model
	local eyeRight = makePart("EyeRight", Vector3.new(0.35, 0.5, 0.2), Vector3.new(0.5, 2.7, 1.05), Color3.fromRGB(20, 20, 20))
	eyeRight.Parent = model

	for _, spec in ipairs(hatParts(character.Hat)) do
		local hatPart = makePart("Hat", spec.Size, spec.Offset, spec.Color, spec.Shape, spec.Neon)
		hatPart.Parent = model
	end

	-- A glowing shell marks mutated brainrots so they read at a glance.
	if mutationName ~= "Normal" then
		local aura = makePart("Aura", Vector3.new(3.6, 6.6, 2.6), Vector3.new(0, 1.2, 0), mutation.Tint, nil, true)
		aura.Transparency = 0.75
		aura.Parent = model
	end

	-- The floating name plate: name, rarity and money per second.
	local label = Instance.new("BillboardGui")
	label.Name = "NamePlate"
	label.Size = UDim2.fromOffset(240, 64)
	label.StudsOffsetWorldSpace = Vector3.new(0, 5.2, 0)
	label.AlwaysOnTop = false
	label.Parent = body

	local labelText = Instance.new("TextLabel")
	labelText.Name = "Label"
	labelText.Size = UDim2.fromScale(1, 1)
	labelText.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	labelText.BackgroundTransparency = 0.25
	labelText.BorderSizePixel = 0
	labelText.TextColor3 = Color3.fromRGB(255, 255, 255)
	labelText.TextScaled = true
	labelText.Font = Enum.Font.SourceSansBold
	labelText.Text = Catalog.labelFor(character, mutationName)
	labelText.Parent = label

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Interact"
	prompt.ActionText = "Buy"
	prompt.ObjectText = character.Name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = body

	model:SetAttribute("Uid", uid)
	model:SetAttribute("CharacterId", character.Id)
	model:SetAttribute("Mutation", mutationName)
	model:SetAttribute("Placed", false)
	return model
end

local function setModelLabel(model: Model, text: string)
	local body = model:FindFirstChild("Body")
	if not body then
		return
	end
	local plate = body:FindFirstChild("NamePlate")
	if not plate then
		return
	end
	local labelText = plate:FindFirstChild("Label")
	if labelText and labelText:IsA("TextLabel") then
		labelText.Text = text
	end
end

local function setModelPrompt(model: Model, actionText: string, objectText: string)
	local body = model:FindFirstChild("Body")
	if not body then
		return
	end
	local prompt = body:FindFirstChild("Interact")
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.ActionText = actionText
		prompt.ObjectText = objectText
	end
end

--------------------------------------------------------------------------------
-- Bases
--------------------------------------------------------------------------------

-- A floating sign over each plot: who owns it, or that it is free.
local baseSigns = {}

local function setupBaseSigns()
	for index, baseName in ipairs(BASE_NAMES) do
		local baseFolder = Workspace:FindFirstChild(baseName)
		if not baseFolder then
			continue
		end
		local pad = baseFolder:FindFirstChild("Pad")
		if not pad then
			continue
		end
		local sign = Instance.new("BillboardGui")
		sign.Name = "BaseSign"
		sign.Size = UDim2.fromOffset(260, 56)
		sign.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
		sign.Parent = pad
		local text = Instance.new("TextLabel")
		text.Name = "Label"
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundColor3 = BASE_COLORS[index]
		text.BackgroundTransparency = 0.2
		text.TextColor3 = Color3.fromRGB(255, 255, 255)
		text.TextScaled = true
		text.Font = Enum.Font.SourceSansBold
		text.Text = "BASE " .. index .. " — FREE"
		text.Parent = sign
		baseSigns[index] = text
	end
end

local function refreshBaseSign(index: number)
	local text = baseSigns[index]
	if not text then
		return
	end
	local owner = baseOwners[index]
	if owner then
		text.Text = "BASE " .. index .. " — " .. owner.DisplayName .. "'s base"
	else
		text.Text = "BASE " .. index .. " — FREE"
	end
end

--------------------------------------------------------------------------------
-- Conveyor
--------------------------------------------------------------------------------

local function spawnBrainrot()
	if #conveyor >= Config.MAX_ON_CONVEYOR then
		return
	end
	spawnCounter += 1
	local character = Catalog.rollCharacter()
	local mutation = Catalog.rollMutation()
	local uid = "BR-" .. tostring(spawnCounter) .. "-" .. tostring(math.random(1000, 9999))
	local price = Catalog.priceOf(character, mutation.Name)
	local income = Catalog.incomeOf(character, mutation.Name)
	local model = buildBrainrotModel(character, mutation.Name, uid)
	model:PivotTo(CFrame.new(Config.CONVEYOR_START_X, 2.5, Config.CONVEYOR_Z))
	setModelLabel(model, Catalog.labelFor(character, mutation.Name) .. "\nBUY " .. Config.formatMoney(price))
	setModelPrompt(model, "Buy " .. Config.formatMoney(price), character.Name)
	model.Parent = Workspace

	local entry = {
		Model = model,
		Uid = uid,
		CharacterId = character.Id,
		Mutation = mutation.Name,
		Price = price,
		Income = income,
		X = Config.CONVEYOR_START_X,
	}
	table.insert(conveyor, entry)

	local prompt = model:FindFirstChild("Body"):FindFirstChild("Interact")
	prompt.Triggered:Connect(function(player)
		onPromptTriggered(player, entry)
	end)
end

-- The belt walks every brainrot from the green pad to the red one; any that
-- reach the end walk off and are gone.
RunService.Heartbeat:Connect(function(dt)
	for index = #conveyor, 1, -1 do
		local entry = conveyor[index]
		if not entry.Model.Parent then
			table.remove(conveyor, index)
		else
			entry.X += Config.CONVEYOR_SPEED * dt
			if entry.X >= Config.CONVEYOR_END_X then
				entry.Model:Destroy()
				table.remove(conveyor, index)
			else
				entry.Model:PivotTo(CFrame.new(entry.X, 2.5, Config.CONVEYOR_Z))
			end
		end
	end
end)

-- A new brainrot rolls in every few seconds, forever.
task.spawn(function()
	while true do
		task.wait(Config.SPAWN_INTERVAL)
		spawnBrainrot()
	end
end)

--------------------------------------------------------------------------------
-- Buying, stealing, locking, rebirthing
--------------------------------------------------------------------------------

-- One entry point for both prompts: buying off the belt, stealing off a base.
function onPromptTriggered(player, entry)
	local data = playerData[player]
	if not data then
		return
	end
	local model = entry.Model
	if not model or not model.Parent then
		return
	end
	if model:GetAttribute("Placed") then
		stealBrainrot(player, entry)
	else
		buyBrainrot(player, entry)
	end
end

function buyBrainrot(player, entry)
	local data = playerData[player]
	if not data then
		return
	end
	if data.BaseIndex == nil then
		notify(player, "No base yet", "All four bases are taken. Wait for a free plot!", "warn")
		return
	end
	local slot = freeSlot(data)
	if slot == nil then
		notify(player, "Base full", "Your base holds 6 brainrots. Rebirth to start over!", "warn")
		return
	end
	if data.Cash < entry.Price then
		notify(player, "Not enough cash", "You need " .. Config.formatMoney(entry.Price) .. " for this one.", "warn")
		return
	end

	-- Take it off the belt.
	for index, other in ipairs(conveyor) do
		if other.Uid == entry.Uid then
			table.remove(conveyor, index)
			break
		end
	end

	data.Cash -= entry.Price
	local character = Catalog.getById(entry.CharacterId)
	data.Brainrots[slot] = entry
	entry.Model:SetAttribute("Placed", true)
	entry.Model:SetAttribute("Owner", player.Name)
	entry.Model:PivotTo(CFrame.new(slotPosition(data.BaseIndex, slot)))
	setModelLabel(entry.Model, Catalog.labelFor(character, entry.Mutation))
	setModelPrompt(entry.Model, "Steal", character.Name .. " (" .. player.DisplayName .. ")")
	updateLeaderstats(player)
	notify(player, "Bought!", character.Name .. " is earning " .. Config.formatMoney(entry.Income) .. "/s on your base.", "success")
end

function stealBrainrot(player, entry)
	local data = playerData[player]
	if not data then
		return
	end
	local ownerName = entry.Model:GetAttribute("Owner")
	local owner = Players:FindFirstChild(ownerName)
	if owner == player then
		notify(player, "Already yours", "That brainrot already lives on your base.", "info")
		return
	end
	if data.BaseIndex == nil then
		notify(player, "No base yet", "You need a base before you can steal one.", "warn")
		return
	end
	local slot = freeSlot(data)
	if slot == nil then
		notify(player, "Base full", "Your base holds 6 brainrots. Make room first!", "warn")
		return
	end
	if os.time() - data.LastSteal < Config.STEAL_COOLDOWN then
		local left = Config.STEAL_COOLDOWN - (os.time() - data.LastSteal)
		notify(player, "Steal cooling down", "Wait " .. left .. "s before your next steal.", "warn")
		return
	end

	local ownerData = owner and playerData[owner] or nil
	if ownerData and isBaseLocked(ownerData) then
		notify(player, "Base locked!", owner.DisplayName .. "'s base is locked. Try another victim!", "warn")
		return
	end

	-- Pull it out of the victim's base.
	if ownerData then
		for victimSlot, victimEntry in pairs(ownerData.Brainrots) do
			if victimEntry.Uid == entry.Uid then
				ownerData.Brainrots[victimSlot] = nil
				break
			end
		end
		if owner then
			updateLeaderstats(owner)
		end
	end

	data.LastSteal = os.time()
	data.Brainrots[slot] = entry
	entry.Model:SetAttribute("Owner", player.Name)
	entry.Model:PivotTo(CFrame.new(slotPosition(data.BaseIndex, slot)))
	local character = Catalog.getById(entry.CharacterId)
	setModelPrompt(entry.Model, "Steal", character.Name .. " (" .. player.DisplayName .. ")")
	updateLeaderstats(player)
	notify(player, "Stolen!", "You swiped " .. character.Name .. " from " .. (owner and owner.DisplayName or "an empty base") .. "!", "success")
	if owner then
		notify(owner, "You were robbed!", player.DisplayName .. " stole your " .. character.Name .. "! Lock your base!", "warn")
	end
end

BuyBrainrotEvent.OnServerEvent:Connect(function(player, uid)
	-- Buying through the HUD button: same rules as the belt prompt.
	local data = playerData[player]
	if not data then
		return
	end
	for _, entry in ipairs(conveyor) do
		if entry.Uid == uid then
			buyBrainrot(player, entry)
			return
		end
	end
	notify(player, "Too slow!", "That brainrot already walked off the belt.", "warn")
end)

BuyLockEvent.OnServerEvent:Connect(function(player)
	local data = playerData[player]
	if not data then
		return
	end
	if data.BaseIndex == nil then
		notify(player, "No base yet", "You need a base before you can lock one.", "warn")
		return
	end
	if data.Cash < Config.LOCK_COST then
		notify(player, "Not enough cash", "A base lock costs " .. Config.formatMoney(Config.LOCK_COST) .. ".", "warn")
		return
	end
	if isBaseLocked(data) then
		notify(player, "Already locked", "Your base is locked for " .. (data.LockedUntil - os.time()) .. "s more.", "info")
		return
	end
	data.Cash -= Config.LOCK_COST
	data.LockedUntil = os.time() + Config.LOCK_DURATION
	updateLeaderstats(player)
	notify(player, "Base locked!", "Nobody can steal from you for " .. Config.LOCK_DURATION .. " seconds.", "success")
end)

BuyRebirthEvent.OnServerEvent:Connect(function(player)
	local data = playerData[player]
	if not data then
		return
	end
	local cost = Config.rebirthCost(data.Rebirths)
	if data.Cash < cost then
		notify(player, "Not enough cash", "Rebirth " .. (data.Rebirths + 1) .. " costs " .. Config.formatMoney(cost) .. ".", "warn")
		return
	end
	for _, entry in pairs(data.Brainrots) do
		if entry.Model and entry.Model.Parent then
			entry.Model:Destroy()
		end
	end
	data.Brainrots = {}
	data.Cash = 0
	data.Rebirths += 1
	updateLeaderstats(player)
	notifyAll(player.DisplayName .. " REBIRTHED!", player.DisplayName .. " now earns x" .. Config.rebirthMultiplier(data.Rebirths) .. " forever!", "success")
end)

--------------------------------------------------------------------------------
-- Income and state
--------------------------------------------------------------------------------

function updateLeaderstats(player)
	local data = playerData[player]
	if not data then
		return
	end
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		return
	end
	local cash = stats:FindFirstChild("Cash")
	if cash then
		cash.Value = math.floor(data.Cash)
	end
	local count = stats:FindFirstChild("Brainrots")
	if count then
		local owned = 0
		for _ in pairs(data.Brainrots) do
			owned += 1
		end
		count.Value = owned
	end
	local rebirths = stats:FindFirstChild("Rebirths")
	if rebirths then
		rebirths.Value = data.Rebirths
	end
end

-- Every second, every brainrot pays its owner.
task.spawn(function()
	while true do
		task.wait(Config.INCOME_TICK)
		for player, data in pairs(playerData) do
			data.Cash += ownedIncome(data)
			updateLeaderstats(player)
		end
	end
end)

-- Every couple of seconds, push the HUD numbers to each player.
task.spawn(function()
	while true do
		task.wait(Config.STATE_PUSH_INTERVAL)
		for player, data in pairs(playerData) do
			local owned = 0
			for _ in pairs(data.Brainrots) do
				owned += 1
			end
			StateUpdateEvent:FireClient(player, {
				Cash = math.floor(data.Cash),
				Income = ownedIncome(data),
				Owned = owned,
				Rebirths = data.Rebirths,
				Multiplier = Config.rebirthMultiplier(data.Rebirths),
				LockLeft = math.max(0, data.LockedUntil - os.time()),
				StealLeft = math.max(0, Config.STEAL_COOLDOWN - (os.time() - data.LastSteal)),
				RebirthCost = Config.rebirthCost(data.Rebirths),
				BaseName = if data.BaseIndex then "BASE " .. data.BaseIndex else "NO BASE",
			})
		end
	end
end)

--------------------------------------------------------------------------------
-- The tsunami
--------------------------------------------------------------------------------

local function insideBase(player, baseIndex: number): boolean
	local character = player.Character
	if not character then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local center = Config.BASE_CENTERS[baseIndex]
	return math.abs(root.Position.X - center.X) <= 13 and math.abs(root.Position.Z - center.Z) <= 13
end

local function runTsunami()
	if tsunamiRunning then
		return
	end
	tsunamiRunning = true
	notifyAll("TSUNAMI INCOMING!", "A giant wave is coming! Run back to your base!", "tsunami")
	task.wait(Config.TSUNAMI_WARNING)

	local wall = Instance.new("Part")
	wall.Name = "TsunamiWall"
	wall.Size = Vector3.new(320, 40, 4)
	wall.Position = Vector3.new(0, 20, -150)
	wall.Color = Color3.fromRGB(25, 115, 220)
	wall.Material = Enum.Material.SmoothPlastic
	wall.Transparency = 0.3
	wall.Anchored = true
	wall.CanCollide = false
	wall.Parent = Workspace

	local sweep = TweenService:Create(
		wall,
		TweenInfo.new(Config.TSUNAMI_SWEEP_TIME, Enum.EasingStyle.Linear),
		{ Position = Vector3.new(0, 20, 140) }
	)
	sweep:Play()

	-- While the wall sweeps, anyone it passes outside their base gets washed
	-- home and loses a slice of cash. The belt is wiped when the wall crosses it.
	local caught = {}
	local beltWashed = false
	local start = os.clock()
	while os.clock() - start < Config.TSUNAMI_SWEEP_TIME + 1 do
		local wallZ = wall.Position.Z
		if not beltWashed and wallZ >= Config.CONVEYOR_Z then
			beltWashed = true
			for index = #conveyor, 1, -1 do
				conveyor[index].Model:Destroy()
				table.remove(conveyor, index)
			end
			notifyAll("The wave hit the belt!", "Every brainrot on the conveyor was washed away!", "warn")
		end
		for player, data in pairs(playerData) do
			if not caught[player] then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root and wallZ >= root.Position.Z - 2 then
					local safe = data.BaseIndex ~= nil and insideBase(player, data.BaseIndex)
					if not safe then
						caught[player] = true
						local lost = math.floor(data.Cash * Config.TSUNAMI_CASH_LOSS)
						data.Cash -= lost
						updateLeaderstats(player)
						local home = Vector3.new(0, 5, 80)
						if data.BaseIndex then
							local center = Config.BASE_CENTERS[data.BaseIndex]
							home = Vector3.new(center.X, 5, center.Z)
						end
						character:PivotTo(CFrame.new(home))
						notify(player, "Washed away!", "The wave caught you! You lost " .. Config.formatMoney(lost) .. ". Get to your base next time!", "warn")
					end
				end
			end
		end
		task.wait(0.2)
	end

	local fade = TweenService:Create(wall, TweenInfo.new(2), { Transparency = 1 })
	fade:Play()
	fade.Completed:Wait()
	wall:Destroy()
	notifyAll("The wave is gone!", "The belt is filling up again. Grab the next brainrot!", "info")
	tsunamiRunning = false
end

-- Waves roll in on a timer, forever.
task.spawn(function()
	while true do
		task.wait(Config.TSUNAMI_INTERVAL)
		runTsunami()
	end
end)

--------------------------------------------------------------------------------
-- Players
--------------------------------------------------------------------------------

local function onPlayerAdded(player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	stats.Parent = player

	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = Config.STARTING_CASH
	cash.Parent = stats

	local count = Instance.new("IntValue")
	count.Name = "Brainrots"
	count.Value = 0
	count.Parent = stats

	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = 0
	rebirths.Parent = stats

	local baseIndex = nil
	for index = 1, #BASE_NAMES do
		if baseOwners[index] == nil then
			baseIndex = index
			baseOwners[index] = player
			break
		end
	end

	playerData[player] = {
		Cash = Config.STARTING_CASH,
		Rebirths = 0,
		Brainrots = {},
		BaseIndex = baseIndex,
		LockedUntil = 0,
		LastSteal = -Config.STEAL_COOLDOWN,
	}
	refreshBaseSign(baseIndex or 1)
	if baseIndex then
		refreshBaseSign(baseIndex)
		notify(player, "Welcome to Brainrot Bay!", "Your base is BASE " .. baseIndex .. ". Grab brainrots off the belt!", "info")
	else
		notify(player, "Welcome to Brainrot Bay!", "All bases are taken right now. Watch the belt and wait for a free plot!", "warn")
	end
end

local function onPlayerRemoving(player)
	local data = playerData[player]
	if not data then
		return
	end
	for _, entry in pairs(data.Brainrots) do
		if entry.Model and entry.Model.Parent then
			entry.Model:Destroy()
		end
	end
	if data.BaseIndex then
		baseOwners[data.BaseIndex] = nil
		refreshBaseSign(data.BaseIndex)
	end
	playerData[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

setupBaseSigns()
for index = 1, #BASE_NAMES do
	refreshBaseSign(index)
end
-- The belt starts with something to look at.
spawnBrainrot()
spawnBrainrot()
