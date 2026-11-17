-- GameConfig: every number that tunes Brainrot Bay, in one place.
-- The server and the client both read this module, so the numbers the HUD
-- shows (lock cost, rebirth price, tsunami timer) are the numbers the
-- server enforces.

local GameConfig = {}

-- A new player starts with this much cash.
GameConfig.STARTING_CASH = 100

-- The conveyor: where brainrots appear, where they leave, how fast they walk.
GameConfig.CONVEYOR_START_X = -66
GameConfig.CONVEYOR_END_X = 66
GameConfig.CONVEYOR_Z = 0
GameConfig.CONVEYOR_SPEED = 6 -- studs per second
GameConfig.SPAWN_INTERVAL = 7 -- seconds between spawns
GameConfig.MAX_ON_CONVEYOR = 8 -- spawns pause while this many walk the belt

-- Bases: four plots, six slots each, in two rows of three.
GameConfig.BASE_SLOTS = 6
GameConfig.SLOT_SPACING_X = 7
GameConfig.SLOT_SPACING_Z = 7
GameConfig.BASE_CENTERS = {
	Vector3.new(-48, 0, -48),
	Vector3.new(48, 0, -48),
	Vector3.new(-48, 0, 48),
	Vector3.new(48, 0, 48),
}

-- Stealing: how long after a steal you must wait, and what a lock costs.
GameConfig.STEAL_COOLDOWN = 30 -- seconds
GameConfig.LOCK_COST = 500
GameConfig.LOCK_DURATION = 60 -- seconds

-- Rebirth: the cash a rebirth costs, and what it gives back.
-- Cost for rebirth number n (1st, 2nd, ...) is REBIRTH_BASE * REBIRTH_GROWTH^(n-1).
GameConfig.REBIRTH_BASE = 25000
GameConfig.REBIRTH_GROWTH = 6
GameConfig.REBIRTH_MULTIPLIER = 2 -- income x2 per rebirth, compounding

-- The tsunami: how often the wave comes, how long the warning lasts,
-- how fast the wall sweeps the map, and what it costs a caught player.
GameConfig.TSUNAMI_INTERVAL = 180 -- seconds between waves
GameConfig.TSUNAMI_WARNING = 15 -- seconds of warning before the wall moves
GameConfig.TSUNAMI_SWEEP_TIME = 10 -- seconds for the wall to cross the map
GameConfig.TSUNAMI_CASH_LOSS = 0.10 -- caught players lose 10% of their cash

-- How often the server pays out income and pushes state to clients.
GameConfig.INCOME_TICK = 1 -- seconds
GameConfig.STATE_PUSH_INTERVAL = 2 -- seconds

-- Money formatting: "$1,234,567".
function GameConfig.formatMoney(amount: number): string
	local rounded = math.floor(amount + 0.5)
	local text = tostring(rounded)
	local result = ""
	while #text > 3 do
		result = "," .. string.sub(text, -3) .. result
		text = string.sub(text, 1, #text - 3)
	end
	return "$" .. text .. result
end

-- Cash needed for rebirth number n (n starts at 1).
function GameConfig.rebirthCost(rebirthsDone: number): number
	return GameConfig.REBIRTH_BASE * (GameConfig.REBIRTH_GROWTH ^ rebirthsDone)
end

-- Income multiplier from rebirths done.
function GameConfig.rebirthMultiplier(rebirthsDone: number): number
	return GameConfig.REBIRTH_MULTIPLIER ^ rebirthsDone
end

return GameConfig
