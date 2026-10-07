--!strict
-- Tracks where players have been (zones reached, mines visited) from their
-- character position on the server. Feeds "Reach" objectives and lift unlocks.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ZoneLocator = require(Shared.Util.ZoneLocator)
local Mines = require(Shared.Config.Mines)

local DataService = require(script.Parent.DataService)

local ProgressService = {}

local POLL_SECONDS = 0.5

local function check(player: Player)
	local data = DataService:Get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not data or not root then
		return
	end
	local mineId, zoneId = ZoneLocator.Locate(root.Position)
	if not mineId or not zoneId or not Mines.ById[mineId] then
		return -- not in a mine (or in the Abyss, which tracks its own progress)
	end
	local state = data.Mines[mineId]
	if state and state.Visited and state.Reached and state.Reached[zoneId] then
		return -- nothing new
	end
	DataService:Update(player, function(d)
		local s = d.Mines[mineId] or {}
		d.Mines[mineId] = s
		s.Visited = true
		s.Reached = s.Reached or {}
		;(s.Reached :: { [string]: boolean })[zoneId] = true
	end)
end

function ProgressService:MarkVisited(player: Player, mineId: string)
	DataService:Update(player, function(d)
		local s = d.Mines[mineId] or {}
		d.Mines[mineId] = s
		s.Visited = true
	end)
end

function ProgressService:Init()
	task.spawn(function()
		while true do
			task.wait(POLL_SECONDS)
			for _, player in Players:GetPlayers() do
				task.spawn(check, player)
			end
		end
	end)
end

return ProgressService
