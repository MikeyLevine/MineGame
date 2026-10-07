--!strict
-- Per-player throttle for client-callable remotes, so a spamming client
-- can't make the server do expensive work (tool rebuilds, saves, state
-- pushes) hundreds of times a second.
--
--   local allow = RateLimit.new(0.25)
--   if not allow(player) then return false, "Slow down" end

local Players = game:GetService("Players")

local RateLimit = {}

function RateLimit.new(interval: number): (Player) -> boolean
	local last: { [Player]: number } = {}
	Players.PlayerRemoving:Connect(function(player)
		last[player] = nil
	end)
	return function(player: Player): boolean
		local now = os.clock()
		if now - (last[player] or 0) < interval then
			return false
		end
		last[player] = now
		return true
	end
end

return RateLimit
