-- Mine 3: Lava Depths. Arrival -> Scorched Antechamber -> (cooled obsidian flow,
-- Obsidian Pickaxe) -> Lava Rivers (heat level 1, river crossed by bridges) ->
-- (magma plug) -> Magma Core (heat level 2) -> The Molten Seal.
-- Hidden: the Ember Vault behind a cracked wall off the west river cave.
do
local F_SCORCH, F_RIVER, F_CORE = -524, -533, -544

-- Volcanic rock for the whole mine.
T:FillBlock(CFrame.new(0, -525, -790), Vector3.new(400, 190, 440), Enum.Material.Basalt)

local chambers = {
	Arrival = { Zone = "Scorched", C = Vector2.new(0, -612), F = -520, rx = 10, rz = 8, Points = 0 },
	Scorched = { Zone = "Scorched", C = Vector2.new(0, -675), F = F_SCORCH, rx = 36, rz = 26, Points = 22, Tall = true },
	ScorchedEast = { Zone = "Scorched", C = Vector2.new(56, -702), F = -522, rx = 16, rz = 14, Points = 10 },
	Rivers = { Zone = "Rivers", C = Vector2.new(0, -800), F = F_RIVER, rx = 54, rz = 36, Points = 30, Tall = true },
	RiversWest = { Zone = "Rivers", C = Vector2.new(-76, -816), F = -531, rx = 18, rz = 15, Points = 12 },
	Vault = { Zone = "EmberVault", C = Vector2.new(-138, -822), F = -531, rx = 10, rz = 9, Points = 7 },
	Core = { Zone = "Core", C = Vector2.new(0, -930), F = F_CORE, rx = 42, rz = 30, Points = 24, Tall = true },
	CoreEast = { Zone = "Core", C = Vector2.new(58, -952), F = -548, rx = 15, rz = 13, Points = 10 },
	SealHall = { Zone = "Final", C = Vector2.new(0, -970), F = -546, rx = 20, rz = 8, Points = 0, Tall = true },
}

local tunnels = {
	ArrivalToScorched = { Vector3.new(0, -513, -618), Vector3.new(0, -515, -636), Vector3.new(0, -517, -652) },
	ScorchedEast = { Vector3.new(28, -517, -690), Vector3.new(44, -515, -698) },
	Flow = { Vector3.new(0, -517, -700), Vector3.new(0, -519, -718), Vector3.new(0, -521, -732),
		Vector3.new(0, -524, -746), Vector3.new(0, -526, -762) },
	RiversWest = { Vector3.new(-42, -526, -812), Vector3.new(-60, -524, -816) },
	Plug = { Vector3.new(0, -526, -836), Vector3.new(0, -529, -852), Vector3.new(0, -532, -866),
		Vector3.new(0, -535, -880), Vector3.new(0, -537, -898) },
	CoreEast = { Vector3.new(32, -537, -944), Vector3.new(46, -541, -950) },
	Seal = { Vector3.new(0, -537, -952), Vector3.new(0, -539, -962) },
}
local crawl = { Vector3.new(-92, -525, -818), Vector3.new(-110, -525, -821), Vector3.new(-128, -525, -822) }

local function gateDir(path, i)
	return (path[i + 1] - path[i - 1]).Unit
end
local GATES = {
	{ Id = "ObsidianFlow", At = tunnels.Flow[3], Dir = gateDir(tunnels.Flow, 3), Style = "Crystal",
		Text = "COOLED OBSIDIAN\nNeeds an Obsidian Pickaxe" },
	{ Id = "MagmaPlug", At = tunnels.Plug[3], Dir = gateDir(tunnels.Plug, 3), Style = "Crystal",
		Text = "MAGMA PLUG\nOnly a Magma Suit survives past here" },
	{ Id = "EmberVault", At = crawl[2] + Vector3.new(-4, 0, -0.4), Dir = gateDir(crawl, 2), Style = "Hidden" },
}

local SEAL_Z = -986

for _, ch in chambers do
	carveChamber(ch)
end
for _, path in tunnels do
	carveTunnel(path)
end
carveTunnel(crawl, 5)
T:FillBlock(CFrame.new(0, F_CORE + 16, SEAL_Z + 8), Vector3.new(54, 36, 16), AIR)
-- Passage behind the seal to the portal down to the Ancient Depths.
carveTunnel({ Vector3.new(0, F_CORE + 7, SEAL_Z - 2), Vector3.new(0, F_CORE + 7, SEAL_Z - 12) }, 8)
T:FillBall(Vector3.new(0, F_CORE + 10, SEAL_Z - 15), 8.5, AIR)

-- Glowing cracked-lava floors in the hot zones, scorched rock elsewhere.
T:ReplaceMaterial(Region3.new(Vector3.new(-140, F_RIVER - 8, -850), Vector3.new(140, F_RIVER + 2, -760)):ExpandToGrid(4), 4,
	Enum.Material.Basalt, Enum.Material.CrackedLava)
T:ReplaceMaterial(Region3.new(Vector3.new(-80, F_CORE - 10, -980), Vector3.new(80, F_CORE + 2, -895)):ExpandToGrid(4), 4,
	Enum.Material.Basalt, Enum.Material.CrackedLava)

local mine = folder("Mine3", minesFolder)
local props = folder("Props", mine)
local spawnsFolder = folder("OreSpawns", mine)
local gatesFolder = folder("Gates", mine)
local volumes = folder("ZoneVolumes", mine)
local hazards = folder("Hazards", mine)

-- Lava: a river winding across the Rivers chamber, pools in the core.
local riverPoints = {}
for x = -62, 62, 8 do
	table.insert(riverPoints, Vector3.new(x, F_RIVER, -800 + math.sin(x / 14) * 6))
end
local riverSamples = lavaRiver(props, riverPoints, F_RIVER)
local pools = { Vector3.new(-22, 0, -918), Vector3.new(24, 0, -936), Vector3.new(-6, 0, -944), Vector3.new(30, 0, -910) }
for _, c in pools do
	lavaPool(props, Vector3.new(c.X, 0, c.Z), 6, F_CORE)
end
-- Small glowing pools light the (otherwise safe) antechamber.
local scorchPools = { Vector3.new(-24, 0, -662), Vector3.new(26, 0, -668), Vector3.new(-8, 0, -702) }
for _, c in scorchPools do
	lavaPool(props, c, 4, F_SCORCH)
end

waitForTerrain(Vector3.new(chambers.SealHall.C.X, chambers.SealHall.F + 6, chambers.SealHall.C.Y))

-- Bridges over the river.
for _, x in { -26, 26 } do
	local z = -800 + math.sin(x / 14) * 6
	bridge(props, Vector3.new(x, 0, z + 9), Vector3.new(x, 0, z - 9), F_RIVER)
end

local keepClear = { Vector3.new(0, -520, -612), Vector3.new(0, F_CORE, SEAL_Z + 6) }
for _, list in { tunnels, { crawl } } do
	for _, path in list do
		table.insert(keepClear, path[1])
		table.insert(keepClear, path[#path])
	end
end
for _, p in riverSamples do
	table.insert(keepClear, p)
end
for _, p in pools do
	table.insert(keepClear, p)
end
for _, p in scorchPools do
	table.insert(keepClear, p)
end
for _, x in { -26, 26 } do
	table.insert(keepClear, Vector3.new(x, 0, -791))
	table.insert(keepClear, Vector3.new(x, 0, -809))
end
local zoneFolders = makeOreSpawns(chambers, spawnsFolder, keepClear)

zoneVolume(volumes, "Scorched", CFrame.new(0, -520, -665), Vector3.new(240, 110, 154))
zoneVolume(volumes, "Rivers", CFrame.new(0, -528, -804), Vector3.new(300, 110, 124))
zoneVolume(volumes, "Core", CFrame.new(0, -538, -933), Vector3.new(240, 110, 134))
zoneVolume(volumes, "Final", CFrame.new(0, -536, -978), Vector3.new(70, 60, 40), 1)
zoneVolume(volumes, "EmberVault", CFrame.new(-139, -528, -822), Vector3.new(30, 40, 30), 2)

-- Heat: the rivers need a Heat Suit, the core a Magma Suit.
hazardVolume(hazards, "Heat", 1, 14, CFrame.new(0, -525, -808), Vector3.new(300, 70, 116))
hazardVolume(hazards, "Heat", 2, 24, CFrame.new(0, -536, -934), Vector3.new(240, 70, 132))

for _, g in GATES do
	buildGate(gatesFolder, g)
end

-- Obsidian spikes and magma crystals for the volcanic look.
local deco = folder("Formations", props)
local OBSIDIAN = Color3.fromRGB(34, 24, 40)
local MAGMA = Color3.fromRGB(255, 120, 40)
for name, ch in chambers do
	if ch.Points <= 0 or name == "Vault" then
		continue
	end
	local origin = Vector3.new(ch.C.X, ch.F + 8, ch.C.Y)
	local count = math.floor((ch.rx + ch.rz) / 4)
	local placed = 0
	for _ = 1, count * 8 do
		if placed >= count then
			break
		end
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.7, 1), rng:NextNumber(-1, 1))
		if dir.Magnitude < 0.1 then
			continue
		end
		local hit = ray(origin, dir.Unit * 70)
		if hit and clearOf(hit.Position, keepClear, 9) then
			local hot = ch.Zone == "Core"
			local color = if hot and rng:NextNumber() < 0.6 then MAGMA else OBSIDIAN
			crystalCluster(deco, hit.Position, hit.Normal, rng:NextNumber(0.9, if hot then 2.4 else 1.8), color, color == OBSIDIAN or placed % 2 == 0)
			placed += 1
		end
	end
end

-- Lavafalls pouring from the ceiling into the river.
for _, x in { -46, 12, 50 } do
	local z = -800 + math.sin(x / 14) * 6
	local top = ceilingAbove(Vector3.new(x, F_RIVER + 4, z), 60)
	if top then
		local h = top.Y - (F_RIVER - 4)
		lavaSurface(props, CFrame.new(x, F_RIVER - 4 + h / 2, z), Vector3.new(3.5, h, 1.6), true, false)
	end
end

-- Smoke vents in the antechamber.
for _, p in { Vector3.new(10, 0, -650), Vector3.new(-32, 0, -690), Vector3.new(34, 0, -700) } do
	local f = floorBelow(Vector3.new(p.X, F_SCORCH + 8, p.Z), 20)
	if f then
		local vent = P({ Name = "Vent", Size = Vector3.new(2, 0.4, 2), CFrame = CFrame.new(f), Material = Enum.Material.CrackedLava,
			Color = Color3.fromRGB(60, 30, 20), CanCollide = false, Parent = props })
		local smoke = Instance.new("ParticleEmitter")
		smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
		smoke.Color = ColorSequence.new(Color3.fromRGB(90, 80, 76))
		smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 8) })
		smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
		smoke.Lifetime = NumberRange.new(4, 7)
		smoke.Rate = 3
		smoke.Speed = NumberRange.new(2, 4)
		smoke.EmissionDirection = Enum.NormalId.Top
		smoke.SpreadAngle = Vector2.new(12, 12)
		smoke.Parent = vent
	end
end

-- A burned-out camp at the antechamber edge: someone made it this far.
do
	local f = floorBelow(Vector3.new(-22, F_SCORCH + 8, -690), 20)
	if f then
		crate(props, CFrame.new(f + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0.1, 0.6, 0.2)).Color = Color3.fromRGB(50, 34, 26)
		barrel(props, f + Vector3.new(3, 0, 2))
		P({ Name = "NotePost", Size = Vector3.new(0.3, 3, 0.3), CFrame = CFrame.new(f + Vector3.new(-3, 1.5, 0)),
			Material = Enum.Material.Wood, Color = DARKWOOD, Parent = props })
		sign(props, CFrame.lookAt(f + Vector3.new(-3, 3.2, 0), f + Vector3.new(-3, 3.2, 6)), Vector3.new(4.4, 2.4, 0.15),
			"Too hot past the flow.\nNeed proper gear.\nTurning back.", Color3.fromRGB(255, 210, 180))
	end
end

-- The Molten Seal, with the portal to the Ancient Depths behind it.
sealedWall(mine, {
	MineId = "Mine3", Title = "The Molten Seal", X = 0, Z = SEAL_Z, ProbeY = F_CORE + 10,
	StoneA = Color3.fromRGB(56, 36, 32), StoneB = Color3.fromRGB(78, 50, 40), FrameColor = Color3.fromRGB(44, 30, 28),
	RuneColor = Color3.fromRGB(255, 120, 40), CrackColor = Color3.fromRGB(255, 200, 120),
	FireColor = Color3.fromRGB(255, 120, 40), FireColor2 = Color3.fromRGB(255, 40, 10),
})
buildPortal(mine, { X = 0, Z = SEAL_Z - 14, ProbeY = F_CORE + 10, FromMine = "Mine3", ToMine = "Mine4" })

-- Arrival point + lifts.
do
	local f = floorBelow(Vector3.new(0, -512, -608), 30) or Vector3.new(0, -520, -608)
	local arrival = invisible("Arrival", CFrame.lookAt(f + Vector3.new(0, 3.5, 0), f + Vector3.new(0, 3.5, -10)),
		Vector3.new(1, 1, 1), mine)
	arrival:SetAttribute("MineId", "Mine3")
	local lf = floorBelow(Vector3.new(-6, -512, -612), 30)
	if lf then
		local cage = liftCage(mine, "Lift_LavaDepths", lf, Vector3.new(1, 0, 0), "Ride to Camp", "Mine Lift")
		cage:SetAttribute("LiftId", "LavaDepths")
	end
	local rf = floorBelow(Vector3.new(-36, F_RIVER + 8, -778), 20)
	if rf then
		local cage = liftCage(mine, "Lift_LavaRivers", rf, Vector3.new(1, 0, -0.3), "Ride to Camp", "Mine Lift")
		cage:SetAttribute("LiftId", "LavaRivers")
	end
end

-- Artifact: the Ember Crown, in the Ember Vault.
do
	local f = floorBelow(Vector3.new(-144, F_RIVER + 8, -826), 20)
	if f then
		artifactPedestal(props, "EmberCrown", f)
	end
end

local counts = {}
for zone, zf in zoneFolders do
	table.insert(counts, zone .. "=" .. #zf:GetChildren())
end
table.insert(buildReport, "Mine3 ore points: " .. table.concat(counts, " ") .. ", formations: " .. #deco:GetChildren())
end
