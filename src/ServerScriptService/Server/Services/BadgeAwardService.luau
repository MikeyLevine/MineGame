--!strict
-- Awards Roblox badges (Config/Badges) when their achievement is earned.
-- Awarded badges are remembered in data.Badges so each is only sent once;
-- a badge whose id fails (not created yet / wrong id) is skipped for the
-- rest of the session instead of retrying every change.

local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Badges = require(ReplicatedStorage:WaitForChild("Shared").Config.Badges)

local DataService = require(script.Parent.DataService)

local BadgeAwardService = {}

local broken: { [number]: boolean } = {} -- badge ids that errored this session
local busy: { [Player]: boolean } = {}
local lastTry: { [Player]: { [string]: number } } = {} -- avoid hammering the web API on every data change
local RETRY_SECONDS = 60

local function award(player: Player, badge: Badges.Badge): boolean
	local ok, awarded = pcall(BadgeService.AwardBadge, BadgeService, player.UserId, badge.BadgeId)
	if ok and awarded then
		return true
	end
	-- AwardBadge returns false when the player already owns it.
	local okHas, has = pcall(BadgeService.UserHasBadgeAsync, BadgeService, player.UserId, badge.BadgeId)
	if okHas and has then
		return true
	end
	if not ok then
		warn(`[BadgeAwardService] Badge {badge.Id} ({badge.BadgeId}) failed:`, awarded)
		broken[badge.BadgeId] = true
	end
	return false
end

local function check(player: Player)
	if busy[player] then
		return
	end
	local data = DataService:Get(player)
	if not data then
		return
	end
	busy[player] = true
	for _, badge in Badges do
		if badge.BadgeId <= 0 or broken[badge.BadgeId] or data.Badges[badge.Id] then
			continue
		end
		local earned = if badge.Achievement then data.Achievements[badge.Achievement] ~= nil else true
		local tries = lastTry[player] or {}
		lastTry[player] = tries
		if not earned or os.clock() - (tries[badge.Id] or -math.huge) < RETRY_SECONDS then
			continue
		end
		tries[badge.Id] = os.clock()
		if award(player, badge) then
			DataService:Update(player, function(d)
				d.Badges[badge.Id] = true
			end)
		end
	end
	busy[player] = nil
end

function BadgeAwardService:Init()
	DataService:OnLoaded(function(player: Player)
		task.spawn(check, player)
	end)
	-- Achievements are written through DataService, so a change is the cue.
	DataService.Changed:Connect(function(player: Player)
		task.defer(check, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
		lastTry[player] = nil
	end)
end

return BadgeAwardService
