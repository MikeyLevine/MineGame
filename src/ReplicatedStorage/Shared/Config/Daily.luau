--!strict
-- Daily login rewards: a 7-day streak that loops. Claim once per UTC day;
-- missing a day restarts the streak at day 1. Cash scales with how far the
-- player has progressed so rewards matter at every stage. Some days also
-- grant a short free boost (same boosts as the store, see Config/Store).

export type Reward = {
	Cash: number,
	Boost: string?, -- Config/Store boost id
	BoostSeconds: number?,
}

local Daily = {}

Daily.Days = 7

-- Cash multiplier per streak day, plus the bonus boosts.
Daily.Schedule = {
	{ Multiplier = 1 },
	{ Multiplier = 1.5 },
	{ Multiplier = 2, Boost = "LuckyCharm", BoostSeconds = 600 },
	{ Multiplier = 2.5 },
	{ Multiplier = 3, Boost = "OreBuyerBonus", BoostSeconds = 600 },
	{ Multiplier = 4 },
	{ Multiplier = 6, Boost = "MiningFrenzy", BoostSeconds = 900 },
}

-- Base cash by how many mines the player has completed.
local BASE_BY_COMPLETED = { [0] = 400, 3000, 25000, 150000, 800000, 2500000, 6000000 }

function Daily.Today(now: number): number
	return now // 86400
end

-- Seconds until the next UTC midnight.
function Daily.SecondsUntilReset(now: number): number
	return 86400 - now % 86400
end

-- Which streak day (1..7) a claim made today would be.
function Daily.NextDay(data: any, now: number): number
	local d = data.Daily
	local today = Daily.Today(now)
	if not d or d.LastDay ~= today - 1 then
		return 1 -- first claim, or the streak was broken
	end
	return (d.Streak % Daily.Days) + 1
end

function Daily.CanClaim(data: any, now: number): boolean
	return not data.Daily or data.Daily.LastDay ~= Daily.Today(now)
end

local function completedMines(data: any): number
	local n = 0
	for _, state in data.Mines or {} do
		if state.Completed then
			n += 1
		end
	end
	return math.min(n, 6)
end

function Daily.Reward(day: number, data: any): Reward
	local entry = Daily.Schedule[day] or Daily.Schedule[1]
	-- Prestiged players have an empty mine list again; use at least their
	-- prestige level so their dailies don't drop to beginner amounts.
	local tier = math.max(completedMines(data), math.min(data.Prestige or 0, 5))
	local cash = math.floor(BASE_BY_COMPLETED[tier] * entry.Multiplier / 10 + 0.5) * 10
	return { Cash = cash, Boost = entry.Boost, BoostSeconds = entry.BoostSeconds }
end

return Daily
