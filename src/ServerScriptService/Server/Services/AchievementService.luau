--!strict
-- Awards achievements (Config/Achievements) whenever a player's data changes.
-- Checks run deferred so awarding (which itself updates data) never recurses.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Achievements = require(Shared.Config.Achievements)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)

local AchievementService = {}

local pending: { [Player]: boolean } = {}

local function check(player: Player)
	pending[player] = nil
	local data = DataService:Get(player)
	if not data then
		return
	end
	local newly = {}
	for _, a in Achievements.List do
		if not data.Achievements[a.Id] then
			local ok, current, target = pcall(a.Progress, data)
			if ok and current >= target then
				table.insert(newly, a)
			end
		end
	end
	if #newly == 0 then
		return
	end
	DataService:Update(player, function(d)
		for _, a in newly do
			d.Achievements[a.Id] = os.time()
			d.Cash += a.Reward
			d.Stats.TotalEarned += a.Reward
		end
	end)
	-- Stagger pop-ups so several unlocks at once are all readable.
	for i, a in newly do
		task.delay((i - 1) * 2.2, function()
			if player.Parent then
				Remotes.Event("Achievement"):FireClient(player, a.Id)
			end
		end)
	end
end

local function schedule(player: Player)
	if pending[player] then
		return
	end
	pending[player] = true
	task.delay(0.25, check, player)
end

function AchievementService:Init()
	DataService:OnLoaded(function(player)
		task.delay(4, schedule, player) -- after the client UI is up
	end)
	DataService.Changed:Connect(schedule)
	Players.PlayerRemoving:Connect(function(player)
		pending[player] = nil
	end)
end

return AchievementService
