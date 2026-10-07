--!strict
-- Rubble gates between zones. Gates are per-player: breaking one is saved in
-- your progression and only opens the way for you (the client hides gates the
-- player has already broken). Damage is tracked per player in memory.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Mines = require(Shared.Config.Mines)
local ZoneLocator = require(Shared.Util.ZoneLocator)

local DataService = require(script.Parent.DataService)

local GateService = {}

local damageTaken: { [Player]: { [string]: number } } = {}

function GateService:GetConfig(gateId: string): Mines.Gate?
	for _, mine in Mines.ById do
		local gate = mine.Gates[gateId]
		if gate then
			return gate
		end
	end
	return nil
end

function GateService:IsOpen(player: Player, gateId: string?): boolean
	if not gateId then
		return true
	end
	local data = DataService:Get(player)
	return data ~= nil and data.Gates[gateId] == true
end

-- Returns (remainingHealth, maxHealth, broken).
function GateService:Damage(player: Player, gateId: string, amount: number): (number, number, boolean)
	local gate = self:GetConfig(gateId)
	if not gate then
		return 0, 0, false
	end
	if self:IsOpen(player, gateId) then
		return 0, gate.Health, true
	end
	local taken = damageTaken[player] or {}
	damageTaken[player] = taken
	taken[gateId] = (taken[gateId] or 0) + amount
	local remaining = math.max(0, gate.Health - taken[gateId])
	if remaining <= 0 then
		taken[gateId] = nil
		DataService:Update(player, function(data)
			data.Gates[gateId] = true
		end)
		return 0, gate.Health, true
	end
	return remaining, gate.Health, false
end

-- Whether `player` could legitimately reach `position`: the zone's gate is
-- open for them, their lamp is bright enough, and they've visited the mine.
function GateService:CanAccess(player: Player, position: Vector3): boolean
	local data = DataService:Get(player)
	local mineId, zoneId = ZoneLocator.Locate(position)
	if not data or not mineId or not zoneId then
		return data ~= nil
	end
	local mine = Mines.ById[mineId]
	local zone = Mines.GetZone(mineId, zoneId)
	local state = data.Mines[mineId]
	if mine and mine.Order > 1 and not (state and state.Visited) then
		return false
	end
	if zone and not self:IsOpen(player, zone.RequiredGate) then
		return false
	end
	if zone and zone.Dark and data.LampTier < zone.Dark then
		return false
	end
	return true
end

function GateService:Init()
	Players.PlayerRemoving:Connect(function(player)
		damageTaken[player] = nil
	end)
end

return GateService
