-- Mine 5: Unknown Depths (endgame). Arrival -> Shimmering Expanse -> (Living
-- Membrane, Void Pickaxe) -> Spore Forest (corrosive air: Void Suit) ->
-- (Gravity Rift) -> Abyss Core (Void level 2: Abyss Suit) -> The Last Seal ->
-- the Heart of the Deep. Hidden: the Hollow, off the west forest cave.
-- Creatures spawn from Workspace.Mines.Mine5.CreatureSpawns (CreatureService).
do
local F_EXP, F_FOREST, F_CORE = -1074, -1084, -1095
local VOID = Color3.fromRGB(150, 70, 255)
local TEAL = Color3.fromRGB(80, 255, 190)
local PINK = Color3.fromRGB(255, 90, 200)
local ACID = Color3.fromRGB(120, 255, 80)
local ALIEN_COLORS = { VOID, TEAL, PINK, Color3.fromRGB(90, 160, 255) }

T:FillBlock(CFrame.new(0, -1080, -800), Vector3.new(460, 220, 540), Enum.Material.Salt)
-- Salt, LeafyGrass and Concrete only appear down here, so their global colours are ours.
T:SetMaterialColor(Enum.Material.Salt, Color3.fromRGB(46, 34, 62))
T:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(86, 40, 120))
T:SetMaterialColor(Enum.Material.Concrete, Color3.fromRGB(26, 18, 36))

local chambers = {
	Arrival = { Zone = "Expanse", C = Vector2.new(0, -612), F = -1070, rx = 10, rz = 8, Points = 0 },
	Expanse = { Zone = "Expanse", C = Vector2.new(0, -680), F = F_EXP, rx = 44, rz = 30, Points = 24, Tall = true },
	ExpanseEast = { Zone = "Expanse", C = Vector2.new(62, -706), F = -1072, rx = 16, rz = 14, Points = 8 },
	Forest = { Zone = "Forest", C = Vector2.new(0, -812), F = F_FOREST, rx = 54, rz = 40, Points = 30, Tall = true },
	ForestWest = { Zone = "Forest", C = Vector2.new(-80, -830), F = -1082, rx = 18, rz = 15, Points = 10 },
	Hollow = { Zone = "Hollow", C = Vector2.new(-150, -836), F = -1083, rx = 10, rz = 9, Points = 6 },
	Core = { Zone = "Core", C = Vector2.new(0, -950), F = F_CORE, rx = 46, rz = 34, Points = 26, Tall = true },
	CoreEast = { Zone = "Core", C = Vector2.new(64, -972), F = -1098, rx = 16, rz = 13, Points = 8 },
	SealHall = { Zone = "Final", C = Vector2.new(0, -1000), F = -1096, rx = 20, rz = 8, Points = 0, Tall = true },
	Heart = { Zone = "Heart", C = Vector2.new(0, -1044), F = -1096, rx = 14, rz = 10, Points = 0, Tall = true },
}

local tunnels = {
	ArrivalToExpanse = { Vector3.new(0, -1063, -618), Vector3.new(0, -1065, -636), Vector3.new(0, -1067, -652) },
	ExpanseEast = { Vector3.new(30, -1067, -694), Vector3.new(46, -1065, -702) },
	Membrane = { Vector3.new(0, -1067, -712), Vector3.new(0, -1069, -726), Vector3.new(0, -1072, -740),
		Vector3.new(0, -1075, -754), Vector3.new(0, -1077, -772) },
	ForestWest = { Vector3.new(-42, -1077, -822), Vector3.new(-62, -1075, -828) },
	Rift = { Vector3.new(0, -1077, -852), Vector3.new(0, -1080, -866), Vector3.new(0, -1083, -880),
		Vector3.new(0, -1086, -894), Vector3.new(0, -1088, -912) },
	CoreEast = { Vector3.new(34, -1088, -962), Vector3.new(50, -1091, -968) },
	Seal = { Vector3.new(0, -1088, -984), Vector3.new(0, -1089, -992) },
}
local crawl = { Vector3.new(-100, -1076, -832), Vector3.new(-118, -1076, -834), Vector3.new(-136, -1076, -835) }

local function gateDir(path, i)
	return (path[i + 1] - path[i - 1]).Unit
end

local SEAL_Z = -1018

for _, ch in chambers do
	carveChamber(ch)
end
for _, path in tunnels do
	carveTunnel(path)
end
carveTunnel(crawl, 5)
T:FillBlock(CFrame.new(0, -1096 + 18, SEAL_Z + 8), Vector3.new(54, 36, 16), AIR)
carveTunnel({ Vector3.new(0, -1089, SEAL_Z - 2), Vector3.new(0, -1089, SEAL_Z - 14) }, 8)
-- Beyond the Heart: a passage south to the portal into Mine 6. It lies past
-- the edge of the mine's rock block, so give it rock first.
T:FillBlock(CFrame.new(0, -1080, -1100), Vector3.new(80, 60, 60), Enum.Material.Salt)
carveTunnel({ Vector3.new(0, -1089, -1056), Vector3.new(0, -1089, -1084) }, 8)
carveChamber({ C = Vector2.new(0, -1094), F = -1096, rx = 12, rz = 8, Tall = true })

-- Alien moss in the forest, dark glassy floor in the core.
T:ReplaceMaterial(Region3.new(Vector3.new(-110, F_FOREST - 8, -880), Vector3.new(110, F_FOREST + 2, -760)):ExpandToGrid(4), 4,
	Enum.Material.Salt, Enum.Material.LeafyGrass)
T:ReplaceMaterial(Region3.new(Vector3.new(-90, F_CORE - 8, -1060), Vector3.new(90, F_CORE + 2, -900)):ExpandToGrid(4), 4,
	Enum.Material.Salt, Enum.Material.Concrete)

local mine = folder("Mine5", minesFolder)
local props = folder("Props", mine)
local spawnsFolder = folder("OreSpawns", mine)
local gatesFolder = folder("Gates", mine)
local volumes = folder("ZoneVolumes", mine)
local hazards = folder("Hazards", mine)
local creatureSpawns = folder("CreatureSpawns", mine)

-- Acid pools in the forest and core.
local function acidPool(center, radius, F)
	T:FillBall(Vector3.new(center.X, F - radius * 0.6, center.Z), radius, AIR)
	local cf = CFrame.new(center.X, F - 2.5, center.Z) * CFrame.Angles(0, 0, math.rad(90))
	local pool = P({ Name = "Acid", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, radius * 1.9, radius * 1.9), CFrame = cf,
		Material = Enum.Material.Neon, Color = ACID, Transparency = 0.15, CanCollide = false, CanQuery = false, CastShadow = false,
		Parent = props })
	local light = Instance.new("PointLight")
	light.Color = ACID
	light.Range = radius * 3
	light.Brightness = 1.2
	light.Parent = pool
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	bubbles.Color = ColorSequence.new(ACID)
	bubbles.LightEmission = 1
	bubbles.Size = NumberSequence.new(0.4, 0)
	bubbles.Lifetime = NumberRange.new(0.8, 1.6)
	bubbles.Rate = 6
	bubbles.Speed = NumberRange.new(1, 3)
	bubbles.EmissionDirection = Enum.NormalId.Right
	bubbles.Parent = pool
	hazardVolume(hazards, "Acid", 99, 40, CFrame.new(center.X, F - 1, center.Z), Vector3.new(radius * 1.7, 5, radius * 1.7))
end
local pools = { Vector3.new(-28, 0, -800), Vector3.new(30, 0, -826), Vector3.new(-20, 0, -950), Vector3.new(26, 0, -936) }
for i, c in pools do
	acidPool(c, 6, if i <= 2 then F_FOREST else F_CORE)
end

waitForTerrain(Vector3.new(chambers.Heart.C.X, chambers.Heart.F + 6, chambers.Heart.C.Y))

local keepClear = { Vector3.new(0, -1070, -612), Vector3.new(0, -1096, SEAL_Z + 6) }
for _, list in { tunnels, { crawl } } do
	for _, path in list do
		table.insert(keepClear, path[1])
		table.insert(keepClear, path[#path])
	end
end
for _, p in pools do
	table.insert(keepClear, p)
end
local zoneFolders = makeOreSpawns(chambers, spawnsFolder, keepClear)

zoneVolume(volumes, "Expanse", CFrame.new(0, -1075, -665), Vector3.new(300, 110, 150))
zoneVolume(volumes, "Forest", CFrame.new(0, -1085, -810), Vector3.new(300, 110, 140))
zoneVolume(volumes, "Core", CFrame.new(0, -1092, -950), Vector3.new(260, 110, 140))
zoneVolume(volumes, "Final", CFrame.new(0, -1090, -1008), Vector3.new(70, 60, 24), 1)
zoneVolume(volumes, "Heart", CFrame.new(0, -1090, -1044), Vector3.new(50, 50, 44), 2)
zoneVolume(volumes, "Heart", CFrame.new(0, -1090, -1090), Vector3.new(50, 50, 48), 2)
zoneVolume(volumes, "Hollow", CFrame.new(-151, -1083, -836), Vector3.new(32, 40, 30), 2)

-- Corrosive air: the forest needs a Void Suit, the core an Abyss Suit.
hazardVolume(hazards, "Void", 1, 18, CFrame.new(0, -1080, -812), Vector3.new(300, 80, 128))
hazardVolume(hazards, "Void", 2, 30, CFrame.new(0, -1090, -948), Vector3.new(260, 80, 128))

----------------------------------------------------------------------------
-- Alien flora and formations
----------------------------------------------------------------------------

local flora = folder("Flora", props)

local function fungus(f, height, color, lit)
	local stalkW = height * 0.12 + 0.4
	P({ Name = "Stalk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, stalkW, stalkW),
		CFrame = CFrame.new(f + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(200, 180, 220), CanCollide = height > 6, Parent = flora })
	local capW = height * 0.7 + 2
	local cap = P({ Name = "Cap", Shape = Enum.PartType.Cylinder, Size = Vector3.new(capW * 0.3, capW, capW),
		CFrame = CFrame.new(f + Vector3.new(0, height, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Neon, Color = color,
		Transparency = 0.1, CanCollide = false, CanQuery = false, CastShadow = false, Parent = flora })
	if lit then
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = math.min(capW * 2.5, 40)
		light.Brightness = 0.9
		light.Parent = cap
	end
end

local function spire(f, height)
	local cf = CFrame.new(f)
	local w = height * 0.22 + 1
	for i = 0, 4 do
		local h = height / 5
		cf = cf * CFrame.new(0, h, 0) * CFrame.Angles(0, math.rad(30), rng:NextNumber(-0.12, 0.12))
		P({ Name = "Spire", Size = Vector3.new(w, h + 0.4, w), CFrame = cf * CFrame.new(0, -h / 2, 0),
			Material = Enum.Material.Slate, Color = Color3.fromRGB(34, 24, 48), Parent = flora })
		P({ Name = "Vein", Size = Vector3.new(0.2, h, w + 0.1), CFrame = cf * CFrame.new(w / 2, -h / 2, 0),
			Material = Enum.Material.Neon, Color = VOID, CanCollide = false, CanQuery = false, Parent = flora })
		w *= 0.78
	end
end

for name, ch in chambers do
	if ch.Points <= 0 then
		continue
	end
	local origin = Vector3.new(ch.C.X, ch.F + 8, ch.C.Y)
	local count = math.floor((ch.rx + ch.rz) / 3.5)
	local placed = 0
	for _ = 1, count * 8 do
		if placed >= count then
			break
		end
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 0.9), rng:NextNumber(-1, 1))
		if dir.Magnitude < 0.1 then
			continue
		end
		local hit = ray(origin, dir.Unit * 70)
		if not hit or not clearOf(hit.Position, keepClear, 10) then
			continue
		end
		local color = ALIEN_COLORS[rng:NextInteger(1, #ALIEN_COLORS)]
		if hit.Normal.Y > 0.6 then
			local roll = rng:NextNumber()
			if roll < 0.55 then
				fungus(hit.Position, rng:NextNumber(3, if ch.Tall then 14 else 8), color, placed % 2 == 0)
			elseif roll < 0.8 then
				spire(hit.Position, rng:NextNumber(8, 22))
			else
				crystalCluster(flora, hit.Position, hit.Normal, rng:NextNumber(1, 2), color, true)
			end
		elseif hit.Normal.Y < -0.5 then
			-- Tendrils hanging from the ceiling.
			local len = rng:NextNumber(4, 12)
			P({ Name = "Tendril", Shape = Enum.PartType.Cylinder, Size = Vector3.new(len, 0.35, 0.35),
				CFrame = CFrame.new(hit.Position - Vector3.new(0, len / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				Material = Enum.Material.Neon, Color = color, Transparency = 0.2, CanCollide = false, CanQuery = false,
				CastShadow = false, Parent = flora })
		else
			crystalCluster(flora, hit.Position, hit.Normal, rng:NextNumber(0.8, 1.6), color, placed % 3 ~= 0)
		end
		placed += 1
	end
	-- A few crystals floating in mid-air.
	if ch.Tall then
		for _ = 1, 4 do
			local p = origin + Vector3.new(rng:NextNumber(-ch.rx, ch.rx) * 0.6, rng:NextNumber(4, 12), rng:NextNumber(-ch.rz, ch.rz) * 0.6)
			crystalCluster(flora, p, Vector3.new(rng:NextNumber(-1, 1), 1, rng:NextNumber(-1, 1)), rng:NextNumber(0.6, 1.1),
				ALIEN_COLORS[rng:NextInteger(1, #ALIEN_COLORS)], true)
		end
	end
end

----------------------------------------------------------------------------
-- Gates
----------------------------------------------------------------------------

-- The Living Membrane: pulsing organic blobs filling the tunnel.
do
	local at = tunnels.Membrane[3]
	local dir = gateDir(tunnels.Membrane, 3)
	local model = folder("Membrane", gatesFolder, "Model")
	local look = CFrame.lookAt(at, at + dir)
	local blocker = P({ Name = "Blocker", Size = Vector3.new(20, 20, 3), CFrame = look, Transparency = 1, Parent = model })
	model.PrimaryPart = blocker
	for _ = 1, 18 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(0, 7)
		local s = rng:NextNumber(4, 8)
		P({ Name = "Flesh", Shape = Enum.PartType.Ball, Size = Vector3.new(s, s, s),
			CFrame = look * CFrame.new(math.cos(a) * r, math.sin(a) * r * 0.9, rng:NextNumber(-1.5, 1.5)),
			Material = Enum.Material.Neon, Color = PINK:Lerp(VOID, rng:NextNumber()), Transparency = 0.35, Parent = model })
	end
	local light = Instance.new("PointLight")
	light.Color = PINK
	light.Range = 22
	light.Brightness = 1.2
	light.Parent = blocker
	local floor = floorBelow(at - dir * 8, 20)
	if floor then
		sign(model, CFrame.lookAt(floor + Vector3.new(4.5, 4, 0), floor + Vector3.new(4.5, 4, 0) - dir), Vector3.new(4.6, 2.2, 0.2),
			"IT'S ALIVE\nNeeds a Void Pickaxe", Color3.fromRGB(255, 160, 230))
		P({ Name = "SignPost", Size = Vector3.new(0.4, 4, 0.4), CFrame = CFrame.new(floor + Vector3.new(4.5, 2, 0)),
			Material = Enum.Material.Wood, Color = WOOD, Parent = model })
	end
	model:SetAttribute("GateId", "Membrane")
	CollectionService:AddTag(model, "Gate")
end

-- The Gravity Rift: rock chunks hanging in the air around a dark vortex.
do
	local at = tunnels.Rift[3]
	local dir = gateDir(tunnels.Rift, 3)
	local model = folder("Rift", gatesFolder, "Model")
	local look = CFrame.lookAt(at, at + dir)
	local blocker = P({ Name = "Blocker", Size = Vector3.new(20, 20, 3), CFrame = look, Transparency = 1, Parent = model })
	model.PrimaryPart = blocker
	P({ Name = "Vortex", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 15, 15), CFrame = look * CFrame.Angles(0, math.rad(90), 0),
		Material = Enum.Material.Neon, Color = Color3.fromRGB(30, 10, 50), Transparency = 0.1, Parent = model })
	for _ = 1, 16 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(3, 8)
		local s = rng:NextNumber(1.5, 3.5)
		P({ Name = "Chunk", Size = Vector3.new(s, s * 0.8, s), CFrame = look * CFrame.new(math.cos(a) * r, math.sin(a) * r, -1.5)
			* CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0),
			Material = Enum.Material.Slate, Color = Color3.fromRGB(40, 30, 56), Parent = model })
	end
	local light = Instance.new("PointLight")
	light.Color = VOID
	light.Range = 24
	light.Brightness = 1.4
	light.Parent = blocker
	model:SetAttribute("GateId", "Rift")
	CollectionService:AddTag(model, "Gate")
end

buildGate(gatesFolder, { Id = "HollowWall", At = crawl[2] + Vector3.new(-4, 0, 0), Dir = gateDir(crawl, 2), Style = "Hidden" })

----------------------------------------------------------------------------
-- Creatures
----------------------------------------------------------------------------

local function creatureSpawn(zone, kind, x, z, F)
	local zf = creatureSpawns:FindFirstChild(zone) or folder(zone, creatureSpawns)
	local f = floorBelow(Vector3.new(x, F + 8, z), 20) or Vector3.new(x, F, z)
	local p = invisible(kind, CFrame.new(f + Vector3.new(0, 1, 0)), Vector3.new(1, 1, 1), zf)
	p:SetAttribute("Kind", kind)
end
creatureSpawn("Expanse", "Crawler", -22, -684, F_EXP)
creatureSpawn("Expanse", "Crawler", 28, -698, F_EXP)
creatureSpawn("Forest", "Crawler", -34, -806, F_FOREST)
creatureSpawn("Forest", "Crawler", 34, -812, F_FOREST)
creatureSpawn("Forest", "Crawler", 6, -836, F_FOREST)
creatureSpawn("Forest", "Crawler", -76, -832, -1082)
creatureSpawn("Core", "Stalker", -26, -942, F_CORE)
creatureSpawn("Core", "Stalker", 24, -962, F_CORE)
creatureSpawn("Core", "Stalker", 0, -930, F_CORE)
creatureSpawn("Core", "Crawler", 62, -972, -1098)
creatureSpawn("Core", "Crawler", -34, -966, F_CORE)

----------------------------------------------------------------------------
-- The Last Seal, the Heart of the Deep, artifacts, arrival and lifts
----------------------------------------------------------------------------

sealedWall(mine, {
	MineId = "Mine5", Title = "The Last Seal", X = 0, Z = SEAL_Z, ProbeY = -1086,
	StoneA = Color3.fromRGB(30, 22, 44), StoneB = Color3.fromRGB(52, 38, 74), FrameColor = Color3.fromRGB(24, 18, 34),
	RuneColor = VOID, CrackColor = Color3.fromRGB(230, 200, 255),
	FireColor = Color3.fromRGB(180, 90, 255), FireColor2 = Color3.fromRGB(80, 20, 200),
})

do
	-- The heart itself: a huge pulsing light at the bottom of the world.
	local f = floorBelow(Vector3.new(0, -1086, -1050), 20) or Vector3.new(0, -1096, -1050)
	local core = P({ Name = "HeartCore", Shape = Enum.PartType.Ball, Size = Vector3.new(9, 9, 9), CFrame = CFrame.new(f + Vector3.new(0, 10, 0)),
		Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 240, 210), CanCollide = false, CastShadow = false, Parent = props })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 230, 200)
	light.Range = 40
	light.Brightness = 2
	light.Parent = core
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		crystalCluster(props, f + Vector3.new(math.cos(a) * 9, 0, math.sin(a) * 7), Vector3.yAxis, 1.6,
			Color3.fromRGB(255, 230, 190), true)
	end
	artifactPedestal(props, "HeartOfTheDeep", f + Vector3.new(0, 0, 6))
	local h = floorBelow(Vector3.new(-154, -1078, -838), 20)
	if h then
		artifactPedestal(props, "VoidEgg", h)
	end
end

do
	local f = floorBelow(Vector3.new(0, -1062, -608), 30) or Vector3.new(0, -1070, -608)
	local arrival = invisible("Arrival", CFrame.lookAt(f + Vector3.new(0, 3.5, 0), f + Vector3.new(0, 3.5, -10)),
		Vector3.new(1, 1, 1), mine)
	arrival:SetAttribute("MineId", "Mine5")
	local lf = floorBelow(Vector3.new(-6, -1062, -612), 30)
	if lf then
		local cage = liftCage(mine, "Lift_UnknownDepths", lf, Vector3.new(1, 0, 0), "Ride to Camp", "Mine Lift")
		cage:SetAttribute("LiftId", "UnknownDepths")
	end
	local ff = floorBelow(Vector3.new(-30, F_FOREST + 8, -786), 20)
	if ff then
		local cage = liftCage(mine, "Lift_SporeForest", ff, Vector3.new(1, 0, -0.3), "Ride to Camp", "Mine Lift")
		cage:SetAttribute("LiftId", "SporeForest")
	end
end

-- The Heart of the Deep wasn't the bottom after all.
buildPortal(mine, { X = 0, Z = -1098, ProbeY = -1086, FromMine = "Mine5", ToMine = "Mine6" })

local counts = {}
for zone, zf in zoneFolders do
	table.insert(counts, zone .. "=" .. #zf:GetChildren())
end
table.insert(buildReport, "Mine5 ore points: " .. table.concat(counts, " ") .. ", flora parts: " .. #flora:GetChildren())
end
