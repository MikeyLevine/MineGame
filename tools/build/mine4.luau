-- Mine 4: Ancient Depths. Arrival -> Forgotten Halls (ruins) -> (Temple Doors,
-- Ancient Pickaxe) -> Sunken Temple (stepped pyramid) with the dark Catacombs
-- maze to the east and the Sun Door to the south (opened by three Sun Glyphs:
-- pyramid top, catacombs, hidden library) -> Sun Vault. The Ancient Seal is
-- south-west of the temple. The Lost Library hides behind a cracked wall off
-- the west hall.
do
local F_HALL, F_TEMPLE = -794, -804
-- Muted sandstone: pale stone under bright lamps washes out to white.
local STONE = Color3.fromRGB(150, 136, 106)
local STONE_DARK = Color3.fromRGB(112, 100, 78)
local GOLD = Color3.fromRGB(230, 180, 80)

T:FillBlock(CFrame.new(0, -800, -780), Vector3.new(440, 200, 460), Enum.Material.Limestone)
-- Only Mine 4 uses these materials, so their (global) colour is tuned for it.
T:SetMaterialColor(Enum.Material.Limestone, Color3.fromRGB(122, 110, 88))
T:SetMaterialColor(Enum.Material.Pavement, Color3.fromRGB(108, 100, 86))

local chambers = {
	Arrival = { Zone = "Halls", C = Vector2.new(0, -612), F = -790, rx = 10, rz = 8, Points = 0 },
	Halls = { Zone = "Halls", C = Vector2.new(0, -680), F = F_HALL, rx = 40, rz = 28, Points = 22, Tall = true },
	HallsWest = { Zone = "Halls", C = Vector2.new(-58, -702), F = -792, rx = 16, rz = 14, Points = 8 },
	Library = { Zone = "Library", C = Vector2.new(-128, -706), F = -793, rx = 12, rz = 10, Points = 6 },
	Temple = { Zone = "Temple", C = Vector2.new(0, -832), F = F_TEMPLE, rx = 56, rz = 44, Points = 0, Tall = true },
	CatacombA = { Zone = "Catacombs", C = Vector2.new(76, -898), F = F_TEMPLE, rx = 8, rz = 7, Points = 5 },
	CatacombB = { Zone = "Catacombs", C = Vector2.new(124, -812), F = F_TEMPLE, rx = 8, rz = 7, Points = 5 },
	SunVault = { Zone = "SunVault", C = Vector2.new(18, -924), F = F_TEMPLE, rx = 11, rz = 9, Points = 6 },
	SealHall = { Zone = "Final", C = Vector2.new(-62, -904), F = -806, rx = 20, rz = 8, Points = 0, Tall = true },
}

local tunnels = {
	ArrivalToHalls = { Vector3.new(0, -783, -618), Vector3.new(0, -785, -636), Vector3.new(0, -787, -652) },
	HallsWest = { Vector3.new(-30, -787, -694), Vector3.new(-46, -785, -700) },
	TempleDoors = { Vector3.new(0, -787, -708), Vector3.new(0, -789, -722), Vector3.new(0, -792, -736),
		Vector3.new(0, -795, -752), Vector3.new(0, -797, -782) },
	SunDoor = { Vector3.new(8, -797, -878), Vector3.new(12, -797, -892), Vector3.new(16, -797, -906) },
	Seal = { Vector3.new(-38, -797, -868), Vector3.new(-52, -799, -884), Vector3.new(-60, -799, -892) },
}
-- The catacombs: narrow corridors, one dead end.
local catacombs = {
	{ Vector3.new(58, -797, -840), Vector3.new(84, -797, -840), Vector3.new(84, -797, -866), Vector3.new(78, -797, -884) },
	{ Vector3.new(84, -797, -840), Vector3.new(84, -797, -818), Vector3.new(108, -797, -818), Vector3.new(116, -797, -814) },
	{ Vector3.new(84, -797, -866), Vector3.new(106, -797, -866), Vector3.new(110, -797, -880) },
}
local crawl = { Vector3.new(-76, -786, -704), Vector3.new(-96, -786, -705), Vector3.new(-116, -786, -706) }

local function gateDir(path, i)
	return (path[i + 1] - path[i - 1]).Unit
end

local SEAL_Z = -922

for _, ch in chambers do
	carveChamber(ch)
end
-- The temple gets an extra-high vault over the pyramid.
for _, c in { Vector3.new(0, -772, -832), Vector3.new(-26, -778, -832), Vector3.new(26, -778, -832) } do
	T:FillBall(c, if c.X == 0 then 26 else 20, AIR)
end
for _, path in tunnels do
	carveTunnel(path)
end
for _, path in catacombs do
	carveTunnel(path, 6)
end
carveTunnel(crawl, 5)
T:FillBlock(CFrame.new(-62, -806 + 18, SEAL_Z + 8), Vector3.new(54, 36, 16), AIR)
-- Passage behind the seal to the portal down to the Unknown Depths.
carveTunnel({ Vector3.new(-62, -799, SEAL_Z - 2), Vector3.new(-62, -799, SEAL_Z - 12) }, 8)
T:FillBall(Vector3.new(-62, -796, SEAL_Z - 15), 8.5, AIR)
-- Paved floors in the temple and halls.
T:ReplaceMaterial(Region3.new(Vector3.new(-70, F_TEMPLE - 6, -890), Vector3.new(70, F_TEMPLE + 1, -776)):ExpandToGrid(4), 4,
	Enum.Material.Limestone, Enum.Material.Pavement)
T:ReplaceMaterial(Region3.new(Vector3.new(-44, F_HALL - 6, -712), Vector3.new(44, F_HALL + 1, -648)):ExpandToGrid(4), 4,
	Enum.Material.Limestone, Enum.Material.Pavement)

waitForTerrain(Vector3.new(chambers.SealHall.C.X, chambers.SealHall.F + 6, chambers.SealHall.C.Y))

local mine = folder("Mine4", minesFolder)
local props = folder("Props", mine)
local spawnsFolder = folder("OreSpawns", mine)
local gatesFolder = folder("Gates", mine)
local volumes = folder("ZoneVolumes", mine)

-- Keep ore away from doorways, the pyramid and the paths.
local keepClear = { Vector3.new(0, -790, -612), Vector3.new(-62, -806, SEAL_Z + 6) }
for _, list in { tunnels, catacombs, { crawl } } do
	for _, path in list do
		table.insert(keepClear, path[1])
		table.insert(keepClear, path[#path])
	end
end
for x = -20, 20, 8 do
	for z = -852, -800, 8 do
		table.insert(keepClear, Vector3.new(x, 0, z))
	end
end
local zoneFolders = makeOreSpawns(chambers, spawnsFolder, keepClear)
-- The temple's centre is the pyramid, so seed its ore from spots around it.
local templeSpots = {
	TempleWest = { Zone = "Temple", C = Vector2.new(-38, -832), F = F_TEMPLE, Points = 7 },
	TempleEast = { Zone = "Temple", C = Vector2.new(38, -832), F = F_TEMPLE, Points = 7 },
	TempleSW = { Zone = "Temple", C = Vector2.new(-22, -866), F = F_TEMPLE, Points = 6 },
	TempleSE = { Zone = "Temple", C = Vector2.new(22, -866), F = F_TEMPLE, Points = 6 },
	TempleNorth = { Zone = "Temple", C = Vector2.new(-28, -800), F = F_TEMPLE, Points = 5 },
}
for zone, zf in makeOreSpawns(templeSpots, spawnsFolder, keepClear) do
	zoneFolders[zone] = zf
end

zoneVolume(volumes, "Halls", CFrame.new(0, -790, -664), Vector3.new(300, 110, 140))
zoneVolume(volumes, "Temple", CFrame.new(0, -800, -836), Vector3.new(300, 110, 204))
zoneVolume(volumes, "Catacombs", CFrame.new(104, -800, -856), Vector3.new(72, 40, 124), 1)
zoneVolume(volumes, "SunVault", CFrame.new(18, -800, -924), Vector3.new(36, 40, 36), 2)
zoneVolume(volumes, "Final", CFrame.new(-62, -800, -912), Vector3.new(70, 60, 40), 1)
zoneVolume(volumes, "Library", CFrame.new(-129, -790, -706), Vector3.new(32, 40, 30), 2)

----------------------------------------------------------------------------
-- architecture helpers
----------------------------------------------------------------------------

local ruins = folder("Ruins", props)

local function column(pos, height, broken)
	local f = floorBelow(pos + Vector3.new(0, 12, 0), 30)
	if not f then
		return
	end
	local h = if broken then height * rng:NextNumber(0.3, 0.6) else height
	P({ Name = "ColumnBase", Size = Vector3.new(4.4, 1.2, 4.4), CFrame = CFrame.new(f + Vector3.new(0, 0.6, 0)),
		Material = Enum.Material.Sandstone, Color = STONE_DARK, Parent = ruins })
	P({ Name = "Column", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 3.2, 3.2),
		CFrame = CFrame.new(f + Vector3.new(0, 1.2 + h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Sandstone, Color = STONE, Parent = ruins })
	if broken then
		-- The fallen top half lies next to it.
		local a = rng:NextNumber(0, math.pi * 2)
		local len = height - h
		P({ Name = "FallenColumn", Shape = Enum.PartType.Cylinder, Size = Vector3.new(len, 3.2, 3.2),
			CFrame = CFrame.new(f + Vector3.new(math.cos(a) * (len / 2 + 2), 1.6, math.sin(a) * (len / 2 + 2))) * CFrame.Angles(0, a, 0),
			Material = Enum.Material.Sandstone, Color = STONE, Parent = ruins })
	else
		P({ Name = "Capital", Size = Vector3.new(4.6, 1.4, 4.6), CFrame = CFrame.new(f + Vector3.new(0, 1.2 + h + 0.7, 0)),
			Material = Enum.Material.Sandstone, Color = STONE_DARK, Parent = ruins })
	end
end

local function brazier(pos)
	local f = floorBelow(pos + Vector3.new(0, 10, 0), 30)
	if not f then
		return
	end
	P({ Name = "BrazierStand", Size = Vector3.new(1.6, 4, 1.6), CFrame = CFrame.new(f + Vector3.new(0, 2, 0)),
		Material = Enum.Material.Sandstone, Color = STONE_DARK, Parent = ruins })
	local bowl = P({ Name = "Brazier", Size = Vector3.new(3, 0.9, 3), CFrame = CFrame.new(f + Vector3.new(0, 4.4, 0)),
		Material = Enum.Material.Foil, Color = GOLD, Parent = ruins })
	local fire = Instance.new("Fire")
	fire.Size = 4
	fire.Heat = 7
	fire.Color = Color3.fromRGB(255, 190, 90)
	fire.SecondaryColor = Color3.fromRGB(255, 110, 40)
	fire.Parent = bowl
	local light = Instance.new("PointLight")
	light.Range = 22
	light.Brightness = 0.9
	light.Color = Color3.fromRGB(255, 200, 120)
	light.Shadows = false
	light.Parent = bowl
end

local function statue(pos, facing, scale)
	local f = floorBelow(pos + Vector3.new(0, 10, 0), 30)
	if not f then
		return
	end
	local s = scale or 1
	local cf = CFrame.lookAt(f, f + Vector3.new(facing.X, 0, facing.Z))
	local parts = {
		{ "Plinth", Vector3.new(6, 2, 6), CFrame.new(0, 1, 0) },
		{ "Legs", Vector3.new(4.4, 3, 4), CFrame.new(0, 3.5, -0.6) },
		{ "Body", Vector3.new(4, 5, 2.8), CFrame.new(0, 7.5, 0.6) },
		{ "Head", Vector3.new(2.4, 2.6, 2.4), CFrame.new(0, 11.3, 0.4) },
		{ "Headdress", Vector3.new(3, 1.2, 3), CFrame.new(0, 12.8, 0.4) },
	}
	for _, p in parts do
		P({ Name = "Statue" .. p[1], Size = p[2] * s, CFrame = cf * CFrame.new(p[3].Position * s),
			Material = Enum.Material.Sandstone, Color = if p[1] == "Headdress" then GOLD else STONE_DARK, Parent = ruins })
	end
end

----------------------------------------------------------------------------
-- Forgotten Halls
----------------------------------------------------------------------------

for i, z in { -660, -676, -692, -708 } do
	column(Vector3.new(-20, F_HALL, z), 22, i % 2 == 0)
	column(Vector3.new(20, F_HALL, z), 22, i % 3 == 0)
end
brazier(Vector3.new(-12, F_HALL, -666))
brazier(Vector3.new(12, F_HALL, -666))
brazier(Vector3.new(-12, F_HALL, -700))
brazier(Vector3.new(12, F_HALL, -700))
statue(Vector3.new(-30, F_HALL, -684), Vector3.new(1, 0, 0), 0.9)

----------------------------------------------------------------------------
-- Temple Doors (gate: needs the Ancient Pickaxe)
----------------------------------------------------------------------------

do
	local at = tunnels.TempleDoors[3]
	local dir = gateDir(tunnels.TempleDoors, 3)
	local model = folder("TempleDoors", gatesFolder, "Model")
	local look = CFrame.lookAt(at, at + Vector3.new(dir.X, 0, dir.Z))
	local blocker = P({ Name = "Blocker", Size = Vector3.new(20, 20, 3), CFrame = look, Transparency = 1, Parent = model })
	model.PrimaryPart = blocker
	for _, side in { -1, 1 } do
		P({ Name = "DoorLeaf", Size = Vector3.new(8, 16, 2), CFrame = look * CFrame.new(side * 4.05, -0.5, 0),
			Material = Enum.Material.Sandstone, Color = STONE_DARK, Parent = model })
		P({ Name = "DoorBand", Size = Vector3.new(7, 0.6, 0.3), CFrame = look * CFrame.new(side * 4.05, 4, -1.1),
			Material = Enum.Material.Foil, Color = GOLD, Parent = model })
		P({ Name = "DoorBand", Size = Vector3.new(7, 0.6, 0.3), CFrame = look * CFrame.new(side * 4.05, -4, -1.1),
			Material = Enum.Material.Foil, Color = GOLD, Parent = model })
	end
	P({ Name = "Emblem", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 4, 4),
		CFrame = look * CFrame.new(0, 2, -1.2) * CFrame.Angles(0, math.rad(90), 0), Material = Enum.Material.Foil, Color = GOLD, Parent = model })
	for _, side in { -1, 1 } do
		P({ Name = "DoorFrame", Size = Vector3.new(2.4, 20, 3), CFrame = look * CFrame.new(side * 9.4, 1, 0),
			Material = Enum.Material.Sandstone, Color = STONE, Parent = model })
	end
	local floor = floorBelow(at - dir * 8, 20)
	if floor then
		sign(model, CFrame.lookAt(floor + Vector3.new(4.5, 4, 0), floor + Vector3.new(4.5, 4, 0) - dir), Vector3.new(4.6, 2.2, 0.2),
			"TEMPLE DOORS\nNeeds an Ancient Pickaxe", Color3.fromRGB(255, 220, 150))
		P({ Name = "SignPost", Size = Vector3.new(0.4, 4, 0.4), CFrame = CFrame.new(floor + Vector3.new(4.5, 2, 0)),
			Material = Enum.Material.Wood, Color = WOOD, Parent = model })
	end
	model:SetAttribute("GateId", "TempleDoors")
	CollectionService:AddTag(model, "Gate")
	statue(at - dir * 10 + Vector3.new(-12, 0, 0), -dir, 1.1)
	statue(at - dir * 10 + Vector3.new(12, 0, 0), -dir, 1.1)
end

-- Hidden library wall.
buildGate(gatesFolder, { Id = "LibraryWall", At = crawl[2] + Vector3.new(-4, 0, 0), Dir = gateDir(crawl, 2), Style = "Hidden" })

----------------------------------------------------------------------------
-- Sunken Temple: stepped pyramid, columns, braziers
----------------------------------------------------------------------------

local TC = Vector3.new(0, F_TEMPLE, -832)
local pyramid = folder("Pyramid", props, "Model")
for i = 0, 3 do
	local w = 36 - i * 8
	P({ Name = "Tier", Size = Vector3.new(w, 5, w), CFrame = CFrame.new(TC + Vector3.new(0, 2.5 + i * 5, 0)),
		Material = Enum.Material.Sandstone, Color = STONE:Lerp(STONE_DARK, i / 4), Parent = pyramid })
	P({ Name = "Trim", Size = Vector3.new(w + 0.4, 0.5, w + 0.4), CFrame = CFrame.new(TC + Vector3.new(0, 5 + i * 5, 0)),
		Material = Enum.Material.Foil, Color = GOLD, Parent = pyramid })
end
-- Stairs up the north face to the top platform.
for k = 1, 20 do
	P({ Name = "Step", Size = Vector3.new(12, k, 1.6), CFrame = CFrame.new(TC + Vector3.new(0, k / 2, 6 + (20 - k + 0.5) * 1.6)),
		Material = Enum.Material.Sandstone, Color = STONE, Parent = pyramid })
end
local top = TC + Vector3.new(0, 20, 0)
glyphStele(props, "SunGlyph1", "SunDoor", top + Vector3.new(-3, 0, 2), Vector3.new(0, 0, 1))
artifactPedestal(props, "StarMap", top + Vector3.new(3, 0, 1))

for i = 1, 12 do
	local a = i / 12 * math.pi * 2
	local p = TC + Vector3.new(math.cos(a) * 44, 0, math.sin(a) * 34)
	if math.abs(p.Z - (TC.Z + 34)) > 6 or math.abs(p.X) > 10 then
		column(p, 30, i % 4 == 1)
	end
end
for _, off in { Vector3.new(-22, 0, 22), Vector3.new(22, 0, 22), Vector3.new(-22, 0, -22), Vector3.new(22, 0, -22) } do
	brazier(TC + off)
end
brazier(Vector3.new(-10, F_TEMPLE, -790))
brazier(Vector3.new(10, F_TEMPLE, -790))

----------------------------------------------------------------------------
-- Sun Door (mechanism) and the Sun Vault
----------------------------------------------------------------------------

do
	local at = tunnels.SunDoor[2]
	local dir = gateDir(tunnels.SunDoor, 2)
	local model = folder("SunDoor", gatesFolder, "Model")
	local look = CFrame.lookAt(at, at + Vector3.new(dir.X, 0, dir.Z))
	local blocker = P({ Name = "Blocker", Size = Vector3.new(18, 18, 3), CFrame = look, Transparency = 1, Parent = model })
	model.PrimaryPart = blocker
	P({ Name = "Disc", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4, 17, 17),
		CFrame = look * CFrame.Angles(0, math.rad(90), 0), Material = Enum.Material.Sandstone, Color = STONE_DARK, Parent = model })
	P({ Name = "SunEmblem", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 6, 6),
		CFrame = look * CFrame.new(0, 0, -1.3) * CFrame.Angles(0, math.rad(90), 0), Material = Enum.Material.Foil, Color = GOLD, Parent = model })
	for i = 1, 3 do
		local a = i / 3 * math.pi * 2 + math.pi / 2
		P({ Name = "GlyphMark", Size = Vector3.new(1.2, 1.2, 0.3), CFrame = look * CFrame.new(math.cos(a) * 5.5, math.sin(a) * 5.5, -1.3),
			Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 200, 100), Transparency = 0.4, Parent = model })
	end
	model:SetAttribute("GateId", "SunDoor")
	model:SetAttribute("Mechanism", true)
	CollectionService:AddTag(model, "Gate")
end
do
	local f = floorBelow(Vector3.new(18, F_TEMPLE + 8, -928), 20)
	if f then
		artifactPedestal(props, "SunDisk", f)
	end
	brazier(Vector3.new(10, F_TEMPLE, -920))
	brazier(Vector3.new(26, F_TEMPLE, -920))
end

----------------------------------------------------------------------------
-- Catacombs (dark) and the Lost Library
----------------------------------------------------------------------------

do
	local f = floorBelow(Vector3.new(76, F_TEMPLE + 6, -902), 20)
	if f then
		glyphStele(props, "SunGlyph2", "SunDoor", f, Vector3.new(0, 0, 1))
	end
	f = floorBelow(Vector3.new(128, F_TEMPLE + 6, -812), 20)
	if f then
		artifactPedestal(props, "GildedMask", f)
	end
	-- Burial niches along the corridors.
	for _, path in catacombs do
		for i = 1, #path - 1 do
			local a, b = path[i], path[i + 1]
			local mid = (a + b) / 2
			local side = (b - a).Unit:Cross(Vector3.yAxis)
			for _, s in { -1, 1 } do
				local hit = ray(mid, side * s * 8)
				if hit then
					-- Flush with the wall so corridors stay clear.
					P({ Name = "Niche", Size = Vector3.new(2.6, 1.6, 0.3), CFrame = CFrame.lookAt(hit.Position - side * s * 0.1, hit.Position),
						Material = Enum.Material.Sandstone, Color = STONE_DARK, Parent = ruins })
				end
			end
		end
	end
end
do
	local f = floorBelow(Vector3.new(-134, -786, -702), 20)
	if f then
		glyphStele(props, "SunGlyph3", "SunDoor", f, Vector3.new(1, 0, 0))
	end
	f = floorBelow(Vector3.new(-134, -786, -712), 20)
	if f then
		artifactPedestal(props, "ScholarsCodex", f)
	end
	-- Shelves of bronze tablets.
	for i = 0, 2 do
		local s = floorBelow(Vector3.new(-122 + i * 4, -786, -697), 20)
		if s then
			P({ Name = "Shelf", Size = Vector3.new(3.6, 6, 1.2), CFrame = CFrame.new(s + Vector3.new(0, 3, 0)),
				Material = Enum.Material.WoodPlanks, Color = DARKWOOD, Parent = ruins })
		end
	end
	local c = floorBelow(Vector3.new(-124, -786, -710), 20)
	if c then
		lantern(ruins, c + Vector3.new(0, 1.5, 0), 0.1)
	end
end

----------------------------------------------------------------------------
-- The Ancient Seal, arrival and lifts
----------------------------------------------------------------------------

sealedWall(mine, {
	MineId = "Mine4", Title = "The Ancient Seal", X = -62, Z = SEAL_Z, ProbeY = -796,
	StoneA = Color3.fromRGB(150, 136, 104), StoneB = Color3.fromRGB(184, 168, 128), FrameColor = Color3.fromRGB(130, 116, 88),
	RuneColor = Color3.fromRGB(120, 230, 210), CrackColor = Color3.fromRGB(200, 255, 240),
	FireColor = Color3.fromRGB(255, 200, 110), FireColor2 = Color3.fromRGB(255, 120, 40),
})
buildPortal(mine, { X = -62, Z = SEAL_Z - 14, ProbeY = -796, FromMine = "Mine4", ToMine = "Mine5" })

do
	local f = floorBelow(Vector3.new(0, -782, -608), 30) or Vector3.new(0, -790, -608)
	local arrival = invisible("Arrival", CFrame.lookAt(f + Vector3.new(0, 3.5, 0), f + Vector3.new(0, 3.5, -10)),
		Vector3.new(1, 1, 1), mine)
	arrival:SetAttribute("MineId", "Mine4")
	local lf = floorBelow(Vector3.new(-6, -782, -612), 30)
	if lf then
		local cage = liftCage(mine, "Lift_AncientDepths", lf, Vector3.new(1, 0, 0), "Ride to Camp", "Mine Lift")
		cage:SetAttribute("LiftId", "AncientDepths")
	end
	local tf = floorBelow(Vector3.new(-26, F_TEMPLE + 8, -800), 20)
	if tf then
		local cage = liftCage(mine, "Lift_SunkenTemple", tf, Vector3.new(1, 0, -0.4), "Ride to Camp", "Mine Lift")
		cage:SetAttribute("LiftId", "SunkenTemple")
	end
end

local counts = {}
for zone, zf in zoneFolders do
	table.insert(counts, zone .. "=" .. #zf:GetChildren())
end
table.insert(buildReport, "Mine4 ore points: " .. table.concat(counts, " "))
end
