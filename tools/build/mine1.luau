-- Mine 1: Abandoned Coal Mine. Upper tunnels -> Copper Seam -> Iron Hollow ->
-- the deep chamber with the Sealed Wall (ascension) and the portal behind it.
do
local chambers = {
	Hub = { Zone = "Upper", C = Vector2.new(0, -125), F = -28, rx = 22, rz = 16, Points = 22 },
	UpperWest = { Zone = "Upper", C = Vector2.new(-52, -140), F = -30, rx = 14, rz = 12, Points = 12 },
	UpperEast = { Zone = "Upper", C = Vector2.new(50, -150), F = -26, rx = 14, rz = 13, Points = 12 },
	Copper = { Zone = "Copper", C = Vector2.new(0, -215), F = -42, rx = 24, rz = 18, Points = 22 },
	CopperWest = { Zone = "Copper", C = Vector2.new(-55, -232), F = -46, rx = 15, rz = 12, Points = 14 },
	CopperEast = { Zone = "Copper", C = Vector2.new(48, -246), F = -40, rx = 14, rz = 12, Points = 12 },
	Iron = { Zone = "Iron", C = Vector2.new(0, -315), F = -62, rx = 28, rz = 22, Points = 26, Tall = true },
	IronWest = { Zone = "Iron", C = Vector2.new(-58, -332), F = -66, rx = 16, rz = 13, Points = 14 },
	IronEast = { Zone = "Iron", C = Vector2.new(55, -346), F = -60, rx = 16, rz = 14, Points = 14 },
	Deep = { Zone = "Iron", C = Vector2.new(0, -372), F = -70, rx = 22, rz = 15, Points = 10, Tall = true },
	-- The Old Workings: pitch black (no lanterns), needs the Miner's Lantern.
	Workings = { Zone = "Workings", C = Vector2.new(-108, -246), F = -48, rx = 16, rz = 13, Points = 10, NoLights = true },
	Workings2 = { Zone = "Workings", C = Vector2.new(-114, -278), F = -50, rx = 13, rz = 11, Points = 8, NoLights = true },
}

local tunnels = {
	Entrance = { Vector3.new(0, 7, -24), Vector3.new(0, 6, -48), Vector3.new(0, -1, -68), Vector3.new(0, -11, -88),
		Vector3.new(0, -18, -104), Vector3.new(0, -21, -118) },
	HubWest = { Vector3.new(-18, -21, -128), Vector3.new(-40, -23, -138) },
	HubEast = { Vector3.new(18, -21, -130), Vector3.new(40, -19, -146) },
	Gate1 = { Vector3.new(0, -21, -138), Vector3.new(0, -24, -156), Vector3.new(0, -28, -172), Vector3.new(0, -32, -186),
		Vector3.new(0, -35, -200) },
	CopperWest = { Vector3.new(-20, -35, -222), Vector3.new(-42, -39, -230) },
	CopperEast = { Vector3.new(20, -35, -224), Vector3.new(38, -33, -240) },
	Gate2 = { Vector3.new(0, -35, -230), Vector3.new(0, -40, -248), Vector3.new(0, -46, -264), Vector3.new(0, -51, -280),
		Vector3.new(0, -55, -296) },
	IronWest = { Vector3.new(-24, -55, -322), Vector3.new(-45, -59, -330) },
	IronEast = { Vector3.new(24, -55, -326), Vector3.new(44, -53, -342) },
	Deep = { Vector3.new(0, -55, -334), Vector3.new(0, -60, -352), Vector3.new(0, -63, -364) },
	Workings = { Vector3.new(-74, -39, -236), Vector3.new(-90, -41, -242) },
	Workings2 = { Vector3.new(-110, -41, -256), Vector3.new(-113, -43, -268) },
}

local GATES = {
	{ Id = "CopperGate", At = Vector3.new(0, -28, -172), Dir = (Vector3.new(0, -32, -186) - Vector3.new(0, -24, -156)).Unit,
		Text = "CAVE-IN!\nNeeds a Stone Pickaxe" },
	{ Id = "IronGate", At = Vector3.new(0, -46, -264), Dir = (Vector3.new(0, -51, -280) - Vector3.new(0, -40, -248)).Unit,
		Text = "SHAFT COLLAPSED\nNeeds an Iron Pickaxe" },
}

-- The Sealed Wall stands across a passage leading out of the back of the deep chamber.
local WALL_Z = -396
local PORTAL_Z = -428

for _, ch in chambers do
	carveChamber(ch)
end
for _, path in tunnels do
	carveTunnel(path)
end
carveTunnel({ Vector3.new(0, -63, -384), Vector3.new(0, -63, PORTAL_Z + 4) }, 8)
-- Open a tall, flat face in front of the wall so the whole wall and its frame
-- are visible from the chamber (floor stays at the chamber floor height).
T:FillBlock(CFrame.new(0, -52, -386.5), Vector3.new(54, 37, 21), AIR)
for _, x in { -20, 0, 20 } do
	T:FillBall(Vector3.new(x, -42, -380), 14, AIR)
end
T:FillBall(Vector3.new(0, -59, PORTAL_Z), 11, AIR)
-- Rough up the entrance mouth so it reads as a hole in the cliff.
T:FillBall(Vector3.new(0, 8, -30), 9, AIR)
-- A path of dirt from camp to the entrance.
T:FillBlock(CFrame.new(0, -0.5, -4), Vector3.new(10, 3, 44), Enum.Material.Ground)
T:FillBlock(CFrame.new(0, -0.5, 30), Vector3.new(8, 3, 30), Enum.Material.Ground)

waitForTerrain(Vector3.new(chambers.Deep.C.X, chambers.Deep.F + 6, chambers.Deep.C.Y))

local mine = folder("Mine1", minesFolder)
local props = folder("Props", mine)
local spawnsFolder = folder("OreSpawns", mine)
local gatesFolder = folder("Gates", mine)
local volumes = folder("ZoneVolumes", mine)

-- Points that must stay clear of ore (doorways).
local keepClear = { Vector3.new(0, -63, -384), Vector3.new(0, -66, -392) }
for _, path in tunnels do
	table.insert(keepClear, path[1])
	table.insert(keepClear, path[#path])
end
local zoneFolders = makeOreSpawns(chambers, spawnsFolder, keepClear)

-- Zone volumes (split at the gates). The final chamber overrides Iron.
zoneVolume(volumes, "Upper", CFrame.new(0, -55, -103), Vector3.new(220, 140, 138))
zoneVolume(volumes, "Copper", CFrame.new(0, -55, -218), Vector3.new(220, 140, 92))
zoneVolume(volumes, "Iron", CFrame.new(0, -55, -347), Vector3.new(220, 140, 166))
zoneVolume(volumes, "Final", CFrame.new(0, -60, -395), Vector3.new(70, 50, 70), 1)
zoneVolume(volumes, "Workings", CFrame.new(-110, -50, -262), Vector3.new(50, 40, 64), 1)

-- Rubble gates.
for _, g in GATES do
	buildGate(gatesFolder, g)
end

-- Supports and lanterns along tunnels.
local function nearGate(pos)
	for _, g in GATES do
		if (pos - g.At).Magnitude < 12 then
			return true
		end
	end
	return false
end
local function inChamber(pos)
	for _, ch in chambers do
		local d = Vector2.new((pos.X - ch.C.X) / (ch.rx + 4), (pos.Z - ch.C.Y) / (ch.rz + 4))
		if d.Magnitude < 1 then
			return true
		end
	end
	return false
end

local tunnelProps = folder("Tunnels", props)
for name, path in tunnels do
	local walked = 0
	for i = 1, #path - 1 do
		local a, b = path[i], path[i + 1]
		local len = (b - a).Magnitude
		local dir = (b - a).Unit
		local d = 4
		while d < len do
			local pos = a + dir * d
			if not nearGate(pos) and not inChamber(pos) and pos.Z < -34 then
				local step = math.floor((walked + d) / 14)
				if step % 2 == 0 or name:find("Workings") then
					support(tunnelProps, pos, dir)
				else
					ceilingLantern(tunnelProps, pos)
				end
			end
			d += 14
		end
		walked += len
	end
end

-- Chamber lanterns.
local chamberProps = folder("Chambers", props)
for _, ch in chambers do
	if ch.NoLights then
		continue
	end
	local count = if ch.rx > 20 then 4 else 2
	for i = 1, count do
		local a = (i / count) * math.pi * 2 + 0.4
		ceilingLantern(chamberProps, Vector3.new(ch.C.X + math.cos(a) * ch.rx * 0.55, ch.F + 6, ch.C.Y + math.sin(a) * ch.rz * 0.55))
	end
end

-- Rails from outside down the entrance tunnel into the hub.
local rails = folder("Rails", props, "Model")
do
	local path = { Vector3.new(0, 7, -6) }
	for _, p in tunnels.Entrance do
		table.insert(path, p)
	end
	table.insert(path, Vector3.new(0, -21, -121))
	local ties = {}
	for i = 1, #path - 1 do
		local a, b = path[i], path[i + 1]
		local len = (b - a).Magnitude
		local d = 0
		while d < len do
			local floor = floorBelow(a:Lerp(b, d / len) + Vector3.new(0, 4, 0), 30)
			if floor then
				table.insert(ties, floor + Vector3.new(0, 0.15, 0))
			end
			d += 3
		end
	end
	for i, pos in ties do
		local nextPos = ties[i + 1] or (pos + (pos - ties[i - 1]))
		local look = CFrame.lookAt(pos, nextPos)
		P({ Name = "Tie", Size = Vector3.new(4.6, 0.3, 0.8), CFrame = look, Material = Enum.Material.Wood, Color = DARKWOOD,
			CanCollide = false, Parent = rails })
		if ties[i + 1] then
			local len = (nextPos - pos).Magnitude
			for _, x in { -1.3, 1.3 } do
				P({ Name = "Rail", Size = Vector3.new(0.25, 0.3, len + 0.1),
					CFrame = look * CFrame.new(x, 0.3, -len / 2), Material = Enum.Material.Metal, Color = IRON,
					CanCollide = false, Parent = rails })
			end
		end
	end
end

-- Set dressing inside the mine.
local dressing = folder("Dressing", props)
local function onFloor(x, z, yHint)
	return floorBelow(Vector3.new(x, yHint + 8, z), 30)
end
do
	local f = onFloor(-11, -121, chambers.Hub.F)
	if f then
		mineCart(dressing, CFrame.new(f) * CFrame.Angles(0, 0.5, 0) * CFrame.new(0, 0.2, 0), Color3.fromRGB(32, 30, 32))
	end
	f = onFloor(-10, -205, chambers.Copper.F)
	if f then
		mineCart(dressing, CFrame.new(f) * CFrame.Angles(0, 0.7, 0), nil, true)
	end
	-- Abandoned camp in the east upper chamber.
	f = onFloor(56, -156, chambers.UpperEast.F)
	if f then
		crate(dressing, CFrame.new(f + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0.3, 0))
		crate(dressing, CFrame.new(f + Vector3.new(0.4, 3.4, 0.2)) * CFrame.Angles(0, 0.9, 0), 2)
		barrel(dressing, f + Vector3.new(3.4, 0, 1))
		P({ Name = "Bedroll", Size = Vector3.new(2.4, 0.5, 6), CFrame = CFrame.new(f + Vector3.new(-3, 0.25, 2)) * CFrame.Angles(0, 0.2, 0),
			Material = Enum.Material.Fabric, Color = Color3.fromRGB(110, 54, 46), CanCollide = false, Parent = dressing })
		lantern(dressing, f + Vector3.new(1.5, 4.2, -2), 0.3)
	end
	f = onFloor(-60, -334, chambers.IronWest.F)
	if f then
		crate(dressing, CFrame.new(f + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0.2, 0.5, 0.15))
		barrel(dressing, f + Vector3.new(-3, 0, 2))
	end
	f = onFloor(-8, -132, chambers.Hub.F)
	if f then
		sign(dressing, CFrame.lookAt(f + Vector3.new(0, 4.5, 0), f + Vector3.new(0, 4.5, 6)), Vector3.new(5, 2, 0.2),
			"LOWER SEAM\nTHIS WAY")
		P({ Name = "SignPost", Size = Vector3.new(0.4, 4, 0.4), CFrame = CFrame.new(f + Vector3.new(0, 2, 0)),
			Material = Enum.Material.Wood, Color = WOOD, Parent = dressing })
	end
end

-- Old Workings: a warning sign at the mouth and a few abandoned things inside.
do
	local mouth = floorBelow(Vector3.new(-72, -38, -235), 20)
	if mouth then
		P({ Name = "SignPost", Size = Vector3.new(0.4, 4, 0.4), CFrame = CFrame.new(mouth + Vector3.new(0, 2, 2.5)),
			Material = Enum.Material.Wood, Color = WOOD, Parent = dressing })
		sign(dressing, CFrame.lookAt(mouth + Vector3.new(0, 4.4, 2.5), mouth + Vector3.new(6, 4.4, 2.5)), Vector3.new(5, 2.4, 0.2),
			"OLD WORKINGS\nNo light beyond\nthis point", Color3.fromRGB(255, 160, 120))
	end
	local f = floorBelow(Vector3.new(-104, -40, -244), 20)
	if f then
		mineCart(dressing, CFrame.new(f) * CFrame.Angles(0, 1.1, 0), nil, true)
		crate(dressing, CFrame.new(f + Vector3.new(5, 1.2, 3)) * CFrame.Angles(0.3, 0.4, 0.2))
	end
	f = floorBelow(Vector3.new(-118, -42, -280), 20)
	if f then
		barrel(dressing, f + Vector3.new(2, 0, 0))
		lantern(dressing, f + Vector3.new(-1, 1.6, 1), 0.1):FindFirstChildWhichIsA("PointLight", true):Destroy()
	end
end

sealedWall(mine, {
	MineId = "Mine1", Title = "The Sealed Wall", X = 0, Z = WALL_Z, ProbeY = -58,
	StoneA = Color3.fromRGB(62, 64, 74), StoneB = Color3.fromRGB(84, 84, 96), FrameColor = Color3.fromRGB(56, 56, 64),
	RuneColor = Color3.fromRGB(150, 110, 255), CrackColor = Color3.fromRGB(210, 190, 255),
	FireColor = Color3.fromRGB(255, 150, 60), FireColor2 = Color3.fromRGB(255, 70, 20),
})
buildPortal(mine, { X = 0, Z = PORTAL_Z, ProbeY = -58, FromMine = "Mine1", ToMine = "Mine2" })
-- Lift stop in the Iron Hollow (unlocked once the shaft is open).
do
	local f = floorBelow(Vector3.new(-16, -54, -302), 30)
	if f then
		local cage = liftCage(mine, "Lift_IronHollow", f, Vector3.new(0.6, 0, -1), "Ride to Camp", "Mine Lift")
		cage:SetAttribute("LiftId", "IronHollow")
	end
end

-- Artifact: the Lucky Lantern, deep in the Old Workings.
do
	local f = floorBelow(Vector3.new(-120, -42, -284), 20)
	if f then
		artifactPedestal(props, "LuckyLantern", f)
	end
end

local counts = {}
for zone, zf in zoneFolders do
	table.insert(counts, zone .. "=" .. #zf:GetChildren())
end
table.insert(buildReport, "Mine1 ore points: " .. table.concat(counts, " "))
end
