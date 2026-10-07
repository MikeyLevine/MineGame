-- Mine 2: Crystal Caverns. Arrival -> Glimmering Grotto -> (quartz-choked passage,
-- Reinforced Pickaxe) -> Sunken Lake -> (crystallized seal, Crystal Pickaxe) ->
-- Amethyst Geode -> The Crystal Seal. Two hidden chambers sit behind cracked
-- walls at the ends of dead-end tunnels.
do
-- Solid rock for the cavern system to be carved from.
T:FillBlock(CFrame.new(0, -265, -790), Vector3.new(380, 180, 440), Enum.Material.Slate)

local chambers = {
	Arrival = { Zone = "Grotto", C = Vector2.new(0, -612), F = -258, rx = 10, rz = 8, Points = 0 },
	Grotto = { Zone = "Grotto", C = Vector2.new(0, -680), F = -262, rx = 40, rz = 30, Points = 24, Tall = true },
	GrottoWest = { Zone = "Grotto", C = Vector2.new(-60, -720), F = -266, rx = 18, rz = 15, Points = 12 },
	GrottoEast = { Zone = "Grotto", C = Vector2.new(58, -728), F = -258, rx = 18, rz = 16, Points = 12, Tall = true },
	Pocket = { Zone = "HiddenPocket", C = Vector2.new(-122, -728), F = -266, rx = 10, rz = 9, Points = 7 },
	Lake = { Zone = "Lake", C = Vector2.new(0, -805), F = -272, rx = 50, rz = 36, Points = 30, Tall = true },
	LakeWest = { Zone = "Lake", C = Vector2.new(-78, -822), F = -270, rx = 18, rz = 15, Points = 12 },
	LakeEast = { Zone = "Lake", C = Vector2.new(76, -792), F = -268, rx = 18, rz = 16, Points = 12, Tall = true },
	Vault = { Zone = "HiddenVault", C = Vector2.new(138, -800), F = -268, rx = 11, rz = 10, Points = 7 },
	Geode = { Zone = "Geode", C = Vector2.new(0, -922), F = -280, rx = 42, rz = 30, Points = 28, Tall = true },
	GeodeEast = { Zone = "Geode", C = Vector2.new(62, -948), F = -284, rx = 16, rz = 13, Points = 10 },
	SealHall = { Zone = "Final", C = Vector2.new(0, -968), F = -282, rx = 20, rz = 8, Points = 0, Tall = true },
	-- The Lightless Rift: no crystals, no light. Needs the Carbide Lamp.
	Rift = { Zone = "Rift", C = Vector2.new(-140, -850), F = -276, rx = 18, rz = 20, Points = 12, Tall = true, NoLights = true },
	Rift2 = { Zone = "Rift", C = Vector2.new(-150, -884), F = -280, rx = 14, rz = 14, Points = 8, NoLights = true },
}

local tunnels = {
	ArrivalToGrotto = { Vector3.new(0, -251, -618), Vector3.new(0, -253, -636), Vector3.new(0, -255, -652) },
	GrottoWest = { Vector3.new(-32, -255, -696), Vector3.new(-48, -259, -712) },
	GrottoEast = { Vector3.new(32, -255, -702), Vector3.new(46, -251, -722) },
	LakeGate = { Vector3.new(0, -255, -708), Vector3.new(0, -257, -726), Vector3.new(0, -261, -742),
		Vector3.new(0, -264, -758), Vector3.new(0, -265, -772) },
	LakeWest = { Vector3.new(-40, -265, -812), Vector3.new(-62, -263, -820) },
	LakeEast = { Vector3.new(40, -265, -798), Vector3.new(60, -261, -792) },
	GeodeGate = { Vector3.new(0, -265, -838), Vector3.new(0, -268, -856), Vector3.new(0, -271, -870),
		Vector3.new(0, -273, -884), Vector3.new(0, -273, -894) },
	GeodeEast = { Vector3.new(32, -273, -938), Vector3.new(50, -277, -946) },
	Seal = { Vector3.new(0, -273, -950), Vector3.new(0, -275, -962) },
	Rift = { Vector3.new(-98, -263, -828), Vector3.new(-112, -266, -836), Vector3.new(-124, -269, -842) },
}
-- Narrow dead-end crawls that lead to the hidden chambers.
local crawls = {
	Pocket = { Vector3.new(-70, -260, -722), Vector3.new(-90, -260, -726), Vector3.new(-106, -260, -728) },
	Vault = { Vector3.new(90, -262, -794), Vector3.new(106, -262, -797), Vector3.new(120, -262, -799) },
}

local function gateDir(path, i)
	return (path[i + 1] - path[i - 1]).Unit
end
local GATES = {
	{ Id = "LakeGate", At = tunnels.LakeGate[3], Dir = gateDir(tunnels.LakeGate, 3), Style = "Crystal",
		Text = "QUARTZ-CHOKED\nNeeds a Reinforced Pickaxe" },
	{ Id = "GeodeGate", At = tunnels.GeodeGate[3], Dir = gateDir(tunnels.GeodeGate, 3), Style = "Crystal",
		Text = "CRYSTALLIZED SEAL\nNeeds a Crystal Pickaxe" },
	{ Id = "HiddenPocket", At = crawls.Pocket[2] + Vector3.new(-4, 0, -0.8), Dir = gateDir(crawls.Pocket, 2), Style = "Hidden" },
	{ Id = "HiddenVault", At = crawls.Vault[2] + Vector3.new(4, 0, -0.6), Dir = gateDir(crawls.Vault, 2), Style = "Hidden" },
}

local SEAL_Z = -986

for _, ch in chambers do
	carveChamber(ch)
end
for _, path in tunnels do
	carveTunnel(path)
end
for _, path in crawls do
	carveTunnel(path, 5)
end
-- Passage behind the seal to the portal down to the Lava Depths.
carveTunnel({ Vector3.new(0, -275, SEAL_Z - 2), Vector3.new(0, -275, SEAL_Z - 12) }, 8)
T:FillBall(Vector3.new(0, -272, SEAL_Z - 15), 8.5, AIR)
-- Open face in front of the Crystal Seal.
T:FillBlock(CFrame.new(0, chambers.SealHall.F + 18, SEAL_Z + 8), Vector3.new(54, 36, 16), AIR)

-- Water: a small pool in the grotto and the big lake, flush with the floor.
T:FillBlock(CFrame.new(24, -266.5, -686), Vector3.new(22, 9, 26), Enum.Material.Water)
T:FillBlock(CFrame.new(0, -276.5, -806), Vector3.new(60, 9, 42), Enum.Material.Water)
-- Rock islands in the lake.
local islands = { Vector3.new(-14, -276, -800), Vector3.new(16, -276, -814), Vector3.new(4, -277, -792) }
for _, c in islands do
	T:FillBall(c, 5.5, Enum.Material.Slate)
end

waitForTerrain(Vector3.new(chambers.SealHall.C.X, chambers.SealHall.F + 6, chambers.SealHall.C.Y))

local mine = folder("Mine2", minesFolder)
local props = folder("Props", mine)
local spawnsFolder = folder("OreSpawns", mine)
local gatesFolder = folder("Gates", mine)
local volumes = folder("ZoneVolumes", mine)

local keepClear = { Vector3.new(0, -258, -612), Vector3.new(24, -262, -686), Vector3.new(0, -272, -806),
	Vector3.new(-20, -272, -806), Vector3.new(20, -272, -806), Vector3.new(0, -282, SEAL_Z + 6) }
for _, list in { tunnels, crawls } do
	for _, path in list do
		table.insert(keepClear, path[1])
		table.insert(keepClear, path[#path])
	end
end
local zoneFolders = makeOreSpawns(chambers, spawnsFolder, keepClear)

zoneVolume(volumes, "Grotto", CFrame.new(0, -258, -665), Vector3.new(240, 120, 154))
zoneVolume(volumes, "Lake", CFrame.new(0, -266, -804), Vector3.new(280, 120, 124))
zoneVolume(volumes, "Geode", CFrame.new(0, -272, -916), Vector3.new(220, 120, 100))
zoneVolume(volumes, "Final", CFrame.new(0, -270, -978), Vector3.new(70, 60, 40), 1)
zoneVolume(volumes, "HiddenPocket", CFrame.new(-123, -262, -728), Vector3.new(30, 40, 30), 2)
zoneVolume(volumes, "Rift", CFrame.new(-146, -276, -866), Vector3.new(60, 60, 84), 1)
zoneVolume(volumes, "HiddenVault", CFrame.new(139, -262, -800), Vector3.new(30, 40, 30), 2)

for _, g in GATES do
	buildGate(gatesFolder, g)
end

-- Crystal growth. Bigger in the lake and enormous in the geode.
local crystals = folder("Crystals", props)
local SCALE = { Geode = { 1.6, 3 }, GeodeEast = { 1.1, 2 }, Lake = { 1.1, 2.2 }, SealHall = { 1, 1.6 },
	Pocket = { 0.8, 1.4 }, Vault = { 0.8, 1.4 } }
local clearOfDoors = {}
for _, p in keepClear do
	table.insert(clearOfDoors, p)
end
table.insert(clearOfDoors, Vector3.new(-2, 0, -612)) -- arrival alcove + lift
for name, ch in chambers do
	if ch.NoLights then
		continue
	end
	local range = SCALE[name] or { 0.9, 1.6 }
	local count = math.floor((ch.rx + ch.rz) / (if name == "Geode" then 3.2 else 3.5))
	local origin = Vector3.new(ch.C.X, ch.F + 8, ch.C.Y)
	local placed = 0
	for _ = 1, count * 8 do
		if placed >= count then
			break
		end
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.6, 1), rng:NextNumber(-1, 1))
		if dir.Magnitude < 0.1 then
			continue
		end
		local hit = ray(origin, dir.Unit * 70)
		if hit and clearOf(hit.Position, clearOfDoors, if name == "Geode" then 11 else 9) then
			local ceiling = hit.Normal.Y < -0.5
			local scale = if ceiling then range[1] * 0.8 else rng:NextNumber(range[1], range[2])
			-- Only some clusters cast light; dozens of overlapping lights wash everything out.
			crystalCluster(crystals, hit.Position, hit.Normal, scale, nil, placed % 3 ~= 0)
			placed += 1
		end
	end
end
-- Crystals on the lake islands.
for _, c in islands do
	local top = floorBelow(c + Vector3.new(0, 10, 0), 20)
	if top then
		crystalCluster(crystals, top, Vector3.yAxis, rng:NextNumber(1.4, 2.2), CRYSTAL_COLORS[2])
	end
end

-- Story bits ---------------------------------------------------------------
local story = folder("Story", props)
local function note(pos, facing, text)
	local f = floorBelow(pos + Vector3.new(0, 6, 0), 20)
	if not f then
		return
	end
	P({ Name = "NotePost", Size = Vector3.new(0.3, 3, 0.3), CFrame = CFrame.new(f + Vector3.new(0, 1.5, 0)),
		Material = Enum.Material.Wood, Color = WOOD, Parent = story })
	sign(story, CFrame.lookAt(f + Vector3.new(0, 3.2, 0), f + Vector3.new(0, 3.2, 0) + facing), Vector3.new(4.2, 2.4, 0.15), text,
		Color3.fromRGB(235, 225, 200))
end
-- An old expedition camp in the west lake cave.
do
	local f = floorBelow(Vector3.new(-80, -262, -824), 20)
	if f then
		local cf = CFrame.new(f) * CFrame.Angles(0, 0.6, 0)
		for _, side in { -1, 1 } do
			P({ Class = "WedgePart", Name = "Canvas", Size = Vector3.new(7, 4.2, 2.8),
				CFrame = cf * CFrame.new(0, 2.1, side * 1.4) * CFrame.Angles(0, if side == 1 then math.pi else 0, 0),
				Material = Enum.Material.Fabric, Color = Color3.fromRGB(70, 92, 110), Parent = story })
		end
		crate(story, cf * CFrame.new(5, 1.2, 1))
		barrel(story, (cf * CFrame.new(6, 0, -2.5)).Position)
		lantern(story, (cf * CFrame.new(4.5, 3.3, 1)).Position, 0.2)
		note(f + cf.LookVector * -5, cf.LookVector, "Day 12.\nThe crystals hum at night.\nNobody else hears it.")
	end
end
note(Vector3.new(-62, -262, -716), Vector3.new(-1, 0, 0), "This tunnel goes nowhere.\n...or does it?")
note(Vector3.new(-126, -262, -726), Vector3.new(1, 0, 0), "Found it.\nTold no one.")
note(Vector3.new(-4, -262, -760), Vector3.new(0, 0, 1), "The lake glows brighter\nthe deeper you go.")
note(Vector3.new(-96, -262, -826), Vector3.new(1, 0, 0), "The light dies past here.\nBring something brighter.")

-- A pickaxe left stuck in a crystal inside the hidden pocket.
do
	local f = floorBelow(Vector3.new(-120, -262, -732), 20)
	if f then
		crystalCluster(story, f, Vector3.yAxis, 1.2, CRYSTAL_COLORS[3])
		P({ Name = "LostHandle", Size = Vector3.new(0.3, 3.6, 0.3), CFrame = CFrame.new(f + Vector3.new(0.8, 2.6, 0)) * CFrame.Angles(0, 0, 0.6),
			Material = Enum.Material.Wood, Color = WOOD, CanCollide = false, Parent = story })
	end
end

-- The Crystal Seal, with the portal to the Lava Depths behind it.
sealedWall(mine, {
	MineId = "Mine2", Title = "The Crystal Seal", X = 0, Z = SEAL_Z, ProbeY = -270,
	StoneA = Color3.fromRGB(56, 62, 88), StoneB = Color3.fromRGB(80, 88, 122), FrameColor = Color3.fromRGB(48, 52, 76),
	RuneColor = Color3.fromRGB(110, 220, 255), CrackColor = Color3.fromRGB(190, 240, 255),
	FireColor = Color3.fromRGB(120, 220, 255), FireColor2 = Color3.fromRGB(60, 120, 255),
})
buildPortal(mine, { X = 0, Z = SEAL_Z - 14, ProbeY = -270, FromMine = "Mine2", ToMine = "Mine3" })

-- Arrival point + lifts.
do
	local f = floorBelow(Vector3.new(0, -250, -608), 30) or Vector3.new(0, -258, -608)
	local arrival = invisible("Arrival", CFrame.lookAt(f + Vector3.new(0, 3.5, 0), f + Vector3.new(0, 3.5, -10)),
		Vector3.new(1, 1, 1), mine)
	arrival:SetAttribute("MineId", "Mine2")
	local lf = floorBelow(Vector3.new(-6, -250, -612), 30)
	if lf then
		local cage = liftCage(mine, "Lift_CrystalCaverns", lf, Vector3.new(1, 0, 0), "Ride to Camp", "Mine Lift")
		cage:SetAttribute("LiftId", "CrystalCaverns")
	end
	local lake = floorBelow(Vector3.new(-34, -262, -780), 20)
	if lake then
		local cage = liftCage(mine, "Lift_SunkenLake", lake, Vector3.new(1, 0, -0.4), "Ride to Camp", "Mine Lift")
		cage:SetAttribute("LiftId", "SunkenLake")
	end
end

-- Artifact: the Crystal Heart, in the Prism Vault.
do
	local f = floorBelow(Vector3.new(144, -262, -804), 20)
	if f then
		artifactPedestal(props, "CrystalHeart", f)
	end
end

local counts = {}
for zone, zf in zoneFolders do
	table.insert(counts, zone .. "=" .. #zf:GetChildren())
end
table.insert(buildReport, "Mine2 ore points: " .. table.concat(counts, " ") .. ", crystals: " .. #crystals:GetChildren())
end
