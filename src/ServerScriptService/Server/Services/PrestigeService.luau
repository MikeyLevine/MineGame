--!strict
-- Prestige ("Collapse the Mines"), available after completing the final mine.
-- Resets the run (cash, backpack, gear, gates, mine progress) and grants a
-- permanent prestige level: more sell value and mining power each level,
-- pricier gear, and prestige-only skins/achievements. Keeps artifacts,
-- achievements, stats, skins, settings and purchases.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Mines = require(Shared.Config.Mines)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local TravelService = require(script.Parent.TravelService)

local RateLimit = require(script.Parent.Parent.Util.RateLimit)

local PrestigeService = {}
local prestigeLimit = RateLimit.new(2)

function PrestigeService:CanPrestige(data: DataService.Data): boolean
	for id, mine in Mines.ById do
		if mine.Ending then
			local state = data.Mines[id]
			return state ~= nil and state.Completed == true
		end
	end
	return false
end

local function prestige(player: Player): (boolean, string)
	if not prestigeLimit(player) then
		return false, "Slow down"
	end
	local data = DataService:Get(player)
	if not data then
		return false, "Still loading"
	end
	if not PrestigeService:CanPrestige(data) then
		return false, "Complete the Unknown Depths first"
	end
	local level = data.Prestige + 1
	DataService:Update(player, function(d)
		d.Prestige = level
		d.Cash = 0
		table.clear(d.Backpack)
		d.PickaxeTier = 1
		d.BackpackTier = 1
		d.LampTier = 1
		d.SuitTier = 0
		d.DrillTier = 0
		table.clear(d.Gates)
		table.clear(d.Mines)
		table.clear(d.RunMined)
	end)
	local camp = workspace:FindFirstChild("Camp")
	local lift = camp and camp:FindFirstChild("MineLift")
	local arrival = lift and lift:FindFirstChild("Arrival")
	if arrival and arrival:IsA("BasePart") then
		task.spawn(function()
			TravelService:Teleport(player, arrival.CFrame, {
				title = `Prestige {level}`,
				subtitle = "The mines collapse... and open anew",
				tagline = "Ore sells for more and you hit harder, but gear costs more. Dig deep.",
			})
		end)
	end
	return true, `Prestige {level}!`
end

function PrestigeService:Init()
	Remotes.Function("Prestige").OnServerInvoke = prestige
	local camp = workspace:WaitForChild("Camp")
	local monument = camp:WaitForChild("PrestigeMonument", 10)
	local prompt = monument and monument:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		prompt.Triggered:Connect(function(player)
			Remotes.Event("OpenPrestige"):FireClient(player)
		end)
	else
		warn("[PrestigeService] Camp has no PrestigeMonument")
	end
end

return PrestigeService
