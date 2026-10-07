--!strict
-- The Endless Abyss. Each player in the Abyss gets their own generated floor
-- in a private slot far below the mines: a chain of terrain chambers joined
-- by tunnels, lit by crystals, with one-off ore (Config/Abyss decides what,
-- how tough and how rewarding). Mining enough of a floor's ore opens the
-- Descent Shaft in the last chamber; descending builds the next floor at the
-- slot's other level, moves the player and removes the old one.
--
-- Run state is mirrored to the player as attributes for the HUD:
--   AbyssFloor (0 = not in the Abyss), AbyssMined, AbyssQuota, AbyssOpen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Abyss = require(Shared.Config.Abyss)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)
local Resources = require(Shared.Config.Resources)

local CreatureService = require(script.Parent.CreatureService)
local DataService = require(script.Parent.DataService)
local MiningService = require(script.Parent.MiningService)
local OreService = require(script.Parent.OreService)
local TravelService = require(script.Parent.TravelService)

local AbyssService = {}

-- Slots sit side by side far from the mines; each has two levels so the
-- next floor can be built before the current one is removed.
local ORIGIN = Vector3.new(6000, -2600, 6000)
local SLOT_SPACING = 1000
local LEVEL_DROP = 120
local MAX_EXTENT = 380 -- chambers stay within +-MAX_EXTENT of the slot centre

type Chamber = { Center: Vector3, W: number, D: number, H: number }

type Floor = {
	Number: number,
	Folder: Folder,
	Chambers: { Chamber },
	BoundsCF: CFrame,
	BoundsSize: Vector3,
	Arrival: CFrame,
	Shaft: BasePart,
	ShaftRing: BasePart,
	Total: number,
}

type Run = {
	Slot: number,
	Level: number, -- 0 or 1: which of the slot's two levels the current floor uses
	Floor: Floor,
	Mined: number,
	Quota: number,
	Open: boolean,
	Busy: boolean,
}

local runs: { [Player]: Run } = {}
local slotOwners: { [number]: Player } = {}
local abyssFolder: Folder

local function snap(v: number): number
	return math.floor(v / 4 + 0.5) * 4
end

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

local function invisible(name: string, cf: CFrame, size: Vector3, parent: Instance, collide: boolean?): Part
	return part({
		Name = name,
		CFrame = cf,
		Size = size,
		Transparency = 1,
		CanCollide = collide == true,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Parent = parent,
	})
end

local function prompt(parent: Instance, action: string, object: string, hold: number): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = hold
	p.MaxActivationDistance = 12
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.GamepadKeyCode = Enum.KeyCode.ButtonX
	p.Parent = parent
	return p
end

local function pickWeighted(rng: Random, weights: { [string]: number }): string
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

-- Random walk of chambers on one flat level, each far enough from the others.
local function layoutChambers(rng: Random, count: number, base: Vector3): { Chamber }
	local chambers: { Chamber } = {}
	local function add(x: number, z: number)
		table.insert(chambers, {
			Center = Vector3.new(snap(x), base.Y, snap(z)),
			W = snap(rng:NextInteger(36, 52)),
			D = snap(rng:NextInteger(36, 52)),
			H = snap(rng:NextInteger(22, 28)),
		})
	end
	add(base.X, base.Z)
	local heading = rng:NextNumber(0, math.pi * 2)
	for _ = 2, count do
		local placed = false
		for _ = 1, 14 do
			local h = heading + rng:NextNumber(-1.1, 1.1)
			local last = chambers[#chambers].Center
			local dist = rng:NextNumber(66, 86)
			local x, z = last.X + math.cos(h) * dist, last.Z + math.sin(h) * dist
			if math.abs(x - base.X) > MAX_EXTENT or math.abs(z - base.Z) > MAX_EXTENT then
				continue
			end
			local clear = true
			for _, c in chambers do
				if (Vector3.new(x, 0, z) - Vector3.new(c.Center.X, 0, c.Center.Z)).Magnitude < 58 then
					clear = false
					break
				end
			end
			if clear then
				heading = h
				add(x, z)
				placed = true
				break
			end
		end
		if not placed then
			break
		end
	end
	return chambers
end

local function carve(chambers: { Chamber }, band: Abyss.Band, rng: Random): (CFrame, Vector3)
	local terrain = workspace.Terrain
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, c in chambers do
		minX = math.min(minX, c.Center.X - c.W / 2)
		maxX = math.max(maxX, c.Center.X + c.W / 2)
		minZ = math.min(minZ, c.Center.Z - c.D / 2)
		maxZ = math.max(maxZ, c.Center.Z + c.D / 2)
	end
	local margin = 28
	local floorY = chambers[1].Center.Y
	local size = Vector3.new(snap(maxX - minX + margin * 2), 64, snap(maxZ - minZ + margin * 2))
	local boundsCF = CFrame.new(snap((minX + maxX) / 2), floorY + 20, snap((minZ + maxZ) / 2))

	terrain:FillBlock(boundsCF, size, band.Rock)
	terrain:FillBlock(CFrame.new(boundsCF.X, floorY - 4, boundsCF.Z), Vector3.new(size.X, 8, size.Z), band.Floor)

	for i, c in chambers do
		terrain:FillBlock(CFrame.new(c.Center.X, floorY + c.H / 2, c.Center.Z), Vector3.new(c.W, c.H, c.D), Enum.Material.Air)
		-- Bulges in the walls and a domed ceiling so rooms aren't boxes. Ball
		-- bottoms stay at floor level so the floor has no holes.
		for _ = 1, 5 do
			local r = rng:NextNumber(7, 12)
			local side = rng:NextInteger(1, 4)
			local ox = if side <= 2 then (if side == 1 then 1 else -1) * c.W / 2 else rng:NextNumber(-c.W / 2, c.W / 2)
			local oz = if side > 2 then (if side == 3 then 1 else -1) * c.D / 2 else rng:NextNumber(-c.D / 2, c.D / 2)
			terrain:FillBall(Vector3.new(c.Center.X + ox, floorY + r, c.Center.Z + oz), r, Enum.Material.Air)
		end
		terrain:FillBall(Vector3.new(c.Center.X, floorY + c.H - 6, c.Center.Z), math.min(c.W, c.D) / 2 - 4, Enum.Material.Air)
		-- Tunnel to the next chamber (flat floor, same level).
		local nxt = chambers[i + 1]
		if nxt then
			local a = Vector3.new(c.Center.X, floorY + 8, c.Center.Z)
			local b = Vector3.new(nxt.Center.X, floorY + 8, nxt.Center.Z)
			terrain:FillBlock(CFrame.lookAt((a + b) / 2, b), Vector3.new(14, 16, (b - a).Magnitude), Enum.Material.Air)
		end
	end
	return boundsCF, size
end

local function crystal(parent: Instance, at: Vector3, color: Color3, rng: Random)
	local height = rng:NextNumber(4, 7)
	local c = part({
		Name = "Crystal",
		Size = Vector3.new(1.6, height, 1.6),
		CFrame = CFrame.new(at + Vector3.new(0, height / 2 - 0.5, 0)) * CFrame.Angles(rng:NextNumber(-0.35, 0.35), rng:NextNumber(0, 6), rng:NextNumber(-0.35, 0.35)),
		Material = Enum.Material.Neon,
		Color = color,
		CanCollide = false,
		CastShadow = false,
		Parent = parent,
	})
	local small = c:Clone()
	small.Size = Vector3.new(1, height * 0.55, 1)
	small.CFrame = CFrame.new(at + Vector3.new(1.2, height * 0.25, 0.6)) * CFrame.Angles(0.4, rng:NextNumber(0, 6), 0.3)
	small.Parent = parent
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 22
	light.Brightness = 1.1
	light.Shadows = false
	light.Parent = c
end

local function buildFloor(player: Player, number: number, base: Vector3): Floor
	local rng = Random.new()
	local band = Abyss.BandFor(number)
	local folder = Instance.new("Folder")
	folder.Name = `Floor_{player.UserId}_{number}`

	local chambers = layoutChambers(rng, Abyss.ChamberCount(number), base)
	local boundsCF, boundsSize = carve(chambers, band, rng)
	local floorY = base.Y
	-- Terrain renders its surface half a voxel above the carved level, so
	-- everything placed on the floor uses the visible surface instead.
	for _, c in chambers do
		c.Center += Vector3.new(0, 2, 0)
	end

	-- Zone volume for lighting/ambience on the client, and an invisible slab
	-- just under the floor so nobody falls if terrain streams in late.
	local volumes = Instance.new("Folder")
	volumes.Name = "ZoneVolumes"
	volumes.Parent = folder
	local volume = invisible("Floor", CFrame.new(boundsCF.X, floorY + 24, boundsCF.Z), Vector3.new(boundsSize.X, 56, boundsSize.Z), volumes)
	volume:SetAttribute("ZoneId", "F" .. number)
	invisible("SafetyFloor", CFrame.new(boundsCF.X, floorY - 1.5, boundsCF.Z), Vector3.new(boundsSize.X, 1, boundsSize.Z), folder, true)

	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = folder
	local ores = Instance.new("Folder")
	ores.Name = "ActiveOres"
	ores.Parent = folder

	local first, last = chambers[1], chambers[#chambers]
	local toNext = if chambers[2] then (chambers[2].Center - first.Center).Unit else Vector3.new(0, 0, -1)

	-- Arrival and the rope back to camp, at the back of the first chamber.
	local arrival = CFrame.lookAt(first.Center + Vector3.new(0, 3, 0), first.Center + toNext * 10 + Vector3.new(0, 3, 0))
	local ropeAt = first.Center - toNext * math.min(first.W, first.D) * 0.3
	local rope = part({
		Name = "ExitRope",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(first.H, 0.6, 0.6),
		CFrame = CFrame.new(ropeAt + Vector3.new(0, first.H / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Fabric,
		Color = Color3.fromRGB(196, 160, 110),
		CanCollide = false,
		Parent = decor,
	})
	local lamp = part({
		Name = "RopeLamp",
		Size = Vector3.new(1.2, 1.6, 1.2),
		CFrame = CFrame.new(ropeAt + Vector3.new(0, 3.5, 0)),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 200, 120),
		CanCollide = false,
		Parent = decor,
	})
	local lampLight = Instance.new("PointLight")
	lampLight.Color = Color3.fromRGB(255, 200, 120)
	lampLight.Range = 18
	lampLight.Parent = lamp
	-- The prompt sits on the lamp at chest height (the rope's centre is out of reach).
	local exitPrompt = prompt(lamp, "Climb to Camp", "Exit Rope", 0.4)
	exitPrompt.Triggered:Connect(function(who)
		if who == player then
			AbyssService:Leave(player, true)
		end
	end)

	-- Descent Shaft in the centre of the last chamber: a glowing rim around
	-- a black pit (the rim turns the band's colour when the shaft opens).
	local shaft = part({
		Name = "DescentShaft",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 12.5, 12.5),
		CFrame = CFrame.new(last.Center + Vector3.new(0, 1.05, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(2, 1, 3),
		CanCollide = false,
		Parent = decor,
	})
	local ring = part({
		Name = "ShaftRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.2, 15, 15),
		CFrame = CFrame.new(last.Center + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(120, 30, 30),
		CanCollide = false,
		CastShadow = false,
		Parent = decor,
	})
	local ringLight = Instance.new("PointLight")
	ringLight.Color = ring.Color
	ringLight.Range = 16
	ringLight.Brightness = 0.8
	ringLight.Parent = ring
	local motes = Instance.new("ParticleEmitter")
	motes.Name = "OpenMotes"
	motes.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	motes.LightEmission = 1
	motes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	motes.Lifetime = NumberRange.new(1.5, 2.5)
	motes.Speed = NumberRange.new(4, 8)
	motes.SpreadAngle = Vector2.new(12, 12)
	motes.Rate = 18
	motes.EmissionDirection = Enum.NormalId.Right -- the cylinder's X axis points up
	motes.Enabled = false
	motes.Parent = ring
	local descend = prompt(shaft, "Descend", "Descent Shaft", 0.6)
	descend.Triggered:Connect(function(who)
		if who == player then
			AbyssService:Descend(player)
		end
	end)

	-- Light, ore, hazards, creatures.
	local floorTotal = 0
	local richBoost = (ReplicatedStorage:GetAttribute("RichMultiplier") :: number?) or 1
	for i, c in chambers do
		for k = 1, 3 do
			local angle = (k / 3) * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
			local at = c.Center + Vector3.new(math.cos(angle) * (c.W / 2 - 3), 0, math.sin(angle) * (c.D / 2 - 3))
			crystal(decor, at, band.Glow, rng)
		end
		if i == 1 then
			continue -- the arrival chamber is a safe, ore-free landing
		end
		local count = math.min(rng:NextInteger(4, 6) + number // 10, 9)
		local placed: { Vector3 } = {}
		for _ = 1, count * 6 do
			if #placed >= count then
				break
			end
			local at = c.Center + Vector3.new(rng:NextNumber(-c.W / 2 + 6, c.W / 2 - 6), 0, rng:NextNumber(-c.D / 2 + 6, c.D / 2 - 6))
			local ok = not (c == last and (at - last.Center).Magnitude < 10)
			for _, p in placed do
				if (p - at).Magnitude < 7 then
					ok = false
					break
				end
			end
			if ok then
				table.insert(placed, at)
				local resourceId = pickWeighted(rng, band.Weights)
				local resource = Resources.Get(resourceId)
				if resource then
					OreService:SpawnAbyss(resourceId, CFrame.new(at), ores, {
						Health = math.ceil(resource.Health * Abyss.HealthMultiplier(number)),
						Yield = Abyss.Yield(number),
						Rich = rng:NextNumber() < Abyss.RichChance(number) * richBoost,
						Owner = player,
						Floor = number,
					})
					floorTotal += 1
				end
			end
		end
		if band.Hazard then
			local v = invisible("Hazard_" .. band.Hazard.Type, CFrame.new(c.Center + Vector3.new(0, c.H / 2, 0)),
				Vector3.new(c.W + 8, c.H + 4, c.D + 8), folder)
			v:SetAttribute("Type", band.Hazard.Type)
			v:SetAttribute("Level", band.Hazard.Level)
			v:SetAttribute("DamagePerSecond", band.Hazard.DamagePerSecond)
			CollectionService:AddTag(v, "Hazard")
		end
	end

	if band.Creatures and band.CreaturesPerFloor and #chambers > 1 then
		local spawns = Instance.new("Folder")
		spawns.Name = "CreatureSpawns"
		spawns.Parent = folder
		local active = Instance.new("Folder")
		active.Name = "ActiveCreatures"
		active.Parent = folder
		local amount = math.min(band.CreaturesPerFloor + (number - band.First) // 10, 5)
		for _ = 1, amount do
			local c = chambers[rng:NextInteger(2, #chambers)]
			local at = c.Center + Vector3.new(rng:NextNumber(-c.W / 4, c.W / 4), 3, rng:NextNumber(-c.D / 4, c.D / 4))
			local sp = invisible("Spawn", CFrame.new(at), Vector3.new(2, 2, 2), spawns)
			sp:SetAttribute("Kind", pickWeighted(rng, band.Creatures))
			sp:SetAttribute("HealthMult", Abyss.CreatureHealthMultiplier(number))
		end
		folder.Parent = abyssFolder
		for _, sp in spawns:GetChildren() do
			CreatureService:SpawnAt(sp :: BasePart, active)
		end
	end

	folder.Parent = abyssFolder
	return {
		Number = number,
		Folder = folder,
		Chambers = chambers,
		BoundsCF = boundsCF,
		BoundsSize = boundsSize,
		Arrival = arrival,
		Shaft = shaft,
		ShaftRing = ring,
		Total = floorTotal,
	}
end

local function destroyFloor(floor: Floor)
	workspace.Terrain:FillBlock(floor.BoundsCF, floor.BoundsSize + Vector3.new(0, 8, 0), Enum.Material.Air)
	floor.Folder:Destroy()
	OreService:Forget(floor.Folder)
end

local function slotBase(slot: number, level: number): Vector3
	return ORIGIN + Vector3.new(slot * SLOT_SPACING, -level * LEVEL_DROP, 0)
end

local function publish(player: Player, run: Run?)
	player:SetAttribute("AbyssFloor", if run then run.Floor.Number else 0)
	player:SetAttribute("AbyssMined", if run then run.Mined else 0)
	player:SetAttribute("AbyssQuota", if run then run.Quota else 0)
	player:SetAttribute("AbyssOpen", if run then run.Open else false)
end

local function setOpen(run: Run, open: boolean)
	run.Open = open
	local band = Abyss.BandFor(run.Floor.Number)
	run.Floor.ShaftRing.Color = if open then band.Glow else Color3.fromRGB(120, 30, 30)
	local motes = run.Floor.ShaftRing:FindFirstChild("OpenMotes") :: ParticleEmitter?
	if motes then
		motes.Color = ColorSequence.new(band.Glow)
		motes.Enabled = open
	end
	local light = run.Floor.ShaftRing:FindFirstChildOfClass("PointLight")
	if light then
		light.Color = run.Floor.ShaftRing.Color
		light.Brightness = if open then 2 else 0.8
		light.Range = if open then 24 else 16
	end
end

-- Moves the run onto floor `number` (built at the slot's other level), then
-- removes the floor the player came from.
local function goToFloor(player: Player, run: Run?, slot: number, number: number): Run
	local level = if run then 1 - run.Level else 0
	local floor = buildFloor(player, number, slotBase(slot, level))
	local old = run and run.Floor
	local newRun: Run = {
		Slot = slot,
		Level = level,
		Floor = floor,
		Mined = 0,
		Quota = math.max(1, math.ceil(floor.Total * Abyss.QuotaFraction)),
		Open = false,
		Busy = true,
	}
	runs[player] = newRun
	pcall(function()
		player:RequestStreamAroundAsync(floor.Arrival.Position, 5)
	end)
	local band = Abyss.BandFor(number)
	TravelService:Teleport(player, floor.Arrival, {
		title = `FLOOR {number}`,
		subtitle = `The Endless Abyss · {band.Name}`,
	})
	publish(player, newRun)
	if old then
		destroyFloor(old)
	end
	newRun.Busy = false

	-- Records and warnings.
	local data = DataService:Get(player)
	if data and number > (data.Abyss.Best or 0) then
		local bonus = Abyss.RecordBonus(number)
		DataService:Update(player, function(d)
			d.Abyss.Best = number
			d.Cash += bonus
			d.Stats.TotalEarned += bonus
		end)
		Remotes.Event("Notify"):FireClient(player, `New depth record: floor {number}! +{Format.Cash(bonus)}`, "Good")
	end
	if band.First == number and band.Hazard then
		local suitHint = if band.Hazard.Type == "Heat"
			then (if band.Hazard.Level >= 2 then "a Magma Suit" else "a Heat Suit")
			else (if band.Hazard.Level >= 2 then "the Abyss Suit" else "a Void Suit")
		Remotes.Event("Notify"):FireClient(player, `{band.Name}: you'll need {suitHint} down here.`, "Warn")
	end
	return newRun
end

local function freeSlot(player: Player): number?
	for slot = 0, 63 do
		if not slotOwners[slot] then
			slotOwners[slot] = player
			return slot
		end
	end
	return nil
end

-- Called by the camp lift. Starts a run at the player's last checkpoint.
function AbyssService:Enter(player: Player): (boolean, string)
	local data = DataService:Get(player)
	if not data or not Abyss.IsUnlocked(data) then
		return false, "Complete the Unknown Depths to unlock the Abyss"
	end
	if runs[player] then
		return false, "You're already in the Abyss"
	end
	local slot = freeSlot(player)
	if not slot then
		return false, "The Abyss is crowded right now, try again soon"
	end
	local start = Abyss.StartFloor(data.Abyss.Best or 0)
	task.spawn(function()
		local ok, err = pcall(goToFloor, player, nil, slot, start)
		if not ok then
			warn("[AbyssService] Failed to build floor:", err)
			AbyssService:Leave(player, true)
		end
	end)
	return true, "Descending into the Abyss..."
end

function AbyssService:Descend(player: Player)
	local run = runs[player]
	if not run or run.Busy then
		return
	end
	if not run.Open then
		Remotes.Event("Notify"):FireClient(player,
			`The shaft is sealed. Mine {run.Quota - run.Mined} more ore on this floor to open it.`, "Warn")
		return
	end
	run.Busy = true
	local ok, err = pcall(goToFloor, player, run, run.Slot, run.Floor.Number + 1)
	if not ok then
		warn("[AbyssService] Failed to build floor:", err)
		run.Busy = false
	end
end

-- Ends the run: optionally sends the player back to camp, then removes the floor.
function AbyssService:Leave(player: Player, toCamp: boolean)
	local run = runs[player]
	runs[player] = nil
	if toCamp and player.Parent then
		local camp = TravelService:ArrivalFor("Camp")
		if camp then
			TravelService:Teleport(player, camp, { title = "Camp", subtitle = "Back on the surface" })
		end
	end
	if run then
		destroyFloor(run.Floor)
		if slotOwners[run.Slot] == player then
			slotOwners[run.Slot] = nil
		end
	else
		for slot, owner in slotOwners do
			if owner == player then
				slotOwners[slot] = nil
			end
		end
	end
	if player.Parent then
		publish(player, nil)
	end
end

-- Studio testing: open the current shaft without mining.
function AbyssService:DebugOpen(player: Player): boolean
	local run = runs[player]
	if not run then
		return false
	end
	run.Mined = run.Quota
	setOpen(run, true)
	publish(player, run)
	return true
end

function AbyssService:IsInAbyss(player: Player): boolean
	return runs[player] ~= nil
end

function AbyssService:Init()
	abyssFolder = Instance.new("Folder")
	abyssFolder.Name = "Abyss"
	abyssFolder.Parent = workspace

	TravelService.EnterAbyss = function(player: Player)
		return AbyssService:Enter(player)
	end

	MiningService.OreBroken:Connect(function(player: Player, ore: any)
		local run = runs[player]
		if not run or ore.MineId ~= "Abyss" or ore.ZoneId ~= "F" .. run.Floor.Number then
			return
		end
		run.Mined += 1
		if not run.Open and run.Mined >= run.Quota then
			setOpen(run, true)
			Remotes.Event("Notify"):FireClient(player, "The Descent Shaft is open! Find it in the deepest chamber.", "Good")
		end
		publish(player, run)
	end)

	local function watch(player: Player)
		publish(player, nil)
		-- Dying (or any respawn) ends the run; the new character spawns at camp.
		player.CharacterAdded:Connect(function()
			if runs[player] then
				AbyssService:Leave(player, false)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		AbyssService:Leave(player, false)
	end)
end

return AbyssService
