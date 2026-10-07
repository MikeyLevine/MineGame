--!strict
-- One-time reward for joining the game's Roblox group, claimed at the plaque
-- under the camp leaderboard. Membership is checked live with
-- GroupService (not the per-session cached IsInGroup), so players can join
-- the group and claim without rejoining. Disabled while GroupId is 0.

local GroupService = game:GetService("GroupService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Util.Format)
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)

local GroupRewardService = {}
local claimLimit = RateLimit.new(3)

local function isMember(player: Player, groupId: number): boolean?
	local ok, groups = pcall(GroupService.GetGroupsAsync, GroupService, player.UserId)
	if not ok then
		return nil -- web call failed; unknown
	end
	for _, group in groups do
		if group.Id == groupId then
			return true
		end
	end
	return false
end

local function claim(player: Player)
	local notify = Remotes.Event("Notify")
	local groupId = GameConfig.GroupId
	if not groupId or groupId <= 0 then
		notify:FireClient(player, "The group reward is coming soon!", "Info")
		return
	end
	if not claimLimit(player) then
		return
	end
	local data = DataService:Get(player)
	if not data then
		return
	end
	if data.GroupRewardClaimed then
		notify:FireClient(player, "You already claimed the group reward. Thanks for being part of it!", "Info")
		return
	end
	local member = isMember(player, groupId)
	if member == nil then
		notify:FireClient(player, "Couldn't check the group right now, try again in a moment.", "Warn")
		return
	elseif not member then
		notify:FireClient(player, "Join our Roblox group (link on the game page), then come back to claim!", "Info")
		return
	end
	local reward = GameConfig.GroupRewardCash
	local now = os.time()
	DataService:Update(player, function(d)
		d.GroupRewardClaimed = true
		d.Cash += reward
		d.Stats.TotalEarned += reward
		d.Boosts.LuckyCharm = math.max(d.Boosts.LuckyCharm or 0, now) + GameConfig.GroupRewardBoostSeconds
	end)
	notify:FireClient(player, `Thanks for joining! +{Format.Cash(reward)} and {GameConfig.GroupRewardBoostSeconds // 60} min of Lucky Charm`, "Good")
end

function GroupRewardService:Init()
	local camp = workspace:WaitForChild("Camp")
	local board = camp:WaitForChild("Leaderboard", 10)
	local prompt = board and board:FindFirstChild("GroupPrompt", true)
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Triggered:Connect(claim)
	else
		warn("[GroupRewardService] No group prompt at camp")
	end
end

return GroupRewardService
