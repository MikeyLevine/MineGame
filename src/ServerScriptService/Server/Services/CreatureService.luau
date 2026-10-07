--!strict
-- Hostile creatures (Unknown Depths). Server-driven: each creature wanders
-- near its home, chases the nearest player that comes within AggroRange,
-- bites when close, and gives up past LeashRange (healing while idle).
-- Players fight back with the pickaxe/drill (MiningService/DrillService call
-- Damage). Kills pay a reward, may drop rare ore and count towards the
-- CreaturesDefeated stat.
--
-- Creatures are anchored models moved with PivotTo at 20 Hz and snapped to
-- the terrain below, which is plenty for crawling things and keeps them out
-- of the physics engine.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Creatures = require(Shared.Config.Creatures)
local Remotes = require(Shared.Remotes)
local ZoneLocator = require(Shared.Util.ZoneLocator)

local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)
local MiningService = require(script.Parent.MiningService)

local CreatureService = {}

type State = {
	Model: Model,
	Kind: string,
	Config: Creatures.Creature,
	Spawn: BasePart,
	Home: Vector3,
	Health: number,
	Target: Player?,
	LastBite: number,
	WanderTo: Vector3?,
	NextWander: number,
	Engaged: { [Player]: boolean },
}

local TICK = 0.05
-- Zones creatures never follow players into (the seal hall and what's beyond).
local SAFE_ZONES = { Final = true, Heart = true }
local BITE_RANGE = 5.5
local states: { [Model]: State } = {}
local rng = Random.new()
local creatureEvent: RemoteEvent

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { workspace.Terrain }

local function groundBelow(position: Vector3): Vector3?
	local hit = workspace:Raycast(position + Vector3.new(0, 8, 0), Vector3.new(0, -30, 0), terrainOnly)
	return hit and hit.Position
end

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

-- A low, many-legged body with glowing eyes and spines.
local function buildModel(config: Creatures.Creature, at: CFrame): Model
	local s = config.Scale
	local model = Instance.new("Model")
	model.Name = config.Name
	local body = part({
		Name = "Body",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(4, 4, 4) * s,
		CFrame = at,
		Material = Enum.Material.SmoothPlastic,
		Color = config.BodyColor,
		CanQuery = true,
	})
	body.Parent = model
	model.PrimaryPart = body
	local abdomen = part({
		Name = "Abdomen",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(3.4, 3, 4.6) * s,
		CFrame = at * CFrame.new(0, 0.3 * s, 2.6 * s),
		Material = Enum.Material.SmoothPlastic,
		Color = config.BodyColor:Lerp(config.GlowColor, 0.12),
		CanQuery = true,
	})
	abdomen.Parent = model
	for _, x in { -0.7, 0.7 } do
		part({
			Name = "Eye",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.7, 0.7, 0.7) * s,
			CFrame = at * CFrame.new(x * s, 0.6 * s, -1.75 * s),
			Material = Enum.Material.Neon,
			Color = config.GlowColor,
		}).Parent = model
	end
	for i = 1, 3 do
		for _, side in { -1, 1 } do
			local z = (-1 + (i - 1)) * 1.2 * s
			part({
				Name = "Leg",
				Size = Vector3.new(0.35, 0.35, 3.6) * s,
				CFrame = at * CFrame.new(side * 2.2 * s, -1 * s, z) * CFrame.Angles(0, math.rad(90), side * math.rad(35)),
				Material = Enum.Material.SmoothPlastic,
				Color = config.BodyColor,
			}).Parent = model
		end
	end
	for i = 1, 4 do
		part({
			Name = "Spine",
			Size = Vector3.new(0.3, 1.4, 0.3) * s,
			CFrame = at * CFrame.new(0, 2 * s, (-0.5 + i * 0.9) * s) * CFrame.Angles(math.rad(-25), 0, 0),
			Material = Enum.Material.Neon,
			Color = config.GlowColor,
		}).Parent = model
	end
	local light = Instance.new("PointLight")
	light.Color = config.GlowColor
	light.Range = 10 * s
	light.Brightness = 0.8
	light.Parent = body
	return model
end

local function spawnCreature(spawnPart: BasePart, container: Instance)
	local kind = spawnPart:GetAttribute("Kind")
	local config = type(kind) == "string" and Creatures[kind]
	if not config then
		return
	end
	local home = spawnPart.Position
	local floor = groundBelow(home) or home
	local at = CFrame.new(floor + Vector3.new(0, 2 * config.Scale, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local model = buildModel(config, at)
	model:SetAttribute("Kind", kind)
	model:SetAttribute("Health", config.Health)
	model:SetAttribute("MaxHealth", config.Health)
	CollectionService:AddTag(model, "Creature")
	model.Parent = container
	states[model] = {
		Model = model,
		Kind = kind :: string,
		Config = config,
		Spawn = spawnPart,
		Home = floor,
		Health = config.Health,
		Target = nil,
		LastBite = 0,
		WanderTo = nil,
		NextWander = os.clock() + rng:NextNumber(1, 4),
		Engaged = {},
	}
end

local function liveRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return root
end

local function inSafeZone(position: Vector3): boolean
	local _, zoneId = ZoneLocator.Locate(position)
	return zoneId ~= nil and SAFE_ZONES[zoneId] == true
end

local function nearestPlayer(position: Vector3, range: number): Player?
	local best, bestDist = nil, range
	for _, player in Players:GetPlayers() do
		local root = liveRoot(player)
		if root and not inSafeZone(root.Position) then
			local d = (root.Position - position).Magnitude
			if d < bestDist then
				best, bestDist = player, d
			end
		end
	end
	return best
end

-- Moves towards `goal` at `speed`, snapped to the floor; returns new position.
local function step(s: State, goal: Vector3, speed: number): Vector3
	local pivot = s.Model:GetPivot()
	local from = pivot.Position
	local flat = Vector3.new(goal.X - from.X, 0, goal.Z - from.Z)
	if flat.Magnitude < 0.5 then
		return from
	end
	local dir = flat.Unit
	local move = math.min(flat.Magnitude, speed * TICK)
	-- Don't walk into walls.
	local wall = workspace:Raycast(from, dir * (move + 2 * s.Config.Scale), terrainOnly)
	if wall then
		return from
	end
	local nextPos = from + dir * move
	local floor = groundBelow(nextPos)
	if not floor or math.abs(floor.Y - (from.Y - 2 * s.Config.Scale)) > 6 then
		return from -- ledge or cliff: stay put
	end
	local bob = math.sin(os.clock() * 12) * 0.15 * s.Config.Scale
	local target = floor + Vector3.new(0, 2 * s.Config.Scale + bob, 0)
	s.Model:PivotTo(CFrame.lookAt(target, target + dir))
	return target
end

local function update(s: State)
	local config = s.Config
	local position = s.Model:GetPivot().Position
	local now = os.clock()

	-- Keep or acquire a target.
	if s.Target then
		local root = liveRoot(s.Target)
		if not root or (root.Position - s.Home).Magnitude > config.LeashRange or inSafeZone(root.Position) then
			s.Target = nil
		end
	end
	if not s.Target then
		s.Target = nearestPlayer(position, config.AggroRange)
		if s.Target and not s.Engaged[s.Target] then
			s.Engaged[s.Target] = true
			creatureEvent:FireClient(s.Target, { event = "alert", position = position, name = config.Name })
		end
	end

	local target = s.Target
	local root = target and liveRoot(target)
	if target and root then
		local d = (root.Position - position).Magnitude
		if d > BITE_RANGE then
			step(s, root.Position, config.Speed)
		elseif now - s.LastBite >= config.AttackCooldown then
			s.LastBite = now
			local humanoid = (target.Character :: Model):FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid:TakeDamage(config.Damage)
				creatureEvent:FireClient(target, { event = "bite", position = position })
			end
		end
		return
	end

	-- Idle: heal, wander near home, forget who we fought.
	table.clear(s.Engaged)
	if s.Health < config.Health then
		s.Health = math.min(config.Health, s.Health + config.Health * 0.05 * TICK)
		s.Model:SetAttribute("Health", math.floor(s.Health))
	end
	if (position - s.Home).Magnitude > 24 then
		s.WanderTo = s.Home
	elseif now >= s.NextWander then
		local a = rng:NextNumber(0, math.pi * 2)
		s.WanderTo = s.Home + Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(4, 18)
		s.NextWander = now + rng:NextNumber(3, 7)
	end
	if s.WanderTo then
		step(s, s.WanderTo, config.Speed * 0.4)
	end
end

local function kill(s: State, killer: Player)
	states[s.Model] = nil
	local position = s.Model:GetPivot().Position
	s.Model:Destroy()
	creatureEvent:FireClient(killer, { event = "death", position = position, name = s.Config.Name })
	local reward = s.Config.Reward
	DataService:Update(killer, function(d)
		d.Cash += reward
		d.Stats.TotalEarned += reward
		d.Stats.CreaturesDefeated = (d.Stats.CreaturesDefeated or 0) + 1
	end)
	local drops = {}
	for resourceId, chance in s.Config.Drops do
		if rng:NextNumber() < chance and InventoryService:Add(killer, resourceId, 1) > 0 then
			table.insert(drops, resourceId)
		end
	end
	Remotes.Event("Notify"):FireClient(killer,
		`Defeated a {s.Config.Name}! +${reward}` .. (if #drops > 0 then ` and {table.concat(drops, ", ")}` else ""), "Good")
	local spawnPart, container = s.Spawn, s.Spawn.Parent and s.Spawn.Parent.Parent
	task.delay(s.Config.RespawnSeconds, function()
		if spawnPart.Parent and container then
			local active = container:FindFirstChild("ActiveCreatures")
			if active then
				spawnCreature(spawnPart, active)
			end
		end
	end)
end

-- Called by MiningService/DrillService when a player hits a creature.
function CreatureService:Damage(player: Player, model: Instance, amount: number)
	local s = states[model :: Model]
	local root = liveRoot(player)
	if not s or not root then
		return
	end
	s.Health -= amount
	s.Target = player -- whoever hits it gets its attention
	s.Model:SetAttribute("Health", math.max(0, math.floor(s.Health)))
	local feedback = Remotes.Event("MineFeedback")
	local position = s.Model:GetPivot().Position
	if s.Health <= 0 then
		feedback:FireClient(player, { target = model, kind = "Creature", broken = true, position = position,
			health = 0, maxHealth = s.Config.Health, name = s.Config.Name })
		kill(s, player)
	else
		feedback:FireClient(player, { target = model, kind = "Creature", broken = false, position = position,
			health = s.Health, maxHealth = s.Config.Health, name = s.Config.Name })
	end
end

function CreatureService:Init()
	MiningService.CreatureService = CreatureService
	creatureEvent = Remotes.Event("Creature")
	for _, mine in workspace:WaitForChild("Mines"):GetChildren() do
		local spawns = mine:FindFirstChild("CreatureSpawns")
		if spawns then
			local active = Instance.new("Folder")
			active.Name = "ActiveCreatures"
			active.Parent = mine
			for _, p in spawns:GetDescendants() do
				if p:IsA("BasePart") then
					spawnCreature(p, active)
				end
			end
		end
	end
	task.spawn(function()
		while true do
			task.wait(TICK)
			for _, s in states do
				local ok, err = pcall(update, s)
				if not ok then
					warn("[CreatureService]", err)
				end
			end
		end
	end)
end

return CreatureService
