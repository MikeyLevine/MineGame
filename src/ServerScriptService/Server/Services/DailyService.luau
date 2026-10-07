--!strict
-- Daily login rewards (Config/Daily). The server decides the day from its
-- own clock (UTC), so changing the device clock does nothing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Daily = require(Shared.Config.Daily)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)
local Store = require(Shared.Config.Store)

local DataService = require(script.Parent.DataService)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)

local DailyService = {}
local claimLimit = RateLimit.new(1)

local function claim(player: Player): (boolean, string)
	if not claimLimit(player) then
		return false, "Slow down"
	end
	local data = DataService:Get(player)
	if not data then
		return false, "Still loading"
	end
	local now = os.time()
	if not Daily.CanClaim(data, now) then
		return false, "Already claimed today. Come back tomorrow!"
	end
	local day = Daily.NextDay(data, now)
	local reward = Daily.Reward(day, data)
	local boost = reward.Boost and Store.GetBoost(reward.Boost)
	DataService:Update(player, function(d)
		local today = Daily.Today(now)
		-- Streak counts consecutive days (day 8 shows as day 1 of the next week).
		d.Daily.Streak = if d.Daily.LastDay == today - 1 then (d.Daily.Streak or 0) + 1 else 1
		d.Daily.LastDay = today
		d.Daily.Best = math.max(d.Daily.Best or 0, d.Daily.Streak)
		d.Cash += reward.Cash
		d.Stats.TotalEarned += reward.Cash
		if boost and reward.BoostSeconds then
			d.Boosts[boost.Id] = math.max(d.Boosts[boost.Id] or 0, now) + reward.BoostSeconds
		end
	end)
	local text = `Day {day} reward: +{Format.Cash(reward.Cash)}`
	if boost and reward.BoostSeconds then
		text ..= ` and {reward.BoostSeconds // 60} min of {boost.Name}`
	end
	return true, text
end

function DailyService:Init()
	Remotes.Function("ClaimDaily").OnServerInvoke = claim
	-- Tell the client to show the calendar once per join when a reward is waiting.
	DataService:OnLoaded(function(player: Player, data)
		if Daily.CanClaim(data, os.time()) then
			task.delay(4, function()
				if player.Parent then
					Remotes.Event("OpenDaily"):FireClient(player)
				end
			end)
		end
	end)
end

return DailyService
