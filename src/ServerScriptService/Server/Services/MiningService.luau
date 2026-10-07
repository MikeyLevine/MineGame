--!strict
-- Server-authoritative mining. The client only says "I swung at this";
-- the server checks reach, cooldown, equipped tool, hardness, zone access,
-- lamp strength (dark areas) and backpack space before applying damage or
-- awarding anything. The drill reuses HitOre/HitGate through DrillService.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Equipment = require(Shared.Config.Equipment)
local GameConfig = require(Shared.Config.GameConfig)
local Mines = require(Shared.Config.Mines)
local Resources = require(Shared.Config.Resources)
local Remotes = require(Shared.Remotes)
local Targets = require(Shared.Util.Targets)

local DataService = require(script.Parent.DataService)
local GateService = require(script.Parent.GateService)
local InventoryService = require(script.Parent.InventoryService)
local OreService = require(script.Parent.OreService)
local Modifiers = require(Shared.Modifiers)

local rng = Random.new()

local MiningService = {}

local lastSwing: { [Player]: number } = {}
local feedback: RemoteEvent

local function reject(player: Player, target: Instance, reason: string, extra: { [string]: any }?)
	local payload = { target = target, reason = reason }
	if extra then
		for k, v in extra do
			payload[k] = v
		end
	end
	feedback:FireClient(player, payload)
end

-- Returns the character root if the player is alive and loaded.
function MiningService:LiveRoot(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return root
end

-- Damages a rubble gate for `player`. `silent` suppresses rejection messages.
function MiningService:HitGate(player: Player, model: Instance, power: number, hardness: number, silent: boolean?)
	local gateId = model:GetAttribute("GateId")
	local gate = type(gateId) == "string" and GateService:GetConfig(gateId)
	if not gate then
		return
	end
	if gate.Mechanism then
		if not silent then
			reject(player, model, "Mechanism")
		end
		return
	end
	if hardness < gate.Hardness then
		if not silent then
			reject(player, model, "TooHard", { requirement = gate.RequiredPickaxeName })
		end
		return
	end
	local health, maxHealth, broken = GateService:Damage(player, gate.Id, power)
	feedback:FireClient(player, {
		target = model,
		kind = "Gate",
		hidden = gate.Hidden == true,
		gateName = gate.DisplayName,
		damage = power,
		health = health,
		maxHealth = maxHealth,
		broken = broken,
		gateId = gate.Id,
		position = (model :: Model):GetPivot().Position,
	})
end

-- Damages an ore node for `player` after every server-side check. Returns
-- true if damage was applied. `silent` suppresses rejection messages (used
-- for drill splash damage on neighbouring nodes).
function MiningService:HitOre(player: Player, model: Instance, power: number, hardness: number, silent: boolean?): boolean
	local data = DataService:Get(player)
	local ore = OreService:Get(model)
	local resource = ore and Resources.Get(ore.ResourceId)
	if not data or not ore or not resource then
		return false
	end
	local zone = Mines.GetZone(ore.MineId, ore.ZoneId)
	if zone and not GateService:IsOpen(player, zone.RequiredGate) then
		return false -- can't legitimately be here yet
	end
	local mineConfig = Mines.ById[ore.MineId]
	local mineState = data.Mines[ore.MineId]
	if mineConfig and mineConfig.Order > 1 and not (mineState and mineState.Visited) then
		return false -- deeper mines are only reachable through the ascension portal
	end
	if zone and zone.Dark and data.LampTier < zone.Dark then
		if not silent then
			reject(player, model, "TooDark", { requirement = Equipment.Lamps[zone.Dark].Name })
		end
		return false
	end
	if hardness < resource.Hardness then
		if not silent then
			local needed = "a better pickaxe"
			for _, p in Equipment.Pickaxes do
				if p.Hardness >= resource.Hardness then
					needed = p.Name
					break
				end
			end
			reject(player, model, "TooHard", { requirement = needed, resourceId = resource.Id })
		end
		return false
	end
	if InventoryService:IsFull(player) then
		if not silent then
			reject(player, model, "BackpackFull")
		end
		return false
	end

	local position = (model :: Model):GetPivot().Position
	local health, broken = OreService:Damage(model :: Model, power)
	local amount = 0
	local rich = ore.Rich
	if broken and not rich then
		-- Per-player luck (Lucky Miner pass, Lucky Charm boost): a chance that an
		-- ordinary rock pays out like a rich vein.
		local luck = Modifiers.Luck(data, Modifiers.PlayerPasses(player), os.time())
		local base = if zone and zone.RichChance then zone.RichChance else 0.03
		rich = luck > 1 and rng:NextNumber() < base * (luck - 1)
	end
	if broken then
		amount = InventoryService:Add(player, resource.Id, if rich then OreService:Yield({ Rich = true } :: any) else 1)
		if rich then
			DataService:Update(player, function(d)
				d.Stats.RichVeins = (d.Stats.RichVeins or 0) + 1
			end)
		end
	end
	-- Splash hits that don't break anything aren't worth a network message.
	if not silent or broken then
		feedback:FireClient(player, {
			target = model,
			kind = "Ore",
			damage = power,
			health = health,
			maxHealth = ore.MaxHealth,
			broken = broken,
			resourceId = resource.Id,
			amount = amount,
			rich = rich,
			position = position,
			splash = silent == true,
		})
	end
	return true
end

local function onMineRequest(player: Player, target: any)
	if typeof(target) ~= "Instance" or not target:IsDescendantOf(workspace) then
		return
	end
	local data = DataService:Get(player)
	local root = MiningService:LiveRoot(player)
	if not data or not root or not (player.Character :: Model):FindFirstChild("Pickaxe") then
		return -- tool must be equipped
	end

	local pickaxe = Equipment.Pickaxes[data.PickaxeTier] or Equipment.Pickaxes[1]
	local now = os.clock()
	if now - (lastSwing[player] or 0) < pickaxe.Cooldown * GameConfig.CooldownTolerance then
		return
	end

	local model, kind = Targets.Resolve(target)
	if not model or Targets.DistanceTo(model, root.Position) > GameConfig.MineRange then
		return
	end
	lastSwing[player] = now

	local power = pickaxe.Power * Modifiers.Power(data, Modifiers.PlayerPasses(player), os.time())
	if kind == "Gate" then
		MiningService:HitGate(player, model, power, pickaxe.Hardness)
	elseif kind == "Creature" then
		MiningService.CreatureService:Damage(player, model, power * 2)
	else
		MiningService:HitOre(player, model, power, pickaxe.Hardness)
	end
end

function MiningService:Init()
	feedback = Remotes.Event("MineFeedback")
	Remotes.Event("MineRequest").OnServerEvent:Connect(onMineRequest)
	Players.PlayerRemoving:Connect(function(player)
		lastSwing[player] = nil
	end)
end

return MiningService
