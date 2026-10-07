--!strict
-- Mine completion + lift unlock rules, shared so the server (authority) and
-- the client (objectives UI, lift menu) always agree.

local Mines = require(script.Parent.Config.Mines)
local Artifacts = require(script.Parent.Config.Artifacts)
local Abyss = require(script.Parent.Config.Abyss)

export type Item = {
	Id: string,
	Label: string,
	Current: number,
	Target: number,
	Done: boolean,
	ShowCount: boolean,
}

-- Minimal shape of player data this module reads.
type DataLike = {
	PickaxeTier: number,
	Gates: { [string]: boolean },
	Stats: { Mined: { [string]: number } },
	Mines: { [string]: { Reached: { [string]: boolean }?, Completed: boolean?, Visited: boolean? } },
	Artifacts: { [string]: boolean }?,
}

local Progress = {}

function Progress.MineState(data: DataLike, mineId: string)
	return data.Mines[mineId] or {}
end

function Progress.IsCompleted(data: DataLike, mineId: string): boolean
	return Progress.MineState(data, mineId).Completed == true
end

-- Returns (items, ready, percent 0..100).
function Progress.Evaluate(data: DataLike, mineId: string): ({ Item }, boolean, number)
	local mine = Mines.ById[mineId]
	local items: { Item } = {}
	if not mine then
		return items, false, 0
	end
	local state = Progress.MineState(data, mineId)
	local fraction = 0
	for _, req in mine.Requirements do
		local current, target, showCount = 0, 1, false
		if req.Type == "PickaxeTier" then
			current, target = if data.PickaxeTier >= (req.Tier or 1) then 1 else 0, 1
		elseif req.Type == "Mined" then
			target = req.Amount or 1
			-- After a prestige only this run's ore counts; before it, lifetime totals
			-- (saves from before RunMined existed keep their progress).
			local counts = if (data.Prestige or 0) > 0 then (data.RunMined or {}) else data.Stats.Mined
			current = math.min(counts[req.Resource or ""] or 0, target)
			showCount = true
		elseif req.Type == "Gate" then
			target = req.Amount or 1
			local broken = 0
			for _, gateId in req.GateIds or {} do
				if data.Gates[gateId] then
					broken += 1
				end
			end
			current = math.min(broken, target)
			showCount = target > 1
		elseif req.Type == "Equip" then
			local have = (data :: any)[req.Field or ""] or 0
			current = if have >= (req.Tier or 1) then 1 else 0
		elseif req.Type == "Artifacts" then
			target = req.Amount or 1
			current = math.min((Artifacts.CountIn(data.Artifacts, req.MineId)), target)
			showCount = true
		elseif req.Type == "Stat" then
			target = req.Amount or 1
			current = math.min(((data.Stats :: any)[req.Field or ""] or 0) :: number, target)
			showCount = true
		elseif req.Type == "Reach" then
			local reached = state.Reached
			current = if reached and reached[req.ZoneId or ""] then 1 else 0
		end
		fraction += current / target
		table.insert(items, {
			Id = req.Id,
			Label = req.Label,
			Current = current,
			Target = target,
			Done = current >= target,
			ShowCount = showCount,
		})
	end
	local ready = #items > 0
	for _, item in items do
		if not item.Done then
			ready = false
		end
	end
	local percent = if #items > 0 then math.floor(fraction / #items * 100) else 100
	return items, ready, percent
end

-- The mine whose objectives the player should be working on: the first
-- (by Order) mine that has requirements and isn't completed yet.
function Progress.FrontierMine(data: DataLike): string?
	local ordered = {}
	for id, mine in Mines.ById do
		table.insert(ordered, mine)
	end
	table.sort(ordered, function(a, b)
		return a.Order < b.Order
	end)
	for _, mine in ordered do
		if #mine.Requirements > 0 and not Progress.IsCompleted(data, mine.Id) then
			return mine.Id
		end
	end
	return nil
end

function Progress.IsLiftUnlocked(data: DataLike, lift: Mines.Lift): boolean
	if lift.Abyss then
		return Abyss.IsUnlocked(data)
	end
	if lift.UnlockGate and data.Gates[lift.UnlockGate] then
		return true
	end
	if lift.UnlockMine and Progress.MineState(data, lift.UnlockMine).Visited then
		return true
	end
	return false
end

return Progress
