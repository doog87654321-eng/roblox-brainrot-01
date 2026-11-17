-- Brainrot Bay: the client.
-- Draws the whole interface over the 3D world: the cash bar, the belt shop,
-- the lock and rebirth buttons, toast notifications and the tsunami banner.
-- It never decides anything: every button press is a request to the server,
-- and every number on screen comes from the server's StateUpdate.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BrainrotCatalog"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local Events = ReplicatedStorage:WaitForChild("BrainrotEvents")
local BuyBrainrotEvent = Events:WaitForChild("BuyBrainrot")
local BuyLockEvent = Events:WaitForChild("BuyLock")
local BuyRebirthEvent = Events:WaitForChild("BuyRebirth")
local NotifyEvent = Events:WaitForChild("Notify")
local StateUpdateEvent = Events:WaitForChild("StateUpdate")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- The shop reads the belt straight from the world: every brainrot walking
-- the conveyor is a model with Uid, CharacterId and Mutation attributes.
local beltFolder = Workspace

local function beltBrainrots()
	local found = {}
	for _, child in ipairs(beltFolder:GetChildren()) do
		if child:IsA("Model") and child:GetAttribute("Placed") == false and child:GetAttribute("Uid") ~= nil then
			table.insert(found, child)
		end
	end
	table.sort(found, function(a, b)
		return a:GetPivot().X < b:GetPivot().X
	end)
	return found
end

--------------------------------------------------------------------------------
-- Interface
--------------------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "BrainrotBayGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui

local function makeLabel(parent, name, text, size, position, textSize, color, align)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Text = text
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	label.TextSize = textSize
	label.Font = Enum.Font.SourceSansBold
	label.TextXAlignment = align or Enum.TextXAlignment.Center
	label.Parent = parent
	return label
end

local function makeButton(parent, name, text, size, position, color)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = text
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = color
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 20
	button.Font = Enum.Font.SourceSansBold
	button.BorderSizePixel = 0
	button.Parent = parent
	return button
end

-- Top bar: cash, income, rebirths. Kept clear of the top-left corner, where
-- Roblox draws its own menu buttons over the play view.
local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.AnchorPoint = Vector2.new(0.5, 0)
topBar.Position = UDim2.new(0.5, 0, 0, 12)
topBar.Size = UDim2.fromOffset(560, 54)
topBar.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
topBar.BackgroundTransparency = 0.25
topBar.BorderSizePixel = 0
topBar.Parent = gui

local cashLabel = makeLabel(topBar, "Cash", "$100", UDim2.fromOffset(180, 54), UDim2.fromOffset(10, 0), 30, Color3.fromRGB(120, 255, 140), Enum.TextXAlignment.Left)
local incomeLabel = makeLabel(topBar, "Income", "+$0/s", UDim2.fromOffset(180, 54), UDim2.fromOffset(195, 0), 24, Color3.fromRGB(255, 220, 100), Enum.TextXAlignment.Left)
local rebirthLabel = makeLabel(topBar, "Rebirths", "x1  •  0 rebirths", UDim2.fromOffset(180, 54), UDim2.fromOffset(380, 0), 24, Color3.fromRGB(140, 220, 255), Enum.TextXAlignment.Left)

-- Title, bottom centre, so the world stays visible above it.
local titleLabel = makeLabel(gui, "Title", "BRAINROT BAY", UDim2.fromOffset(420, 44), UDim2.new(0.5, -210, 1, -180), 34, Color3.fromRGB(255, 235, 120))
titleLabel.TextStrokeTransparency = 0
titleLabel.TextStrokeColor3 = Color3.fromRGB(40, 20, 60)

-- Action buttons: lock the base, rebirth.
local lockButton = makeButton(gui, "LockButton", "🔒 Lock Base ($500)", UDim2.fromOffset(220, 44), UDim2.new(0, 16, 1, -120), Color3.fromRGB(60, 90, 200))
local rebirthButton = makeButton(gui, "RebirthButton", "✨ Rebirth ($25,000)", UDim2.fromOffset(220, 44), UDim2.new(0, 16, 1, -64), Color3.fromRGB(160, 60, 200))

lockButton.MouseButton1Click:Connect(function()
	BuyLockEvent:FireServer()
end)
rebirthButton.MouseButton1Click:Connect(function()
	BuyRebirthEvent:FireServer()
end)

-- The belt shop: one row per brainrot on the conveyor, rebuilt every frame
-- from the models in the world. The cheapest, nearest the exit, is first.
local shopFrame = Instance.new("Frame")
shopFrame.Name = "Shop"
shopFrame.AnchorPoint = Vector2.new(1, 0)
shopFrame.Position = UDim2.new(1, -16, 0, 80)
shopFrame.Size = UDim2.fromOffset(320, 300)
shopFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
shopFrame.BackgroundTransparency = 0.25
shopFrame.BorderSizePixel = 0
shopFrame.Parent = gui

local shopTitle = makeLabel(shopFrame, "ShopTitle", "🛒 ON THE BELT — click to buy!", UDim2.fromOffset(320, 30), UDim2.fromOffset(0, 0), 18, Color3.fromRGB(255, 235, 120))
local shopList = Instance.new("Frame")
shopList.Name = "ShopList"
shopList.Position = UDim2.fromOffset(0, 32)
shopList.Size = UDim2.fromOffset(320, 268)
shopList.BackgroundTransparency = 1
shopList.Parent = shopFrame

local shopRows = {}

local function refreshShop()
	local models = beltBrainrots()
	for index, model in ipairs(models) do
		local uid = model:GetAttribute("Uid")
		local character = Catalog.getById(model:GetAttribute("CharacterId"))
		local mutation = model:GetAttribute("Mutation") or "Normal"
		if character then
			local row = shopRows[index]
			if not row then
				row = Instance.new("TextButton")
				row.Name = "ShopRow"
				row.Size = UDim2.fromOffset(304, 30)
				row.Position = UDim2.fromOffset(8, (index - 1) * 34)
				row.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
				row.TextColor3 = Color3.fromRGB(255, 255, 255)
				row.TextSize = 15
				row.Font = Enum.Font.SourceSansBold
				row.BorderSizePixel = 0
				row.Parent = shopList
				-- Connected once, when the row is made: it reads the uid the
				-- row currently shows, so refreshes never stack connections.
				row:SetAttribute("CurrentUid", "")
				row.MouseButton1Click:Connect(function()
					local currentUid = row:GetAttribute("CurrentUid")
					if currentUid ~= "" then
						BuyBrainrotEvent:FireServer(currentUid)
					end
				end)
				shopRows[index] = row
			end
			row:SetAttribute("CurrentUid", uid)
			local price = Catalog.priceOf(character, mutation)
			local income = Catalog.incomeOf(character, mutation)
			local rarity = Catalog.getRarity(character.Rarity)
			row.Text = character.Name .. "  $" .. income .. "/s  —  " .. Config.formatMoney(price)
			row.BackgroundColor3 = Color3.fromRGB(
				math.floor(rarity.Color.R * 255 * 0.45 + 25),
				math.floor(rarity.Color.G * 255 * 0.45 + 25),
				math.floor(rarity.Color.B * 255 * 0.45 + 25)
			)
		end
	end
	-- Hide rows the belt no longer needs.
	for index = #models + 1, #shopRows do
		shopRows[index].Visible = false
	end
	for index = 1, math.min(#models, #shopRows) do
		shopRows[index].Visible = true
	end
	if #models == 0 then
		shopTitle.Text = "🛒 Belt is empty — more coming!"
	else
		shopTitle.Text = "🛒 ON THE BELT — click to buy!"
	end
end

-- Toasts stack at the top-right, newest on top.
local toastFrame = Instance.new("Frame")
toastFrame.Name = "Toasts"
toastFrame.AnchorPoint = Vector2.new(1, 0)
toastFrame.Position = UDim2.new(1, -16, 0, 396)
toastFrame.Size = UDim2.fromOffset(320, 200)
toastFrame.BackgroundTransparency = 1
toastFrame.Parent = gui

local TOAST_COLORS = {
	info = Color3.fromRGB(50, 90, 160),
	success = Color3.fromRGB(40, 160, 70),
	warn = Color3.fromRGB(200, 120, 30),
	tsunami = Color3.fromRGB(200, 40, 40),
}

local function showToast(title, body, kind)
	local toast = Instance.new("Frame")
	toast.Name = "Toast"
	toast.Size = UDim2.fromOffset(320, 56)
	toast.BackgroundColor3 = TOAST_COLORS[kind] or TOAST_COLORS.info
	toast.BackgroundTransparency = 0.15
	toast.BorderSizePixel = 0
	toast.Parent = toastFrame
	-- Push older toasts down.
	for _, other in ipairs(toastFrame:GetChildren()) do
		if other ~= toast and other:IsA("Frame") then
			other.Position += UDim2.fromOffset(0, 62)
		end
	end
	makeLabel(toast, "ToastTitle", title, UDim2.fromOffset(300, 22), UDim2.fromOffset(10, 4), 18, Color3.fromRGB(255, 255, 255), Enum.TextXAlignment.Left)
	makeLabel(toast, "ToastBody", body, UDim2.fromOffset(300, 28), UDim2.fromOffset(10, 26), 14, Color3.fromRGB(235, 235, 235), Enum.TextXAlignment.Left)
	task.delay(6, function()
		if toast.Parent then
			toast:Destroy()
		end
	end)
end

-- The tsunami banner: a full-width warning across the middle of the screen.
local banner = Instance.new("Frame")
banner.Name = "TsunamiBanner"
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 90)
banner.Size = UDim2.fromOffset(640, 72)
banner.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
banner.BackgroundTransparency = 0.15
banner.BorderSizePixel = 0
banner.Visible = false
banner.Parent = gui

local bannerTitle = makeLabel(banner, "BannerTitle", "🌊 TSUNAMI INCOMING!", UDim2.fromOffset(640, 36), UDim2.fromOffset(0, 4), 30, Color3.fromRGB(255, 255, 255))
local bannerBody = makeLabel(banner, "BannerBody", "Run back to your base!", UDim2.fromOffset(640, 28), UDim2.fromOffset(0, 40), 20, Color3.fromRGB(255, 220, 220))

local tsunamiCountdown = 0

NotifyEvent.OnClientEvent:Connect(function(title, body, kind)
	if kind == "tsunami" then
		banner.Visible = true
		bannerTitle.Text = "🌊 " .. title
		bannerBody.Text = body
		tsunamiCountdown = Config.TSUNAMI_WARNING
	else
		showToast(title, body, kind)
	end
end)

-- Count the warning down, then hide the banner when the wave has passed.
RunService.RenderStepped:Connect(function(dt)
	if tsunamiCountdown > 0 then
		tsunamiCountdown -= dt
		bannerBody.Text = "Run back to your base! Wave in " .. math.ceil(tsunamiCountdown) .. "s"
		if tsunamiCountdown <= 0 then
			bannerTitle.Text = "🌊 THE WAVE IS HERE!"
			bannerBody.Text = "Hold on tight!"
			task.delay(Config.TSUNAMI_SWEEP_TIME + 2, function()
				banner.Visible = false
			end)
		end
	end
end)

--------------------------------------------------------------------------------
-- Server state
--------------------------------------------------------------------------------

StateUpdateEvent.OnClientEvent:Connect(function(state)
	cashLabel.Text = Config.formatMoney(state.Cash)
	incomeLabel.Text = "+" .. Config.formatMoney(state.Income) .. "/s"
	rebirthLabel.Text = "x" .. state.Multiplier .. "  •  " .. state.Rebirths .. " rebirths"
	if state.LockLeft > 0 then
		lockButton.Text = "🔒 Locked (" .. state.LockLeft .. "s)"
	else
		lockButton.Text = "🔒 Lock Base ($500)"
	end
	if state.StealLeft > 0 then
		titleLabel.Text = "BRAINROT BAY  •  steal ready in " .. state.StealLeft .. "s"
	else
		titleLabel.Text = "BRAINROT BAY  •  " .. state.BaseName .. "  •  " .. state.Owned .. "/6 brainrots"
	end
	rebirthButton.Text = "✨ Rebirth (" .. Config.formatMoney(state.RebirthCost) .. ")"
end)

-- The shop follows the belt: rebuild it a few times a second.
local shopTimer = 0
RunService.RenderStepped:Connect(function(dt)
	shopTimer += dt
	if shopTimer >= 0.25 then
		shopTimer = 0
		refreshShop()
	end
end)

refreshShop()
showToast("Welcome to Brainrot Bay!", "Buy brainrots off the belt, fill your base, and run home when the wave comes!", "info")
