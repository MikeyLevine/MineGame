-- Shared helpers for the map builders. Not run on its own: tools/studio.py build
-- concatenates lib.luau + world.luau + mine*.luau + camp.luau into one chunk.
-- Fixed seed so layouts are identical every build.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local StarterPlayer = game:GetService("StarterPlayer")

local T = workspace.Terrain
local AIR = Enum.Material.Air
local rng = Random.new(1612)

local WOOD = Color3.fromRGB(112, 80, 52)
local DARKWOOD = Color3.fromRGB(78, 56, 38)
local IRON = Color3.fromRGB(70, 70, 74)
local LAMP = Color3.fromRGB(255, 196, 120)

----------------------------------------------------------------------------
-- helpers
----------------------------------------------------------------------------

local function P(props)
	local cls = props.Class or "Part"
	props.Class = nil
	local p = Instance.new(cls)
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local parent = props.Parent
	props.Parent = nil
	for k, v in props do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function folder(name, parent, class)
	local f = Instance.new(class or "Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { T }

local function ray(origin, dir)
	return workspace:Raycast(origin, dir, terrainOnly)
end

local function floorBelow(pos, maxDist)
	local hit = ray(pos, Vector3.new(0, -(maxDist or 30), 0))
	return hit and hit.Position
end

local function ceilingAbove(pos, maxDist)
	local hit = ray(pos, Vector3.new(0, maxDist or 30, 0))
	return hit and hit.Position
end

local function sign(parent, cf, size, text, textColor)
	local board = P({
		Name = "Sign",
		Size = size,
		CFrame = cf,
		Material = Enum.Material.WoodPlanks,
		Color = DARKWOOD,
		CanCollide = false,
		Parent = parent,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 1
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextScaled = true
	label.TextWrapped = true
	label.FontFace = Font.new("rbxasset://fonts/families/Bangers.json")
	label.TextColor3 = textColor or Color3.fromRGB(240, 220, 180)
	label.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.05, 0)
	pad.PaddingRight = UDim.new(0.05, 0)
	pad.PaddingTop = UDim.new(0.08, 0)
	pad.PaddingBottom = UDim.new(0.08, 0)
	pad.Parent = label
	return board
end

local function lantern(parent, hangPoint, ropeLength)
	local model = folder("Lantern", parent, "Model")
	local top = hangPoint
	local bodyPos = top - Vector3.new(0, ropeLength + 0.9, 0)
	P({ Name = "Rope", Size = Vector3.new(0.12, ropeLength, 0.12), CFrame = CFrame.new(top - Vector3.new(0, ropeLength / 2, 0)),
		Material = Enum.Material.Fabric, Color = Color3.fromRGB(70, 60, 50), CanCollide = false, Parent = model })
	P({ Name = "Cap", Size = Vector3.new(0.9, 0.25, 0.9), CFrame = CFrame.new(bodyPos + Vector3.new(0, 0.75, 0)),
		Material = Enum.Material.Metal, Color = IRON, CanCollide = false, Parent = model })
	local glass = P({ Name = "Glass", Size = Vector3.new(0.7, 1.1, 0.7), CFrame = CFrame.new(bodyPos),
		Material = Enum.Material.Neon, Color = LAMP, Transparency = 0.15, CanCollide = false, CastShadow = false, Parent = model })
	P({ Name = "Base", Size = Vector3.new(0.9, 0.2, 0.9), CFrame = CFrame.new(bodyPos - Vector3.new(0, 0.65, 0)),
		Material = Enum.Material.Metal, Color = IRON, CanCollide = false, Parent = model })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 204, 150)
	light.Range = 20
	light.Brightness = 0.8
	-- Shadow-casting lights are expensive; dozens of lanterns don't need them.
	light.Shadows = false
	light.Parent = glass
	return model
end

-- Hangs a lantern from the ceiling above `pos` if there is one in reach.
local function ceilingLantern(parent, pos)
	local ceil = ceilingAbove(pos, 25)
	local floor = floorBelow(pos, 25)
	if not ceil or not floor then
		return
	end
	local height = ceil.Y - floor.Y
	local rope = math.clamp(height - 7.5, 0.5, 8)
	lantern(parent, ceil - Vector3.new(0, 0.2, 0), rope)
end

-- Timber support frame across a tunnel at `center`, facing along `dir`.
local function support(parent, center, dir)
	local flatDir = Vector3.new(dir.X, 0, dir.Z).Unit
	local side = flatDir:Cross(Vector3.yAxis).Unit
	local model = folder("Support", parent, "Model")
	local tops = {}
	for _, s in { -1, 1 } do
		local probe = center + side * s * 4.6
		local floor = floorBelow(probe, 20)
		local ceil = ceilingAbove(probe, 20)
		if not floor or not ceil then
			model:Destroy()
			return
		end
		local h = ceil.Y - floor.Y + 0.6
		if h < 6 or h > 18 then
			model:Destroy()
			return
		end
		P({ Name = "Post", Size = Vector3.new(0.9, h, 0.9),
			CFrame = CFrame.lookAt(floor + Vector3.new(0, h / 2 - 0.3, 0), floor + Vector3.new(0, h / 2 - 0.3, 0) + flatDir),
			Material = Enum.Material.Wood, Color = WOOD, Parent = model })
		table.insert(tops, floor + Vector3.new(0, h - 0.6, 0))
	end
	local beamY = math.min(tops[1].Y, tops[2].Y)
	local a = Vector3.new(tops[1].X, beamY, tops[1].Z)
	local b = Vector3.new(tops[2].X, beamY, tops[2].Z)
	P({ Name = "Beam", Size = Vector3.new(1, 1, (a - b).Magnitude + 1.4),
		CFrame = CFrame.lookAt((a + b) / 2, b), Material = Enum.Material.Wood, Color = DARKWOOD, Parent = model })
end

local function crate(parent, cf, s)
	s = s or 2.4
	local c = P({ Name = "Crate", Size = Vector3.new(s, s, s), CFrame = cf, Material = Enum.Material.WoodPlanks,
		Color = WOOD, Parent = parent })
	return c
end

local function barrel(parent, pos)
	P({ Name = "Barrel", Class = "Part", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 2.2, 2.2),
		CFrame = CFrame.new(pos + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Wood, Color = Color3.fromRGB(96, 66, 42), Parent = parent })
end

local function mineCart(parent, cf, oreColor, tipped)
	local model = folder("MineCart", parent, "Model")
	local base = cf * (if tipped then CFrame.Angles(0, 0, math.rad(80)) else CFrame.new())
	local function piece(name, size, offset, color, mat)
		return P({ Name = name, Size = size, CFrame = base * offset, Color = color or IRON,
			Material = mat or Enum.Material.CorrodedMetal, Parent = model })
	end
	piece("Floor", Vector3.new(3.2, 0.3, 4.6), CFrame.new(0, 1.2, 0))
	piece("SideL", Vector3.new(0.3, 2, 4.6), CFrame.new(-1.6, 2.2, 0))
	piece("SideR", Vector3.new(0.3, 2, 4.6), CFrame.new(1.6, 2.2, 0))
	piece("Front", Vector3.new(3.2, 2, 0.3), CFrame.new(0, 2.2, -2.3))
	piece("Back", Vector3.new(3.2, 2, 0.3), CFrame.new(0, 2.2, 2.3))
	for _, x in { -1.7, 1.7 } do
		for _, z in { -1.5, 1.5 } do
			P({ Name = "Wheel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 1.2, 1.2),
				CFrame = base * CFrame.new(x, 0.6, z), Material = Enum.Material.Metal, Color = Color3.fromRGB(40, 40, 42), Parent = model })
		end
	end
	if oreColor and not tipped then
		for i = 1, 7 do
			P({ Name = "Load", Size = Vector3.new(1.1, 1.1, 1.1),
				CFrame = base * CFrame.new(rng:NextNumber(-0.9, 0.9), 2.9 + rng:NextNumber(0, 0.4), rng:NextNumber(-1.6, 1.6))
					* CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0),
				Material = Enum.Material.Slate, Color = oreColor, CanCollide = false, Parent = model })
		end
	end
	return model
end


----------------------------------------------------------------------------
-- cave carving
----------------------------------------------------------------------------

-- Chambers: floor height F, footprint radii rx/rz around C (x, z).
-- Tunnel centerlines run 7 studs above their floor with radius 7.5.
local TUNNEL_R = 7.5

local function carveChamber(ch)
	local y = ch.F + 11
	for x = -ch.rx, ch.rx, 6 do
		for z = -ch.rz, ch.rz, 6 do
			if (x / ch.rx) ^ 2 + (z / ch.rz) ^ 2 <= 1.05 then
				T:FillBall(Vector3.new(ch.C.X + x, y + rng:NextNumber(-0.5, 1.5), ch.C.Y + z), 11, AIR)
			end
		end
	end
	-- Dome so chambers feel bigger than tunnels.
	local domeY = ch.F + (if ch.Tall then 20 else 15)
	for _ = 1, (if ch.Tall then 8 else 5) do
		local off = Vector2.new(rng:NextNumber(-ch.rx, ch.rx) * 0.5, rng:NextNumber(-ch.rz, ch.rz) * 0.5)
		T:FillBall(Vector3.new(ch.C.X + off.X, domeY, ch.C.Y + off.Y), if ch.Tall then 13 else 9, AIR)
	end
end

local function carveTunnel(points, radius)
	local r = radius or TUNNEL_R
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local steps = math.ceil((b - a).Magnitude / (r * 0.35))
		for s = 0, steps do
			T:FillBall(a:Lerp(b, s / steps), r, AIR)
		end
	end
end

-- Terrain collision updates asynchronously; wait until `probe` can hit the
-- floor below it before raycasting for prop placement.
local function waitForTerrain(probe)
	local deadline = os.clock() + 20
	while not ray(probe, Vector3.new(0, -20, 0)) and os.clock() < deadline do
		task.wait(0.2)
	end
	task.wait(0.5)
end

local function clearOf(pos, list, dist)
	for _, p in list do
		if (Vector3.new(p.X, 0, p.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude < dist then
			return false
		end
	end
	return true
end

-- Ore spawn points: raycast from inside each chamber towards floor and walls.
-- Returns { [zoneId] = Folder }.
local function makeOreSpawns(chambers, spawnsFolder, keepClear)
	local allPoints = {}
	local zoneFolders = {}
	for name, ch in chambers do
		if not ch.Points or ch.Points <= 0 then
			continue
		end
		local zf = zoneFolders[ch.Zone] or spawnsFolder:FindFirstChild(ch.Zone) or folder(ch.Zone, spawnsFolder)
		zoneFolders[ch.Zone] = zf
		local origin = Vector3.new(ch.C.X, ch.F + 6, ch.C.Y)
		local made, tries = 0, 0
		while made < ch.Points and tries < 600 do
			tries += 1
			local angle = rng:NextNumber(0, math.pi * 2)
			local down = if rng:NextNumber() < 0.8 then rng:NextNumber(-0.9, -0.2) else rng:NextNumber(-0.15, 0.1)
			local dir = Vector3.new(math.cos(angle), down, math.sin(angle)).Unit
			local hit = ray(origin, dir * 45)
			if hit and hit.Normal.Y > -0.1 and clearOf(hit.Position, allPoints, 6.5)
				and clearOf(hit.Position, keepClear, 9) then
				local normal = hit.Normal
				if normal.Y > 0.6 then
					normal = Vector3.yAxis:Lerp(normal, 0.4).Unit -- floors: keep rocks upright
				end
				local right = normal:Cross(Vector3.zAxis)
				if right.Magnitude < 0.1 then
					right = normal:Cross(Vector3.xAxis)
				end
				right = right.Unit
				local back = right:Cross(normal).Unit
				local point = P({
					Name = name .. "_" .. made,
					Size = Vector3.new(1, 1, 1),
					CFrame = CFrame.fromMatrix(hit.Position - hit.Normal * 0.6, right, normal, back),
					Transparency = 1,
					CanCollide = false,
					CanQuery = false,
					CanTouch = false,
					Parent = zf,
				})
				point:SetAttribute("Chamber", name)
				table.insert(allPoints, hit.Position)
				made += 1
			end
		end
	end
	return zoneFolders
end

-- Invisible box used for zone detection. Higher priority wins where boxes overlap.
local function zoneVolume(parent, zoneId, cf, size, priority)
	local v = P({
		Name = zoneId,
		Size = size,
		CFrame = cf,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = parent,
	})
	v:SetAttribute("ZoneId", zoneId)
	v:SetAttribute("Priority", priority or 0)
	return v
end

local function invisible(name, cf, size, parent)
	return P({ Name = name, Size = size, CFrame = cf, Transparency = 1, CanCollide = false, CanQuery = false,
		CanTouch = false, Parent = parent })
end

-- Glowing crystal cluster growing out of a surface at `pos` along `normal`.
local CRYSTAL_COLORS = {
	Color3.fromRGB(160, 100, 255),
	Color3.fromRGB(90, 190, 255),
	Color3.fromRGB(200, 140, 255),
	Color3.fromRGB(110, 230, 240),
}
local function crystalCluster(parent, pos, normal, scale, color, noLight)
	local model = folder("Crystal", parent, "Model")
	color = color or CRYSTAL_COLORS[rng:NextInteger(1, #CRYSTAL_COLORS)]
	local up = normal.Unit
	local right = up:Cross(Vector3.zAxis)
	if right.Magnitude < 0.1 then
		right = up:Cross(Vector3.xAxis)
	end
	local base = CFrame.fromMatrix(pos, right.Unit, up)
	for i = 1, rng:NextInteger(3, 6) do
		local h = rng:NextNumber(2.5, 7) * scale
		local w = rng:NextNumber(0.7, 1.4) * scale
		local tilt = CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 6), rng:NextNumber(-0.5, 0.5))
		local cf = base * CFrame.new(rng:NextNumber(-1, 1) * scale, 0, rng:NextNumber(-1, 1) * scale) * tilt
		P({ Name = "Shard", Size = Vector3.new(w, h, w), CFrame = cf * CFrame.new(0, h / 2 - 0.4, 0) * CFrame.Angles(0, math.rad(45), 0),
			Material = if i % 3 == 0 then Enum.Material.Glass else Enum.Material.Neon, Color = color,
			Transparency = if i % 3 == 0 then 0.25 else 0.1, CastShadow = false,
			-- Decorative only: never trap players or block clicks on ore behind them.
			CanCollide = false, CanQuery = false, CanTouch = false, Parent = model })
	end
	if not noLight then
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = math.min(16 * scale, 36)
		light.Brightness = 0.8
		light.Parent = model:FindFirstChild("Shard")
	end
	return model
end

-- A blockage across a tunnel, broken per-player by mining it (see GateService).
-- g = { Id, At, Dir, Text?, Style = "Rubble" | "Crystal" | "Hidden" }
local function buildGate(gatesFolder, g)
	local model = folder(g.Id, gatesFolder, "Model")
	local look = CFrame.lookAt(g.At, g.At + g.Dir)
	local right, up = look.RightVector, look.UpVector
	-- Invisible blocker guarantees the passage is sealed.
	local blocker = P({
		Name = "Blocker",
		Size = Vector3.new(20, 20, 3),
		CFrame = look,
		Transparency = 1,
		CanCollide = true,
		Parent = model,
	})
	model.PrimaryPart = blocker
	local style = g.Style or "Rubble"
	local palette = if style == "Crystal" then { Color3.fromRGB(70, 66, 92), Color3.fromRGB(52, 50, 70) }
		elseif style == "Hidden" then { Color3.fromRGB(78, 80, 92), Color3.fromRGB(64, 66, 78) }
		else { Color3.fromRGB(96, 90, 84), Color3.fromRGB(70, 62, 56) }
	for i = 1, (if style == "Hidden" then 34 else 26) do
		local r = rng:NextNumber(0, 7.5)
		local a = rng:NextNumber(0, math.pi * 2)
		local s = rng:NextNumber(2.6, 5.2)
		local pos = g.At + right * math.cos(a) * r + up * (math.sin(a) * r * 0.9) + g.Dir * rng:NextNumber(-2.5, 1.5)
		P({
			Name = "Rubble",
			Size = Vector3.new(s, s * rng:NextNumber(0.6, 1), s * rng:NextNumber(0.8, 1.2)),
			CFrame = CFrame.new(pos) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6)),
			Material = Enum.Material.Slate,
			Color = palette[1]:Lerp(palette[2], rng:NextNumber()),
			Parent = model,
		})
	end
	if style == "Crystal" then
		-- Crystals grown through the blockage.
		for _ = 1, 9 do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(1, 7)
			crystalCluster(model, g.At + right * math.cos(a) * r + up * math.sin(a) * r - g.Dir * 2.4,
				-g.Dir + Vector3.new(rng:NextNumber(-0.4, 0.4), rng:NextNumber(-0.2, 0.6), 0), rng:NextNumber(0.6, 1.1),
				CRYSTAL_COLORS[rng:NextInteger(1, 2)], true)
		end
	elseif style == "Hidden" then
		-- A few faint glints in the cracks: the only hint something is behind it.
		for _ = 1, 6 do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(0.5, 5)
			P({ Name = "Glint", Size = Vector3.new(0.18, 0.18, 0.18), Material = Enum.Material.Neon,
				Color = Color3.fromRGB(200, 220, 255), Transparency = 0.2, CanCollide = false, CastShadow = false,
				CFrame = CFrame.new(g.At + right * math.cos(a) * r + up * math.sin(a) * r - g.Dir * 3.6), Parent = model })
		end
	end
	-- Broken timbers sticking out of the pile.
	for i = 1, (if style == "Rubble" then 3 else 0) do
		P({
			Name = "BrokenBeam",
			Size = Vector3.new(0.9, 0.9, rng:NextNumber(7, 10)),
			CFrame = look * CFrame.new(rng:NextNumber(-4, 4), rng:NextNumber(-3, 3), -2.5)
				* CFrame.Angles(rng:NextNumber(-0.6, 0.6), rng:NextNumber(-1.2, 1.2), rng:NextNumber(-0.5, 0.5)),
			Material = Enum.Material.Wood,
			Color = DARKWOOD,
			Parent = model,
		})
	end
	local floor = g.Text and floorBelow(g.At - g.Dir * 7, 20)
	if floor then
		local postBase = floor + right * 4.5
		P({ Name = "SignPost", Size = Vector3.new(0.4, 4, 0.4), CFrame = CFrame.new(postBase + Vector3.new(0, 2, 0)),
			Material = Enum.Material.Wood, Color = WOOD, Parent = model })
		sign(model, CFrame.lookAt(postBase + Vector3.new(0, 4, 0), postBase + Vector3.new(0, 4, 0) - g.Dir),
			Vector3.new(4.4, 2.2, 0.2), g.Text, Color3.fromRGB(255, 196, 120))
	end
	model:SetAttribute("GateId", g.Id)
	CollectionService:AddTag(model, "Gate")
	return model
end

-- The ascension wall at the end of a mine. Front faces +Z. opts = { MineId, Title, X, Z, ProbeY,
-- StoneA, StoneB, FrameColor, RuneColor, CrackColor, FireColor, FireColor2 }
local function sealedWall(mine, opts)
	local floor = floorBelow(Vector3.new(opts.X, opts.ProbeY, opts.Z + 4), 30) or Vector3.new(opts.X, opts.ProbeY - 12, opts.Z + 4)
	local baseY = floor.Y - 1
	local wall = folder("SealedWall", mine, "Model")
	-- Front faces +Z (towards the player coming from the deep chamber).
	local face = CFrame.new(opts.X, baseY, opts.Z) * CFrame.Angles(0, math.pi, 0)
	local blocks = folder("Blocks", wall)
	local rowH, cols = 4.6, 7
	for row = 0, 6 do
		local offset = if row % 2 == 0 then 0 else 2.6
		for col = -cols, cols do
			local x = col * 5.2 + offset
			if math.abs(x) <= 18.5 then
				local tint = rng:NextNumber()
				P({ Name = "Block", Size = Vector3.new(5.1, rowH - 0.1, 3.2 + rng:NextNumber(-0.3, 0.4)),
					CFrame = face * CFrame.new(x, rowH * row + rowH / 2, rng:NextNumber(-0.25, 0.25)),
					Material = Enum.Material.Slate,
					Color = opts.StoneA:Lerp(opts.StoneB, tint), Parent = blocks })
			end
		end
	end
	-- Faint runes hinting at what lies beyond; brighten during ascension.
	local runes = folder("Runes", wall)
	for i = 1, 14 do
		local x, y = rng:NextNumber(-15, 15), rng:NextNumber(4, 28)
		local vertical = rng:NextNumber() < 0.5
		P({ Name = "Rune", Size = if vertical then Vector3.new(0.3, rng:NextNumber(1.2, 2.6), 0.1) else Vector3.new(rng:NextNumber(1.2, 2.6), 0.3, 0.1),
			CFrame = face * CFrame.new(x, y, -1.75), Material = Enum.Material.Neon,
			Color = opts.RuneColor, Transparency = 0.6, CanCollide = false, Parent = runes })
	end
	-- Crack lines, invisible until the wall starts to break.
	local cracks = folder("Cracks", wall)
	local function crackFrom(start, dir, segments)
		local pos = start
		for _ = 1, segments do
			local len = rng:NextNumber(2, 4.5)
			local ang = math.atan2(dir.Y, dir.X) + rng:NextNumber(-0.7, 0.7)
			local d = Vector2.new(math.cos(ang), math.sin(ang))
			local mid = pos + d * len / 2
			P({ Name = "Crack", Size = Vector3.new(len, 0.28, 0.12),
				CFrame = face * CFrame.new(mid.X, mid.Y, -1.78) * CFrame.Angles(0, 0, ang),
				Material = Enum.Material.Neon, Color = opts.CrackColor, Transparency = 1,
				CanCollide = false, Parent = cracks })
			pos += d * len
			dir = d
		end
	end
	local center = Vector2.new(0, 14)
	for i = 1, 9 do
		local a = i / 9 * math.pi * 2
		crackFrom(center, Vector2.new(math.cos(a), math.sin(a)), rng:NextInteger(3, 5))
	end
	-- Frame: pillars, lintel, braziers.
	for _, x in { -21, 21 } do
		P({ Name = "Pillar", Size = Vector3.new(4.5, 36, 4.5), CFrame = face * CFrame.new(x, 18, 0),
			Material = Enum.Material.Slate, Color = opts.FrameColor, Parent = wall })
		local bf = floorBelow((face * CFrame.new(x * 0.62, 6, -7)).Position, 20)
		if bf then
			P({ Name = "BrazierStand", Size = Vector3.new(1.4, 3.4, 1.4), CFrame = CFrame.new(bf + Vector3.new(0, 1.7, 0)),
				Material = Enum.Material.Metal, Color = IRON, Parent = wall })
			local bowl = P({ Name = "Brazier", Size = Vector3.new(2.6, 0.8, 2.6), CFrame = CFrame.new(bf + Vector3.new(0, 3.6, 0)),
				Material = Enum.Material.Metal, Color = Color3.fromRGB(50, 46, 44), Parent = wall })
			local fire = Instance.new("Fire")
			fire.Size = 3
			fire.Heat = 7
			fire.Color = opts.FireColor
			fire.SecondaryColor = opts.FireColor2
			fire.Parent = bowl
			local light = Instance.new("PointLight")
			light.Range = 22
			light.Brightness = 1
			light.Color = opts.FireColor
			light.Shadows = true
			light.Parent = bowl
		end
	end
	P({ Name = "Lintel", Size = Vector3.new(48, 4, 5), CFrame = face * CFrame.new(0, 34, 0),
		Material = Enum.Material.Slate, Color = opts.FrameColor, Parent = wall })
	local wallSign = sign(wall, face * CFrame.new(0, 34, -2.6), Vector3.new(20, 3, 0.3), opts.Title:upper(), opts.CrackColor)
	wallSign:FindFirstChildOfClass("SurfaceGui").LightInfluence = 0.15
	-- Invisible seal so nothing slips past the blocks.
	local blocker = P({ Name = "Blocker", Size = Vector3.new(46, 40, 4), CFrame = face * CFrame.new(0, 18, 0.5),
		Transparency = 1, Parent = wall })
	wall.PrimaryPart = blocker
	local promptPart = invisible("PromptPart", face * CFrame.new(0, 4, -5), Vector3.new(1, 1, 1), wall)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "AscendPrompt"
	prompt.ActionText = "Ascend"
	prompt.ObjectText = opts.Title
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 1.2
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptPart
	-- Where the camera frames the wall during the ascension sequence.
	invisible("CameraPoint", face * CFrame.new(0, 15, -26), Vector3.new(1, 1, 1), wall)
	-- Faint glow from the runes; the ascension sequence brightens it.
	local glow = invisible("RuneGlow", face * CFrame.new(0, 14, -4), Vector3.new(1, 1, 1), runes)
	local glowLight = Instance.new("PointLight")
	glowLight.Name = "Glow"
	glowLight.Color = opts.RuneColor
	glowLight.Range = 26
	glowLight.Brightness = 0.6
	glowLight.Parent = glow
	wall:SetAttribute("MineId", opts.MineId)
	CollectionService:AddTag(wall, "AscensionWall")
	return wall
end

-- Portal ring behind an ascension wall. opts = { X, Z, ProbeY, FromMine, ToMine }
local function buildPortal(mine, opts)
	local portal = folder("Portal", mine, "Model")
	local floor = floorBelow(Vector3.new(opts.X, opts.ProbeY, opts.Z + 2), 30) or Vector3.new(opts.X, opts.ProbeY - 12, opts.Z)
	local c = CFrame.new(opts.X, floor.Y + 7, opts.Z)
	for i = 1, 14 do
		local a = i / 14 * math.pi * 2
		P({ Name = "RingStone", Size = Vector3.new(2.2, 2.6, 2.4),
			CFrame = c * CFrame.new(math.cos(a) * 7, math.sin(a) * 7, 0) * CFrame.Angles(0, 0, a),
			Material = Enum.Material.Slate, Color = Color3.fromRGB(60, 58, 70), Parent = portal })
	end
	local disk = P({ Name = "Disk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 12.5, 12.5),
		CFrame = c * CFrame.Angles(0, math.rad(90), 0), Material = Enum.Material.Neon,
		Color = Color3.fromRGB(130, 100, 255), Transparency = 0.3, CanCollide = false, Parent = portal })
	local light = Instance.new("PointLight")
	light.Range = 30
	light.Brightness = 2
	light.Color = Color3.fromRGB(150, 120, 255)
	light.Parent = disk
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(Color3.fromRGB(190, 170, 255))
	sparkle.LightEmission = 1
	sparkle.Size = NumberSequence.new(0.4, 0)
	sparkle.Lifetime = NumberRange.new(1, 2)
	sparkle.Rate = 18
	sparkle.Speed = NumberRange.new(1, 3)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Parent = disk
	local trigger = P({ Name = "PortalTrigger", Size = Vector3.new(11, 12, 3), CFrame = c,
		Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = true, Parent = portal })
	trigger:SetAttribute("FromMine", opts.FromMine)
	trigger:SetAttribute("ToMine", opts.ToMine)
	return portal
end

local minesFolder -- created by world.luau after cleanup
local buildReport = {}

-- A lift cage: platform, corner posts, a cable up into the ceiling, a prompt
-- and an Arrival point. `floorPos` is where the platform sits; the cage opens
-- towards `facing`.
local function liftCage(parent, name, floorPos, facing, actionText, objectText)
	local model = folder(name, parent, "Model")
	local cf = CFrame.lookAt(floorPos, floorPos + Vector3.new(facing.X, 0, facing.Z))
	P({ Name = "Platform", Size = Vector3.new(8, 0.6, 8), CFrame = cf * CFrame.new(0, 0.3, 0),
		Material = Enum.Material.DiamondPlate, Color = Color3.fromRGB(80, 80, 84), Parent = model })
	for _, x in { -3.7, 3.7 } do
		for _, z in { -3.7, 3.7 } do
			P({ Name = "Post", Size = Vector3.new(0.6, 11, 0.6), CFrame = cf * CFrame.new(x, 5.8, z),
				Material = Enum.Material.Metal, Color = IRON, Parent = model })
		end
	end
	P({ Name = "Roof", Size = Vector3.new(8, 0.5, 8), CFrame = cf * CFrame.new(0, 11.4, 0),
		Material = Enum.Material.DiamondPlate, Color = Color3.fromRGB(70, 70, 74), Parent = model })
	-- side and back mesh walls
	for _, side in { { CFrame.new(-3.85, 4, 0), Vector3.new(0.15, 7, 7.4) }, { CFrame.new(3.85, 4, 0), Vector3.new(0.15, 7, 7.4) },
		{ CFrame.new(0, 4, 3.85), Vector3.new(7.4, 7, 0.15) } } do
		P({ Name = "Mesh", Size = side[2], CFrame = cf * side[1], Material = Enum.Material.DiamondPlate,
			Color = Color3.fromRGB(60, 60, 64), Transparency = 0.35, Parent = model })
	end
	local cableTop = ceilingAbove(floorPos + Vector3.new(0, 12, 0), 200)
	local cableLen = if cableTop then cableTop.Y - (floorPos.Y + 11.6) else 30
	P({ Name = "Cable", Size = Vector3.new(0.3, cableLen, 0.3), CFrame = cf * CFrame.new(0, 11.6 + cableLen / 2, 0),
		Material = Enum.Material.Metal, Color = Color3.fromRGB(40, 40, 42), CanCollide = false, Parent = model })
	lantern(model, (cf * CFrame.new(0, 11.1, -3)).Position, 0.3)
	local promptPart = invisible("PromptPart", cf * CFrame.new(0, 3, 0), Vector3.new(1, 1, 1), model)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LiftPrompt"
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptPart
	-- Players arrive standing just outside the cage, facing out.
	invisible("Arrival", cf * CFrame.new(0, 3.2, -6.5), Vector3.new(1, 1, 1), model)
	CollectionService:AddTag(model, "LiftStop")
	return model
end

----------------------------------------------------------------------------
-- hazards and lava
----------------------------------------------------------------------------

-- Invisible box that hurts players without enough protection (HazardService).
local function hazardVolume(parent, hazardType, level, dps, cf, size)
	local v = invisible("Hazard_" .. hazardType, cf, size, parent)
	v:SetAttribute("Type", hazardType)
	v:SetAttribute("Level", level)
	v:SetAttribute("DamagePerSecond", dps)
	CollectionService:AddTag(v, "Hazard")
	return v
end

local LAVA = Color3.fromRGB(255, 104, 24)

local function lavaSurface(parent, cf, size, withLight, withEmbers)
	local lava = P({ Name = "Lava", Size = size, CFrame = cf, Material = Enum.Material.Neon, Color = LAVA,
		Transparency = 0.05, CanCollide = false, CanQuery = false, CastShadow = false, Parent = parent })
	if withLight then
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 120, 40)
		light.Range = 22
		light.Brightness = 1.6
		light.Parent = lava
	end
	if withEmbers then
		local embers = Instance.new("ParticleEmitter")
		embers.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		embers.Color = ColorSequence.new(Color3.fromRGB(255, 170, 60), Color3.fromRGB(255, 60, 10))
		embers.LightEmission = 1
		embers.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
		embers.Lifetime = NumberRange.new(1.2, 2.4)
		embers.Rate = 6
		embers.Speed = NumberRange.new(2, 5)
		embers.Acceleration = Vector3.new(0, 2, 0)
		embers.SpreadAngle = Vector2.new(25, 25)
		embers.EmissionDirection = Enum.NormalId.Top
		embers.Parent = lava
	end
	return lava
end

-- A lava river in a carved trench along `points` (floor height F). Adds the
-- Lava hazard over it. Returns sample points along the river for keep-clear.
local function lavaRiver(parent, points, F)
	local river = folder("LavaRiver", parent)
	local samples = {}
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local steps = math.ceil((b - a).Magnitude / 2)
		for s = 0, steps do
			local p = a:Lerp(b, s / steps)
			T:FillBall(Vector3.new(p.X, F - 2.5, p.Z), 5, AIR)
		end
	end
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local mid = (a + b) / 2
		local len = (b - a).Magnitude
		local cf = CFrame.lookAt(Vector3.new(mid.X, F - 4.5, mid.Z), Vector3.new(b.X, F - 4.5, b.Z))
		lavaSurface(river, cf, Vector3.new(8.5, 1, len + 2), i % 3 == 1, i % 2 == 0)
		hazardVolume(river, "Lava", 99, 45, cf * CFrame.new(0, 1.5, 0), Vector3.new(9, 5, len + 2))
		table.insert(samples, Vector3.new(mid.X, F, mid.Z))
	end
	return samples
end

-- A round lava pool sunk into the floor at `center` (floor height F).
local function lavaPool(parent, center, radius, F)
	T:FillBall(Vector3.new(center.X, F - radius * 0.6, center.Z), radius, AIR)
	local cf = CFrame.new(center.X, F - 2.5, center.Z) * CFrame.Angles(0, 0, math.rad(90))
	lavaSurface(parent, cf, Vector3.new(1, radius * 1.9, radius * 1.9), true, true).Shape = Enum.PartType.Cylinder
	hazardVolume(parent, "Lava", 99, 45, CFrame.new(center.X, F - 1, center.Z), Vector3.new(radius * 1.7, 5, radius * 1.7))
end

-- Stone slab bridge across a river from `a` to `b` at floor height F.
local function bridge(parent, a, b, F)
	local mid = (a + b) / 2
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt(Vector3.new(mid.X, F - 0.3, mid.Z), Vector3.new(b.X, F - 0.3, b.Z))
	P({ Name = "Bridge", Size = Vector3.new(6, 1.4, len), CFrame = cf, Material = Enum.Material.Basalt,
		Color = Color3.fromRGB(52, 44, 42), Parent = parent })
	for _, x in { -3.2, 3.2 } do
		P({ Name = "Rail", Size = Vector3.new(0.5, 1.4, len), CFrame = cf * CFrame.new(x, 1.3, 0), Material = Enum.Material.Basalt,
			Color = Color3.fromRGB(40, 34, 32), Parent = parent })
	end
end

----------------------------------------------------------------------------
-- artifacts and ancient mechanisms
----------------------------------------------------------------------------

-- Require a clone: the plugin context caches modules, so requiring the
-- original would return a stale copy after `studio.py sync` updates it.
local ArtifactDefs = require(game:GetService("ReplicatedStorage").Shared.Config.Artifacts:Clone())

-- Builds the small glowing object for an artifact around `cf`.
local function artifactItem(model, def, cf)
	local item = folder("Item", model, "Model")
	local c = def.Color
	local function part(name, size, offset, props)
		local p = P({ Name = name, Size = size, CFrame = cf * offset, Material = Enum.Material.Neon, Color = c,
			CanCollide = false, CanQuery = false, CastShadow = false, Parent = item })
		for k, v in props or {} do
			p[k] = v
		end
		return p
	end
	local core
	if def.Shape == "Lantern" then
		core = part("Glass", Vector3.new(0.8, 1.1, 0.8), CFrame.new())
		part("Cap", Vector3.new(1, 0.25, 1), CFrame.new(0, 0.7, 0), { Material = Enum.Material.Metal, Color = IRON })
		part("Base", Vector3.new(1, 0.2, 1), CFrame.new(0, -0.65, 0), { Material = Enum.Material.Metal, Color = IRON })
	elseif def.Shape == "Heart" then
		core = part("Core", Vector3.new(1.4, 1.4, 1.4), CFrame.new(), { Shape = Enum.PartType.Ball, Material = Enum.Material.Glass, Transparency = 0.2 })
		part("Glow", Vector3.new(0.7, 0.7, 0.7), CFrame.new(), { Shape = Enum.PartType.Ball })
	elseif def.Shape == "Crown" then
		core = part("Band", Vector3.new(0.5, 1.6, 1.6), CFrame.Angles(0, 0, math.rad(90)), { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Foil, Color = Color3.fromRGB(200, 120, 50) })
		for i = 1, 6 do
			local a = i / 6 * math.pi * 2
			part("Spike", Vector3.new(0.25, 0.6, 0.25), CFrame.new(math.cos(a) * 0.7, 0.45, math.sin(a) * 0.7))
		end
	elseif def.Shape == "Tablet" then
		core = part("Stone", Vector3.new(1.6, 2, 0.3), CFrame.new(), { Material = Enum.Material.Slate, Color = Color3.fromRGB(70, 74, 90) })
		for i = 1, 5 do
			part("Star", Vector3.new(0.15, 0.15, 0.1), CFrame.new(-0.5 + i * 0.18, (i % 3) * 0.4 - 0.3, -0.18))
		end
	elseif def.Shape == "Mask" then
		core = part("Face", Vector3.new(1.4, 1.8, 0.5), CFrame.new(), { Material = Enum.Material.Foil })
		for _, x in { -0.32, 0.32 } do
			part("Eye", Vector3.new(0.3, 0.18, 0.1), CFrame.new(x, 0.25, -0.28), { Color = Color3.fromRGB(70, 200, 130) })
		end
	elseif def.Shape == "Book" then
		core = part("Cover", Vector3.new(1.4, 0.35, 1.8), CFrame.new(), { Material = Enum.Material.Foil })
		part("Pages", Vector3.new(1.3, 0.25, 1.7), CFrame.new(0.05, 0, 0), { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(230, 220, 190) })
	else -- Disk
		core = part("Disk", Vector3.new(0.3, 2, 2), CFrame.Angles(0, math.rad(90), 0), { Shape = Enum.PartType.Cylinder })
		for i = 1, 8 do
			local a = i / 8 * math.pi * 2
			part("Ray", Vector3.new(0.2, 0.7, 0.1), CFrame.new(math.cos(a) * 1.25, math.sin(a) * 1.25, 0) * CFrame.Angles(0, 0, a - math.pi / 2))
		end
	end
	item.PrimaryPart = core
	return item, core
end

-- Stone pedestal with a floating artifact and a "Take" prompt.
local function artifactPedestal(parent, artifactId, floorPos)
	local def = ArtifactDefs.Get(artifactId)
	assert(def, "unknown artifact " .. tostring(artifactId))
	local model = folder("Artifact_" .. artifactId, parent, "Model")
	P({ Name = "Pedestal", Size = Vector3.new(2.4, 3, 2.4), CFrame = CFrame.new(floorPos + Vector3.new(0, 1.5, 0)),
		Material = Enum.Material.Sandstone, Color = Color3.fromRGB(190, 176, 140), Parent = model })
	P({ Name = "PedestalTop", Size = Vector3.new(3, 0.4, 3), CFrame = CFrame.new(floorPos + Vector3.new(0, 3.2, 0)),
		Material = Enum.Material.Sandstone, Color = Color3.fromRGB(176, 160, 124), Parent = model })
	local _, core = artifactItem(model, def, CFrame.new(floorPos + Vector3.new(0, 4.6, 0)))
	local light = Instance.new("PointLight")
	light.Color = def.Color
	light.Range = 14
	light.Brightness = 1.4
	light.Parent = core
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(def.Color)
	sparkle.LightEmission = 1
	sparkle.Size = NumberSequence.new(0.3, 0)
	sparkle.Lifetime = NumberRange.new(0.8, 1.6)
	sparkle.Rate = 8
	sparkle.Speed = NumberRange.new(0.5, 1.5)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Parent = core
	local promptPart = invisible("PromptPart", CFrame.new(floorPos + Vector3.new(0, 4, 0)), Vector3.new(1, 1, 1), model)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Take"
	prompt.ObjectText = def.Name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0.6
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptPart
	model:SetAttribute("ArtifactId", artifactId)
	CollectionService:AddTag(model, "Artifact")
	return model
end

-- A stone stele with a sun glyph that players press (MechanismService).
local function glyphStele(parent, glyphId, door, floorPos, facing)
	local model = folder("Glyph_" .. glyphId, parent, "Model")
	local cf = CFrame.lookAt(floorPos, floorPos + Vector3.new(facing.X, 0, facing.Z))
	P({ Name = "Stele", Size = Vector3.new(3.4, 6.5, 1.2), CFrame = cf * CFrame.new(0, 3.25, 0),
		Material = Enum.Material.Sandstone, Color = Color3.fromRGB(176, 164, 132), Parent = model })
	local sun = P({ Name = "Sun", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, 2.2, 2.2),
		CFrame = cf * CFrame.new(0, 4.2, -0.65) * CFrame.Angles(0, math.rad(90), 0), Material = Enum.Material.Slate,
		Color = Color3.fromRGB(80, 70, 50), CanCollide = false, Parent = model })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 210, 110)
	light.Range = 18
	light.Brightness = 1.6
	light.Enabled = false
	light.Parent = sun
	local promptPart = invisible("PromptPart", cf * CFrame.new(0, 3.5, -1.2), Vector3.new(1, 1, 1), model)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Press"
	prompt.ObjectText = "Sun Glyph"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptPart
	model:SetAttribute("GlyphId", glyphId)
	model:SetAttribute("Door", door)
	CollectionService:AddTag(model, "Glyph")
	return model
end
