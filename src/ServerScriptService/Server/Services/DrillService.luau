--!strict
-- The Mining Drill: a held tool that sends a tick every Drill.Tick seconds.
-- Each tick damages the target and splashes reduced damage onto nearby ore.
-- Every tick adds heat; at 100 the drill overheats and locks for a while.
-- Heat lives on the server and is mirrored to the player as attributes
-- (DrillHeat 0..100, DrillOverheated) for the client's heat bar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Equipment = require(Shared.Config.Equipment)
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Remotes)
local Targets = require(Shared.Util.Targets)

local DataService = require(script.Parent.DataService)
local MiningService = require(script.Parent.MiningService)
local OreService = require(script.Parent.OreService)
local Modifiers = require(Shared.Modifiers)

local DrillService = {}

type DrillState = { Heat: number, LockedUntil: number, LastTick: number }
local states: { [Player]: DrillState } = {}

local function stateFor(player: Player): DrillState
	local s = states[player]
	if not s then
		s = { Heat = 0, LockedUntil = 0, LastTick = 0 }
		states[player] = s
	end
	return s
end

local function publish(player: Player, s: DrillState)
	player:SetAttribute("DrillHeat", math.floor(s.Heat + 0.5))
	player:SetAttribute("DrillOverheated", os.clock() < s.LockedUntil)
end

local function onDrillRequest(player: Player, target: any)
	if typeof(target) ~= "Instance" or not target:IsDescendantOf(workspace) then
		return
	end
	local data = DataService:Get(player)
	local root = MiningService:LiveRoot(player)
	if not data or not root or data.DrillTier < 1 or not (player.Character :: Model):FindFirstChild("Drill") then
		return
	end
	local drill = Equipment.Drills[data.DrillTier]
	local s = stateFor(player)
	local now = os.clock()
	if now < s.LockedUntil or now - s.LastTick < drill.Tick * GameConfig.CooldownTolerance then
		return
	end
	local model, kind = Targets.Resolve(target)
	if not model or Targets.DistanceTo(model, root.Position) > GameConfig.MineRange then
		return
	end
	s.LastTick = now
	s.Heat += drill.HeatPerTick
	if s.Heat >= 100 then
		s.Heat = 100
		s.LockedUntil = now + drill.OverheatSeconds
	end
	publish(player, s)

	local power = drill.Power * Modifiers.Power(data, Modifiers.PlayerPasses(player), os.time())
	if kind == "Gate" then
		MiningService:HitGate(player, model, power, drill.Hardness)
		return
	elseif kind == "Creature" then
		MiningService.CreatureService:Damage(player, model, power * 2)
		return
	end
	local center = (model :: Model):GetPivot().Position
	MiningService:HitOre(player, model, power, drill.Hardness)
	local splash = power * drill.SplashMultiplier
	for _, other in OreService:Nearby(center, drill.SplashRadius) do
		if other ~= model then
			MiningService:HitOre(player, other, splash, drill.Hardness, true)
		end
	end
end

function DrillService:Init()
	Remotes.Event("DrillRequest").OnServerEvent:Connect(onDrillRequest)
	-- Cooling: heat drains whenever the drill isn't actively ticking.
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.1 then
			return
		end
		local step = accumulator
		accumulator = 0
		local now = os.clock()
		for player, s in states do
			local data = DataService:Get(player)
			local drill = data and Equipment.Drills[math.max(data.DrillTier, 1)]
			if drill and s.Heat > 0 and now - s.LastTick > 0.6 then
				s.Heat = math.max(0, s.Heat - drill.CoolPerSecond * step)
				publish(player, s)
			elseif s.Heat == 0 and player:GetAttribute("DrillOverheated") and now >= s.LockedUntil then
				publish(player, s)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
end

return DrillService
