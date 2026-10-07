--!strict
-- Spawns, tracks and respawns ore nodes.
--
-- The map provides spawn points: Workspace.Mines.<MineId>.OreSpawns.<ZoneId>.<Part>
-- Each point's CFrame sits on the cave surface with UpVector = surface normal.
-- Which points are filled, and with what, is randomised every time, so every
-- trip down looks a little different.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Mines = require(Shared.Config.Mines)
local Resources = require(Shared.Config.Resources)

type OreState = {
	ResourceId: string,
	MineId: string,
	ZoneId: string,
	Health: number,
	MaxHealth: number,
	Rich: boolean,
	Point: BasePart?, -- nil for special one-off ores (event meteorites, abyss)
	Yield: number?, -- units per break before the rich bonus (abyss floors pay more)
	Owner: Player?, -- only this player may mine it (abyss floors)
}

local OreService = {}

-- Rich veins take this much longer to break and yield RICH_YIELD units.
local RICH_HEALTH_MULT = 1.6
local RICH_YIELD = 3

local ores: { [Model]: OreState } = {}
local occupied: { [BasePart]: boolean } = {}
local rng = Random.new()

local function pickResource(weights: { [string]: number }): string
	local total = 0
	for _, w in weights do
		total += w
	end
	local roll = rng:NextNumber() * total
	for id, w in weights do
		roll -= w
		if roll <= 0 then
			return id
		end
	end
	return next(weights) :: string
end

local function makePart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CastShadow = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(part :: any)[k] = v
	end
	return part
end

-- Builds a chunky rock with ore pieces poking out of it.
local function buildOreModel(resource: Resources.Resource, placement: CFrame, rich: boolean, health: number): Model
	local model = Instance.new("Model")
	model.Name = (if rich then "Rich_" else "Ore_") .. resource.Id

	local scale = rng:NextNumber(0.9, 1.25) * (if rich then 1.2 else 1)
	local up = placement.UpVector
	local base = placement * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local center = base + up * (1.0 * scale)

	local rock = makePart({
		Name = "Rock",
		Size = Vector3.new(3.4, 2.6, 3.0) * scale,
		CFrame = center * CFrame.Angles(rng:NextNumber(-0.25, 0.25), 0, rng:NextNumber(-0.25, 0.25)),
		Material = Enum.Material.Slate,
		Color = resource.RockColor,
	})
	rock.Parent = model
	model.PrimaryPart = rock

	local cap = makePart({
		Name = "RockCap",
		Size = Vector3.new(2.4, 1.6, 2.4) * scale,
		CFrame = center * CFrame.new(0, 0.9 * scale, 0) * CFrame.Angles(0, math.rad(45), rng:NextNumber(-0.3, 0.3)),
		Material = Enum.Material.Slate,
		Color = resource.RockColor,
		CanCollide = false,
	})
	cap.Parent = model

	-- A tilted slab breaks up the boxy silhouette.
	local slab = makePart({
		Name = "RockSlab",
		Size = Vector3.new(2.6, 1.4, 3.4) * scale,
		CFrame = center * CFrame.new(rng:NextNumber(-0.8, 0.8) * scale, -0.2 * scale, 0)
			* CFrame.Angles(rng:NextNumber(0.3, 0.7), rng:NextNumber(0, 6), rng:NextNumber(-0.4, 0.4)),
		Material = Enum.Material.Slate,
		Color = resource.RockColor:Lerp(Color3.new(0, 0, 0), 0.15),
		CanCollide = false,
	})
	slab.Parent = model

	local chunks = rng:NextInteger(4, 6) + (if rich then 4 else 0)
	for i = 1, chunks do
		local angle = (i / chunks) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local offset = Vector3.new(math.cos(angle) * 1.5, rng:NextNumber(-0.1, 1.4), math.sin(angle) * 1.3) * scale
		local s = rng:NextNumber(0.9, 1.45) * scale
		local chunk = makePart({
			Name = "Vein",
			Size = Vector3.new(s, s * rng:NextNumber(0.7, 1.1), s),
			CFrame = center * CFrame.new(offset) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6)),
			Material = resource.OreMaterial,
			Color = resource.OreColor,
			CanCollide = false,
			CastShadow = false,
		})
		if resource.Glow then
			chunk.Material = Enum.Material.Neon
			chunk.Transparency = 0.15
		end
		chunk.Parent = model
	end
	if resource.Glow or rich then
		local light = Instance.new("PointLight")
		light.Color = resource.OreColor
		light.Range = if rich then 14 else 10
		light.Brightness = if rich then 1.4 else 0.8
		light.Parent = rock
	end
	if rich then
		-- Sparkles make rich veins stand out from across a chamber.
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Name = "RichSparkle"
		sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkle.Color = ColorSequence.new(resource.OreColor:Lerp(Color3.new(1, 1, 1), 0.5))
		sparkle.LightEmission = 1
		sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		sparkle.Lifetime = NumberRange.new(0.6, 1.2)
		sparkle.Rate = 10
		sparkle.Speed = NumberRange.new(0.5, 1.5)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		sparkle.Parent = rock
	end

	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanTouch = false
		end
	end

	model:SetAttribute("ResourceId", resource.Id)
	model:SetAttribute("Health", health)
	model:SetAttribute("MaxHealth", health)
	model:SetAttribute("Rich", rich)
	CollectionService:AddTag(model, "Ore")
	return model
end

local function spawnOre(mineId: string, zone: Mines.Zone, point: BasePart, container: Instance)
	local resource = Resources.Get(pickResource(zone.Weights))
	if not resource then
		return
	end
	-- Random events (Lucky Hour) can boost the rich chance for everyone.
	local boost = (ReplicatedStorage:GetAttribute("RichMultiplier") :: number?) or 1
	local rich = rng:NextNumber() < (zone.RichChance or 0) * boost
	local health = math.ceil(resource.Health * (if rich then RICH_HEALTH_MULT else 1))
	local model = buildOreModel(resource, point.CFrame, rich, health)
	model:SetAttribute("Zone", zone.Id)
	ores[model] = {
		ResourceId = resource.Id,
		MineId = mineId,
		ZoneId = zone.Id,
		Health = health,
		MaxHealth = health,
		Rich = rich,
		Point = point,
	}
	occupied[point] = true
	model.Parent = container
end

local function freePoints(points: { BasePart }): { BasePart }
	local free = {}
	for _, p in points do
		if not occupied[p] then
			table.insert(free, p)
		end
	end
	return free
end

local function fillZone(mineId: string, zone: Mines.Zone, points: { BasePart }, container: Instance)
	local alive = 0
	for _, state in ores do
		if state.MineId == mineId and state.ZoneId == zone.Id then
			alive += 1
		end
	end
	local free = freePoints(points)
	while alive < zone.MaxOres and #free > 0 do
		local idx = rng:NextInteger(1, #free)
		spawnOre(mineId, zone, free[idx], container)
		table.remove(free, idx)
		alive += 1
	end
end

local zoneRuntime: { [string]: { Zone: Mines.Zone, Points: { BasePart }, Container: Instance, MineId: string } } = {}

function OreService:Yield(state: OreState): number
	return (state.Yield or 1) * (if state.Rich then RICH_YIELD else 1)
end

export type AbyssOre = { Health: number, Yield: number, Rich: boolean, Owner: Player, Floor: number }

-- Spawns a one-off ore on an abyss floor at `placement` (UpVector = surface
-- normal). It never respawns and only `opts.Owner` can mine it.
function OreService:SpawnAbyss(resourceId: string, placement: CFrame, container: Instance, opts: AbyssOre): Model?
	local resource = Resources.Get(resourceId)
	if not resource then
		return nil
	end
	local health = math.ceil(opts.Health * (if opts.Rich then RICH_HEALTH_MULT else 1))
	local model = buildOreModel(resource, placement, opts.Rich, health)
	model:SetAttribute("Zone", "Abyss")
	ores[model] = {
		ResourceId = resource.Id,
		MineId = "Abyss",
		ZoneId = "F" .. opts.Floor,
		Health = health,
		MaxHealth = health,
		Rich = opts.Rich,
		Point = nil,
		Yield = opts.Yield,
		Owner = opts.Owner,
	}
	model.Parent = container
	return model
end

-- Forgets ores whose models were destroyed with their floor.
function OreService:Forget(container: Instance)
	for model in ores do
		if model:IsDescendantOf(container) or not model.Parent then
			ores[model] = nil
		end
	end
end

-- Live ore models whose pivot is within `radius` of `position`.
function OreService:Nearby(position: Vector3, radius: number): { Model }
	local found = {}
	for model in ores do
		if (model:GetPivot().Position - position).Magnitude <= radius then
			table.insert(found, model)
		end
	end
	return found
end

-- Spawns a one-off ore (not part of any zone, never respawns), e.g. event
-- meteorites. `point` only provides the placement CFrame.
function OreService:SpawnSpecial(resourceId: string, point: BasePart, container: Instance, rich: boolean): Model?
	local resource = Resources.Get(resourceId)
	if not resource then
		return nil
	end
	local health = math.ceil(resource.Health * (if rich then RICH_HEALTH_MULT else 1))
	local model = buildOreModel(resource, point.CFrame, rich, health)
	model:SetAttribute("Zone", "Event")
	ores[model] = {
		ResourceId = resource.Id,
		MineId = "Surface",
		ZoneId = "Event",
		Health = health,
		MaxHealth = health,
		Rich = rich,
		Point = nil,
	}
	model.Parent = container
	return model
end

-- Turns up to `count` ordinary ores in a mine zone into rich veins (Rich
-- Seam event). Returns how many were converted.
function OreService:MakeRich(mineId: string, zoneId: string, count: number): number
	local candidates = {}
	for model, state in ores do
		if state.MineId == mineId and state.ZoneId == zoneId and not state.Rich and state.Point then
			table.insert(candidates, model)
		end
	end
	local converted = 0
	while converted < count and #candidates > 0 do
		local model = table.remove(candidates, rng:NextInteger(1, #candidates)) :: Model
		local state = ores[model]
		local resource = Resources.Get(state.ResourceId)
		if resource and state.Point then
			local health = math.ceil(resource.Health * RICH_HEALTH_MULT)
			local replacement = buildOreModel(resource, state.Point.CFrame, true, health)
			replacement:SetAttribute("Zone", state.ZoneId)
			ores[replacement] = {
				ResourceId = state.ResourceId,
				MineId = state.MineId,
				ZoneId = state.ZoneId,
				Health = health,
				MaxHealth = health,
				Rich = true,
				Point = state.Point,
			}
			replacement.Parent = model.Parent
			ores[model] = nil
			model:Destroy()
			converted += 1
		end
	end
	return converted
end

function OreService:Get(model: Instance): OreState?
	return ores[model :: Model]
end

-- Applies damage; returns (newHealth, broken).
function OreService:Damage(model: Model, amount: number): (number, boolean)
	local state = ores[model]
	if not state then
		return 0, false
	end
	state.Health = math.max(0, state.Health - amount)
	model:SetAttribute("Health", state.Health)
	if state.Health > 0 then
		return state.Health, false
	end

	ores[model] = nil
	model:Destroy()
	local key = state.MineId .. "/" .. state.ZoneId
	local runtime = zoneRuntime[key]
	-- Keep the spot reserved for a moment so a new rock doesn't pop into the
	-- exact place the player is still swinging at.
	if not state.Point then
		return 0, true -- special ore: never respawns
	end
	task.delay(runtime and runtime.Zone.RespawnSeconds or 8, function()
		occupied[state.Point :: BasePart] = nil
		if runtime then
			fillZone(runtime.MineId, runtime.Zone, runtime.Points, runtime.Container)
		end
	end)
	return 0, true
end

function OreService:Init()
	local minesFolder = workspace:WaitForChild("Mines")
	for mineId, mine in Mines.ById do
		local mineFolder = minesFolder:FindFirstChild(mineId)
		local spawns = mineFolder and mineFolder:FindFirstChild("OreSpawns")
		if not spawns then
			warn(`[OreService] {mineId} has no OreSpawns folder`)
			continue
		end
		local container = mineFolder:FindFirstChild("ActiveOres") or Instance.new("Folder")
		container.Name = "ActiveOres"
		container.Parent = mineFolder

		for _, zone in mine.Zones do
			local zoneFolder = spawns:FindFirstChild(zone.Id)
			local points: { BasePart } = {}
			if zoneFolder then
				for _, p in zoneFolder:GetChildren() do
					if p:IsA("BasePart") then
						table.insert(points, p)
					end
				end
			end
			if #points == 0 and zone.MaxOres > 0 then
				warn(`[OreService] {mineId}/{zone.Id} has no spawn points`)
			end
			zoneRuntime[mineId .. "/" .. zone.Id] = { Zone = zone, Points = points, Container = container, MineId = mineId }
			fillZone(mineId, zone, points, container)
		end
	end
end

return OreService
