-- Mine 6: The Worldheart (final mine). Reached through the portal beyond the
-- Heart of the Deep in Mine 5. Arrival -> Gilded Vestibule -> (Gilded Seal,
-- Core Pickaxe) -> Radiant Galleries (radiance: Radiant Suit) -> (Star Gate)
-- -> The Worldheart (radiance level 2: Core Suit, Gilded Sentinels) -> The
-- Origin Seal -> The Origin. Hidden: the Sun Treasury, off the east gallery.
-- Same footprint as Mine 5, ~270 studs further down.
do
local F_VEST, F_GAL, F_HEART = -1344, -1352, -1362
local GOLD = Color3.fromRGB(255, 200, 90)
local PALE = Color3.fromRGB(255, 244, 210)
local AMBER = Color3.fromRGB(255, 150, 60)
local CYAN = Color3.fromRGB(120, 255, 230)
local CORE_COLORS = { GOLD, PALE, AMBER, Color3.fromRGB(255, 220, 140) }

T:FillBlock(CFrame.new(0, -1350, -800), Vector3.new(460, 220, 540), Enum.Material.Asphalt)
-- Asphalt, Cobblestone, Snow and Mud only appear down here, so their global
-- colours are ours: dark bronze rock, gilded floors, pale-gold sand, molten floor.
T:SetMaterialColor(Enum.Material.Asphalt, Color3.fromRGB(62, 46, 28))
T:SetMaterialColor(Enum.Material.Cobblestone, Color3.fromRGB(150, 116, 58))
T:SetMaterialColor(Enum.Material.Snow, Color3.fromRGB(226, 204, 150))
T:SetMaterialColor(Enum.Material.Mud, Color3.fromRGB(96, 56, 22))

local chambers = {
	Arrival = { Zone = "Vestibule", C = Vector2.new(0, -612), F = -1340, rx = 10, rz = 8, Points = 0 },
	Vestibule = { Zone = "Vestibule", C = Vector2.new(0, -680), F = F_VEST, rx = 44, rz = 30, Points = 24, Tall = true },
	VestibuleWest = { Zone = "Vestibule", C = Vector2.new(-64, -700), F = -1342, rx = 16, rz = 14, Points = 8 },
	Galleries = { Zone = "Galleries", C = Vector2.new(0, -812), F = F_GAL, rx = 52, rz = 38, Points = 28, Tall = true },
	GalleriesEast = { Zone = "Galleries", C = Vector2.new(80, -830), F = -1350, rx = 18, rz = 15, Points = 10 },
	Treasury = { Zone = "Treasury", C = Vector2.new(150, -836), F = -1351, rx = 10, rz = 9, Points = 6 },
	Heartfield = { Zone = "Heartfield", C = Vector2.new(0, -950), F = F_HEART, rx = 50, rz = 38, Points = 28, Tall = true },
	SealHall = { Zone = "Final", C = Vector2.new(0, -1000), F = -1364, rx = 20, rz = 8, Points = 0, Tall = true },
	Origin = { Zone = "Origin", C = Vector2.new(0, -1044), F = -1364, rx = 14, rz = 10, Points = 0, Tall = true },
}

local tunnels = {
	ArrivalToVestibule = { Vector3.new(0, -1333, -618), Vector3.new(0, -1335, -636), Vector3.new(0, -1337, -652) },
	VestibuleWest = { Vector3.new(-30, -1337, -694), Vector3.new(-46, -1335, -700) },
	GildedSeal = { Vector3.new(0, -1337, -712), Vector3.new(0, -1339, -726), Vector3.new(0, -1342, -740),
		Vector3.new(0, -1344, -754), Vector3.new(0, -1346, -772) },
	GalleriesEast = { Vector3.new(44, -1345, -822), Vector3.new(62, -1343, -828) },
	StarGate = { Vector3.new(0, -1345, -852), Vector3.new(0, -1348, -866), Vector3.new(0, -1351, -880),
		Vector3.new(0, -1354, -894), Vector3.new(0, -1356, -912) },
	Seal = { Vector3.new(0, -1356, -984), Vector3.new(0, -1357, -992) },
}
local crawl = { Vector3.new(100, -1344, -832), Vector3.new(118, -1344, -834), Vector3.new(136, -1344, -835) }

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
T:FillBlock(CFrame.new(0, -1364 + 18, SEAL_Z + 8), Vector3.new(54, 36, 16), AIR)
carveTunnel({ Vector3.new(0, -1357, SEAL_Z - 2), Vector3.new(0, -1357, SEAL_Z - 14) }, 8)

-- Gilded floors in the vestibule, pale radiant sand in the galleries, a
-- dark molten floor around the core.
T:ReplaceMaterial(Region3.new(Vector3.new(-90, F_VEST - 8, -720), Vector3.new(90, F_VEST + 2, -600)):ExpandToGrid(4), 4,
	Enum.Material.Asphalt, Enum.Material.Cobblestone)
T:ReplaceMaterial(Region3.new(Vector3.new(-120, F_GAL - 8, -880), Vector3.new(120, F_GAL + 2, -760)):ExpandToGrid(4), 4,
	Enum.Material.Asphalt, Enum.Material.Snow)
T:ReplaceMaterial(Region3.new(Vector3.new(-90, F_HEART - 8, -1060), Vector3.new(90, F_HEART + 2, -900)):ExpandToGrid(4), 4,
	Enum.Material.Asphalt, Enum.Material.Mud)

local mine = folder("Mine6", minesFolder)
local props = folder("Props", mine)
local spawnsFolder = folder("OreSpawns", mine)
local gatesFolder = folder("Gates", mine)
local volumes = folder("ZoneVolumes", mine)
local hazards = folder("Hazards", mine)
local creatureSpawns = folder("CreatureSpawns", mine)

waitForTerrain(Vector3.new(chambers.Origin.C.X, chambers.Origin.F + 6, chambers.Origin.C.Y))

local keepClear = { Vector3.new(0, -1340, -612), Vector3.new(0, -1364, SEAL_Z + 6), Vector3.new(0, F_HEART, -950) }
for _, list in { tunnels, { crawl } } do
	for _, path in list do
		table.insert(keepClear, path[1])
		table.insert(keepClear, path[#path])
	end
end
local zoneFolders = makeOreSpawns(chambers, spawnsFolder, keepClear)

zoneVolume(volumes, "Vestibule", CFrame.new(0, -1345, -665), Vector3.new(300, 110, 150))
zoneVolume(volumes, "Galleries", CFrame.new(0, -1353, -810), Vector3.new(300, 110, 140))
zoneVolume(volumes, "Heartfield", CFrame.new(0, -1360, -950), Vector3.new(260, 110, 140))
zoneVolume(volumes, "Final", CFrame.new(0, -1358, -1008), Vector3.new(70, 60, 24), 1)
zoneVolume(volumes, "Origin", CFrame.new(0, -1358, -1044), Vector3.new(50, 50, 44), 2)
zoneVolume(volumes, "Treasury", CFrame.new(151, -1351, -836), Vector3.new(32, 40, 30), 2)

-- The light itself burns: the galleries need a Radiant Suit, the heartfield a Core Suit.
hazardVolume(hazards, "Radiance", 1, 22, CFrame.new(0, -1348, -812), Vector3.new(300, 80, 128))
hazardVolume(hazards, "Radiance", 2, 34, CFrame.new(0, -1358, -948), Vector3.new(260, 80, 128))

----------------------------------------------------------------------------
-- Gilded formations
----------------------------------------------------------------------------

local formations = folder("Formations", props)

-- A thin beam of light from floor to ceiling.
local function lightPillar(f, color)
	local top = ceilingAbove(f + Vector3.new(0, 2, 0), 60)
	local height = if top then (top.Y - f.Y) else 30
	local beam = P({ Name = "LightPillar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, 1.2, 1.2),
		CFrame = CFrame.new(f + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Neon, Color = color, Transparency = 0.35, CanCollide = false, CanQuery = false, CastShadow = false,
		Parent = formations })
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 26
	light.Brightness = 1.1
	light.Parent = beam
end

-- Golden obelisk crystals growing out of the floor.
local function goldSpire(f, height)
	local cf = CFrame.new(f) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), rng:NextNumber(0, 6), rng:NextNumber(-0.15, 0.15))
	local w = height * 0.2 + 1
	P({ Name = "Spire", Size = Vector3.new(w, height, w), CFrame = cf * CFrame.new(0, height / 2 - 0.5, 0),
		Material = Enum.Material.Foil, Color = Color3.fromRGB(196, 150, 60), Parent = formations })
	P({ Name = "Tip", Size = Vector3.new(w * 0.7, w * 0.7, w * 0.7), CFrame = cf * CFrame.new(0, height, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		Material = Enum.Material.Neon, Color = PALE, CanCollide = false, CastShadow = false, Parent = formations })
end

-- Rock islands drifting overhead in the tall chambers (decorative, out of reach).
local function floatingIsland(at, size)
	local rock = P({ Name = "Island", Size = Vector3.new(size, size * 0.6, size * 0.9), CFrame = CFrame.new(at)
		* CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, 6), rng:NextNumber(-0.2, 0.2)),
		Material = Enum.Material.Slate, Color = Color3.fromRGB(70, 52, 30), CanCollide = false, Parent = formations })
	P({ Name = "Underside", Shape = Enum.PartType.Ball, Size = Vector3.new(size * 0.8, size * 0.8, size * 0.8),
		CFrame = rock.CFrame * CFrame.new(0, -size * 0.3, 0), Material = Enum.Material.Slate, Color = Color3.fromRGB(56, 40, 24),
		CanCollide = false, Parent = formations })
	P({ Name = "Vein", Size = Vector3.new(size * 0.9, 0.3, 0.6), CFrame = rock.CFrame * CFrame.new(0, size * 0.31, 0),
		Material = Enum.Material.Neon, Color = GOLD, CanCollide = false, CastShadow = false, Parent = formations })
end

for _, ch in chambers do
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
		local color = CORE_COLORS[rng:NextInteger(1, #CORE_COLORS)]
		if hit.Normal.Y > 0.6 then
			local roll = rng:NextNumber()
			if roll < 0.4 then
				goldSpire(hit.Position, rng:NextNumber(5, if ch.Tall then 16 else 9))
			elseif roll < 0.55 and ch.Tall then
				lightPillar(hit.Position, color)
			else
				crystalCluster(formations, hit.Position, hit.Normal, rng:NextNumber(1, 2), color, placed % 2 ~= 0)
			end
		else
			crystalCluster(formations, hit.Position, hit.Normal, rng:NextNumber(0.8, 1.6), color, placed % 3 ~= 0)
		end
		placed += 1
	end
	if ch.Tall then
		for _ = 1, 3 do
			floatingIsland(origin + Vector3.new(rng:NextNumber(-ch.rx, ch.rx) * 0.55, rng:NextNumber(10, 16),
				rng:NextNumber(-ch.rz, ch.rz) * 0.55), rng:NextNumber(4, 7))
		end
	end
end

-- The World Core: a huge burning sphere hanging over the heartfield, ringed by light.
do
	local center = Vector3.new(0, F_HEART + 20, -950)
	local core = P({ Name = "WorldCore", Shape = Enum.PartType.Ball, Size = Vector3.new(14, 14, 14), CFrame = CFrame.new(center),
		Material = Enum.Material.Neon, Color = Color3.fromRGB(230, 170, 80), Transparency = 0.15, CanCollide = false, CanQuery = false,
		CastShadow = false, Parent = props })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 200, 120)
	light.Range = 60
	light.Brightness = 1.4
	light.Parent = core
	for i, tilt in { 0.35, -0.5, 1.2 } do
		P({ Name = "CoreRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 24 + i * 4, 24 + i * 4),
			CFrame = CFrame.new(center) * CFrame.Angles(tilt, i * 1.1, math.rad(90)), Material = Enum.Material.Neon,
			Color = if i == 2 then AMBER else PALE, Transparency = 0.55, CanCollide = false, CanQuery = false, CastShadow = false, Parent = props })
	end
	local motes = Instance.new("ParticleEmitter")
	motes.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	motes.Color = ColorSequence.new(GOLD)
	motes.LightEmission = 1
	motes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
	motes.Lifetime = NumberRange.new(2, 4)
	motes.Rate = 20
	motes.Speed = NumberRange.new(3, 7)
	motes.SpreadAngle = Vector2.new(180, 180)
	motes.Parent = core
end

----------------------------------------------------------------------------
-- Gates
----------------------------------------------------------------------------

-- The Gilded Seal: a lattice of golden bars across the tunnel.
do
	local at = tunnels.GildedSeal[3]
	local dir = gateDir(tunnels.GildedSeal, 3)
	local model = folder("GildedSeal", gatesFolder, "Model")
	local look = CFrame.lookAt(at, at + dir)
	local blocker = P({ Name = "Blocker", Size = Vector3.new(20, 20, 3), CFrame = look, Transparency = 1, Parent = model })
	model.PrimaryPart = blocker
	for i = -3, 3 do
		P({ Name = "Bar", Size = Vector3.new(0.9, 18, 0.9), CFrame = look * CFrame.new(i * 2.6, 0, 0),
			Material = Enum.Material.Foil, Color = Color3.fromRGB(214, 168, 70), Parent = model })
		P({ Name = "Bar", Size = Vector3.new(18, 0.9, 0.9), CFrame = look * CFrame.new(0, i * 2.6, 0.4),
			Material = Enum.Material.Foil, Color = Color3.fromRGB(190, 146, 56), Parent = model })
	end
	P({ Name = "Sigil", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 6, 6), CFrame = look * CFrame.new(0, 0, -0.8)
		* CFrame.Angles(0, math.rad(90), 0), Material = Enum.Material.Neon, Color = PALE, CanCollide = false, Parent = model })
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Range = 24
	light.Brightness = 1.4
	light.Parent = blocker
	local floor = floorBelow(at - dir * 8, 20)
	if floor then
		sign(model, CFrame.lookAt(floor + Vector3.new(4.5, 4, 0), floor + Vector3.new(4.5, 4, 0) - dir), Vector3.new(4.6, 2.2, 0.2),
			"GILDED SEAL\nNeeds a Core Pickaxe", Color3.fromRGB(255, 220, 140))
		P({ Name = "SignPost", Size = Vector3.new(0.4, 4, 0.4), CFrame = CFrame.new(floor + Vector3.new(4.5, 2, 0)),
			Material = Enum.Material.Wood, Color = WOOD, Parent = model })
	end
	model:SetAttribute("GateId", "GildedSeal")
	CollectionService:AddTag(model, "Gate")
end

-- The Star Gate: shards of light orbiting a white disk.
do
	local at = tunnels.StarGate[3]
	local dir = gateDir(tunnels.StarGate, 3)
	local model = folder("StarGate", gatesFolder, "Model")
	local look = CFrame.lookAt(at, at + dir)
	local blocker = P({ Name = "Blocker", Size = Vector3.new(20, 20, 3), CFrame = look, Transparency = 1, Parent = model })
	model.PrimaryPart = blocker
	P({ Name = "Disk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 15, 15), CFrame = look * CFrame.Angles(0, math.rad(90), 0),
		Material = Enum.Material.Neon, Color = PALE, Transparency = 0.15, Parent = model })
	for i = 1, 10 do
		local a = i / 10 * math.pi * 2
		P({ Name = "Shard", Size = Vector3.new(1.2, 3.4, 1.2), CFrame = look * CFrame.new(math.cos(a) * 8.5, math.sin(a) * 8.5, -1)
			* CFrame.Angles(0, 0, a), Material = Enum.Material.Neon, Color = if i % 2 == 0 then GOLD else CYAN, Parent = model })
	end
	local light = Instance.new("PointLight")
	light.Color = PALE
	light.Range = 26
	light.Brightness = 1.6
	light.Parent = blocker
	model:SetAttribute("GateId", "StarGate")
	CollectionService:AddTag(model, "Gate")
end

buildGate(gatesFolder, { Id = "TreasuryWall", At = crawl[2] + Vector3.new(4, 0, 0), Dir = gateDir(crawl, 2), Style = "Hidden" })

----------------------------------------------------------------------------
-- Creatures
----------------------------------------------------------------------------

local function creatureSpawn(zone, kind, x, z, F)
	local zf = creatureSpawns:FindFirstChild(zone) or folder(zone, creatureSpawns)
	local f = floorBelow(Vector3.new(x, F + 8, z), 20) or Vector3.new(x, F, z)
	local p = invisible(kind, CFrame.new(f + Vector3.new(0, 1, 0)), Vector3.new(1, 1, 1), zf)
	p:SetAttribute("Kind", kind)
end
creatureSpawn("Galleries", "Stalker", -30, -806, F_GAL)
creatureSpawn("Galleries", "Sentinel", 32, -816, F_GAL)
creatureSpawn("Galleries", "Sentinel", -6, -840, F_GAL)
creatureSpawn("Heartfield", "Sentinel", -30, -942, F_HEART)
creatureSpawn("Heartfield", "Sentinel", 28, -960, F_HEART)
creatureSpawn("Heartfield", "Sentinel", 0, -926, F_HEART)
creatureSpawn("Heartfield", "Stalker", -36, -968, F_HEART)
creatureSpawn("Heartfield", "Sentinel", 36, -934, F_HEART)

----------------------------------------------------------------------------
-- The Origin Seal, the Origin, artifacts, arrival and lifts
----------------------------------------------------------------------------

sealedWall(mine, {
	MineId = "Mine6", Title = "The Origin Seal", X = 0, Z = SEAL_Z, ProbeY = -1354,
	StoneA = Color3.fromRGB(120, 92, 46), StoneB = Color3.fromRGB(168, 132, 66), FrameColor = Color3.fromRGB(80, 60, 30),
	RuneColor = GOLD, CrackColor = PALE,
	FireColor = Color3.fromRGB(255, 210, 120), FireColor2 = AMBER,
})

do
	-- The Origin: the first stone of the world, a cyan crystal hanging in a gold dome.
	local f = floorBelow(Vector3.new(0, -1354, -1050), 20) or Vector3.new(0, -1364, -1050)
	local stone = P({ Name = "FirstStone", Size = Vector3.new(4, 8, 4), CFrame = CFrame.new(f + Vector3.new(0, 10, 0)) * CFrame.Angles(0, math.rad(45), 0),
		Material = Enum.Material.Neon, Color = CYAN, CanCollide = false, CastShadow = false, Parent = props })
	local light = Instance.new("PointLight")
	light.Color = CYAN
	light.Range = 40
	light.Brightness = 2
	light.Parent = stone
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		crystalCluster(props, f + Vector3.new(math.cos(a) * 10, 0, math.sin(a) * 8), Vector3.yAxis, 1.5, if i % 2 == 0 then GOLD else PALE, true)
	end
	artifactPedestal(props, "OriginShard", f + Vector3.new(0, 0, 6))
	local t = floorBelow(Vector3.new(154, -1346, -838), 20)
	if t then
		artifactPedestal(props, "SunCrown", t)
	end
end

do
	local f = floorBelow(Vector3.new(0, -1332, -608), 30) or Vector3.new(0, -1340, -608)
	local arrival = invisible("Arrival", CFrame.lookAt(f + Vector3.new(0, 3.5, 0), f + Vector3.new(0, 3.5, -10)),
		Vector3.new(1, 1, 1), mine)
	arrival:SetAttribute("MineId", "Mine6")
	local lf = floorBelow(Vector3.new(-6, -1332, -612), 30)
	if lf then
		local cage = liftCage(mine, "Lift_Worldheart", lf, Vector3.new(1, 0, 0), "Ride to Camp", "Mine Lift")
		cage:SetAttribute("LiftId", "Worldheart")
	end
	local gf = floorBelow(Vector3.new(-30, F_GAL + 8, -786), 20)
	if gf then
		local cage = liftCage(mine, "Lift_RadiantGalleries", gf, Vector3.new(1, 0, -0.3), "Ride to Camp", "Mine Lift")
		cage:SetAttribute("LiftId", "RadiantGalleries")
	end
end

local counts = {}
for zone, zf in zoneFolders do
	table.insert(counts, zone .. "=" .. #zf:GetChildren())
end
table.insert(buildReport, "Mine6 ore points: " .. table.concat(counts, " ") .. ", formations: " .. #formations:GetChildren())
end
