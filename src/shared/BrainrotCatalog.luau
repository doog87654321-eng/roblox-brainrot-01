-- BrainrotCatalog: the cast of Brainrot Bay.
-- Every character is original to this game: a name, a rarity, what it earns
-- per second, what it costs, and the colours its body is built from.
-- The server builds each character's 3D model from this data, and the client
-- reads the same table to draw the shop. Rarities climb from Common to Secret;
-- a mutation multiplies both the price and the income of a spawn.

local BrainrotCatalog = {}

-- Rarity ladder, cheapest first. Weight is the spawn chance (out of 1000).
BrainrotCatalog.RARITIES = {
	{ Name = "Common", Weight = 380, Color = Color3.fromRGB(120, 200, 90) },
	{ Name = "Rare", Weight = 260, Color = Color3.fromRGB(70, 140, 255) },
	{ Name = "Epic", Weight = 170, Color = Color3.fromRGB(170, 90, 255) },
	{ Name = "Legendary", Weight = 105, Color = Color3.fromRGB(255, 160, 40) },
	{ Name = "Mythic", Weight = 55, Color = Color3.fromRGB(255, 70, 120) },
	{ Name = "Brainrot God", Weight = 22, Color = Color3.fromRGB(60, 220, 230) },
	{ Name = "Secret", Weight = 8, Color = Color3.fromRGB(25, 25, 30) },
}

-- Mutations rolled when a brainrot spawns on the conveyor.
BrainrotCatalog.MUTATIONS = {
	{ Name = "Normal", Weight = 850, Multiplier = 1, Tint = Color3.fromRGB(255, 255, 255) },
	{ Name = "Golden", Weight = 100, Multiplier = 2, Tint = Color3.fromRGB(255, 215, 0) },
	{ Name = "Diamond", Weight = 40, Multiplier = 5, Tint = Color3.fromRGB(140, 230, 255) },
	{ Name = "Rainbow", Weight = 10, Multiplier = 10, Tint = Color3.fromRGB(255, 120, 200) },
}

-- The cast. Body is the main colour, Belly the front panel, Hat the topper.
-- Price and Income are the Normal-mutation values; mutations multiply both.
BrainrotCatalog.CHARACTERS = {
	{
		Id = "noodle-nibbler",
		Name = "Noodle Nibbler",
		Rarity = "Common",
		Price = 50,
		Income = 2,
		Blurb = "Slurps spaghetti. Judges you silently.",
		Body = Color3.fromRGB(240, 210, 120),
		Belly = Color3.fromRGB(255, 240, 190),
		Hat = "Bowl",
	},
	{
		Id = "sir-bananaphone",
		Name = "Sir Bananaphone",
		Rarity = "Common",
		Price = 100,
		Income = 4,
		Blurb = "Answers every call. It is always a banana.",
		Body = Color3.fromRGB(250, 220, 60),
		Belly = Color3.fromRGB(255, 245, 170),
		Hat = "Crown",
	},
	{
		Id = "capybara-ceo",
		Name = "Capybara CEO",
		Rarity = "Rare",
		Price = 300,
		Income = 10,
		Blurb = "Runs a Fortune 500 pond. Never blinks.",
		Body = Color3.fromRGB(170, 120, 70),
		Belly = Color3.fromRGB(210, 170, 120),
		Hat = "Tie",
	},
	{
		Id = "dj-pickle",
		Name = "DJ Pickle",
		Rarity = "Rare",
		Price = 500,
		Income = 15,
		Blurb = "Drops the beat. And the brine.",
		Body = Color3.fromRGB(90, 180, 70),
		Belly = Color3.fromRGB(160, 220, 120),
		Hat = "Headphones",
	},
	{
		Id = "toilet-tornado",
		Name = "Toilet Tornado",
		Rarity = "Epic",
		Price = 1200,
		Income = 30,
		Blurb = "It spins. It flushes. It remembers.",
		Body = Color3.fromRGB(230, 240, 245),
		Belly = Color3.fromRGB(120, 200, 240),
		Hat = "Swirl",
	},
	{
		Id = "grandmas-wifi",
		Name = "Grandma's WiFi",
		Rarity = "Epic",
		Price = 2000,
		Income = 45,
		Blurb = "Password is 'password'. Signal: eternal.",
		Body = Color3.fromRGB(200, 160, 220),
		Belly = Color3.fromRGB(235, 210, 245),
		Hat = "Bun",
	},
	{
		Id = "shark-in-a-suit",
		Name = "Shark in a Suit",
		Rarity = "Legendary",
		Price = 4500,
		Income = 80,
		Blurb = "Closes deals. Eats the competition. Literally.",
		Body = Color3.fromRGB(90, 130, 180),
		Belly = Color3.fromRGB(220, 230, 240),
		Hat = "Tie",
	},
	{
		Id = "professor-pigeon",
		Name = "Professor Pigeon",
		Rarity = "Legendary",
		Price = 7000,
		Income = 120,
		Blurb = "Holds three PhDs. Coos in Latin.",
		Body = Color3.fromRGB(140, 140, 160),
		Belly = Color3.fromRGB(200, 200, 215),
		Hat = "Mortarboard",
	},
	{
		Id = "infinite-burrito",
		Name = "The Infinite Burrito",
		Rarity = "Mythic",
		Price = 12000,
		Income = 200,
		Blurb = "Every bite regrows. Science cannot explain it.",
		Body = Color3.fromRGB(220, 170, 90),
		Belly = Color3.fromRGB(120, 200, 90),
		Hat = "Foil",
	},
	{
		Id = "quantum-quokka",
		Name = "Quantum Quokka",
		Rarity = "Mythic",
		Price = 20000,
		Income = 320,
		Blurb = "In two places at once. Smiling in both.",
		Body = Color3.fromRGB(190, 140, 100),
		Belly = Color3.fromRGB(240, 210, 170),
		Hat = "Antenna",
	},
	{
		Id = "lord-loo-roll",
		Name = "Lord Loo Roll",
		Rarity = "Brainrot God",
		Price = 45000,
		Income = 600,
		Blurb = "He saw the end of the roll. He is the roll.",
		Body = Color3.fromRGB(245, 245, 245),
		Belly = Color3.fromRGB(180, 220, 250),
		Hat = "Crown",
	},
	{
		Id = "the-algorithm",
		Name = "The Algorithm",
		Rarity = "Secret",
		Price = 100000,
		Income = 1200,
		Blurb = "It knows what you will buy next. It is always right.",
		Body = Color3.fromRGB(30, 30, 40),
		Belly = Color3.fromRGB(80, 255, 170),
		Hat = "Halo",
	},
}

-- Look a character up by its id.
function BrainrotCatalog.getById(id: string)
	for _, character in ipairs(BrainrotCatalog.CHARACTERS) do
		if character.Id == id then
			return character
		end
	end
	return nil
end

-- Look a rarity up by name.
function BrainrotCatalog.getRarity(name: string)
	for _, rarity in ipairs(BrainrotCatalog.RARITIES) do
		if rarity.Name == name then
			return rarity
		end
	end
	return BrainrotCatalog.RARITIES[1]
end

-- Look a mutation up by name.
function BrainrotCatalog.getMutation(name: string)
	for _, mutation in ipairs(BrainrotCatalog.MUTATIONS) do
		if mutation.Name == name then
			return mutation
		end
	end
	return BrainrotCatalog.MUTATIONS[1]
end

-- Pick one entry from a weighted table (each entry carries Weight).
local function pickWeighted(entries)
	local total = 0
	for _, entry in ipairs(entries) do
		total += entry.Weight
	end
	local roll = math.random(1, total)
	local running = 0
	for _, entry in ipairs(entries) do
		running += entry.Weight
		if roll <= running then
			return entry
		end
	end
	return entries[1]
end

-- Roll a random character, weighted toward the cheap rarities.
function BrainrotCatalog.rollCharacter()
	local rarity = pickWeighted(BrainrotCatalog.RARITIES)
	local pool = {}
	for _, character in ipairs(BrainrotCatalog.CHARACTERS) do
		if character.Rarity == rarity.Name then
			table.insert(pool, character)
		end
	end
	if #pool == 0 then
		return BrainrotCatalog.CHARACTERS[1]
	end
	return pool[math.random(1, #pool)]
end

-- Roll a mutation for a fresh spawn.
function BrainrotCatalog.rollMutation()
	return pickWeighted(BrainrotCatalog.MUTATIONS)
end

-- Price and income of a character under a mutation.
function BrainrotCatalog.priceOf(character, mutationName: string): number
	local mutation = BrainrotCatalog.getMutation(mutationName)
	return character.Price * mutation.Multiplier
end

function BrainrotCatalog.incomeOf(character, mutationName: string): number
	local mutation = BrainrotCatalog.getMutation(mutationName)
	return character.Income * mutation.Multiplier
end

-- Short label shown over a brainrot: "Name | RARITY | $12/s".
function BrainrotCatalog.labelFor(character, mutationName: string): string
	local income = BrainrotCatalog.incomeOf(character, mutationName)
	if mutationName == "Normal" then
		return character.Name .. "  |  " .. character.Rarity .. "  |  $" .. income .. "/s"
	end
	return mutationName .. " " .. character.Name .. "  |  " .. character.Rarity .. "  |  $" .. income .. "/s"
end

return BrainrotCatalog
