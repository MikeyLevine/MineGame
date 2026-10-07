--!strict
-- Completion percentages for the journal: per mine and for the whole game.
--
-- A mine's score blends: objectives (or 100% once completed), areas reached,
-- hidden chambers found and artifacts collected. The game score is 80% the
-- average of all mines and 20% achievements.

local Mines = require(script.Parent.Config.Mines)
local Artifacts = require(script.Parent.Config.Artifacts)
local Achievements = require(script.Parent.Config.Achievements)
local Progress = require(script.Parent.Progress)

local Completion = {}

export type MineSummary = {
	MineId: string,
	Percent: number,
	ZonesReached: number,
	ZonesTotal: number,
	SecretsFound: number,
	SecretsTotal: number,
	ArtifactsFound: number,
	ArtifactsTotal: number,
	Completed: boolean,
	Visited: boolean,
}

function Completion.Mine(data: any, mineId: string): MineSummary
	local mine = Mines.ById[mineId]
	local state = data.Mines[mineId] or {}
	local reached = state.Reached or {}

	local zonesReached, zonesTotal = 0, 0
	local secretsFound, secretsTotal = 0, 0
	for _, zone in mine.Zones do
		local gate = zone.RequiredGate and mine.Gates[zone.RequiredGate]
		if gate and gate.Hidden then
			secretsTotal += 1
			if data.Gates[gate.Id] then
				secretsFound += 1
			end
		else
			zonesTotal += 1
			if reached[zone.Id] then
				zonesReached += 1
			end
		end
	end
	local artifactsFound, artifactsTotal = Artifacts.CountIn(data.Artifacts, mineId)

	local objectives = 0
	if state.Completed then
		objectives = 1
	elseif #mine.Requirements > 0 then
		local _, _, percent = Progress.Evaluate(data, mineId)
		objectives = percent / 100
	end

	-- Weights shift onto the other parts when a mine has no secrets/artifacts.
	local parts = { { 0.4, objectives }, { 0.3, if zonesTotal > 0 then zonesReached / zonesTotal else 1 } }
	if secretsTotal > 0 then
		table.insert(parts, { 0.15, secretsFound / secretsTotal })
	end
	if artifactsTotal > 0 then
		table.insert(parts, { 0.15, artifactsFound / artifactsTotal })
	end
	local weight, score = 0, 0
	for _, p in parts do
		weight += p[1]
		score += p[1] * p[2]
	end

	return {
		MineId = mineId,
		Percent = math.floor(score / weight * 100),
		ZonesReached = zonesReached,
		ZonesTotal = zonesTotal,
		SecretsFound = secretsFound,
		SecretsTotal = secretsTotal,
		ArtifactsFound = artifactsFound,
		ArtifactsTotal = artifactsTotal,
		Completed = state.Completed == true,
		Visited = state.Visited == true or mine.Order == 1,
	}
end

function Completion.OrderedMines(): { string }
	local ids = {}
	for id in Mines.ById do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return Mines.ById[a].Order < Mines.ById[b].Order
	end)
	return ids
end

function Completion.Game(data: any): number
	local sum, count = 0, 0
	for _, id in Completion.OrderedMines() do
		sum += Completion.Mine(data, id).Percent
		count += 1
	end
	local earned = 0
	for _, a in Achievements.List do
		if data.Achievements and data.Achievements[a.Id] then
			earned += 1
		end
	end
	local mines = if count > 0 then sum / count / 100 else 0
	return math.floor((mines * 0.8 + (earned / #Achievements.List) * 0.2) * 100)
end

return Completion
