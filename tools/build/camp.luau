-- Surface camp: entrance, spawn, campfire, stations, mine lift, decor.
----------------------------------------------------------------------------
-- surface camp
----------------------------------------------------------------------------

local camp = folder("Camp", workspace)

-- Mine entrance frame.
do
	local entrance = folder("MineEntrance", camp, "Model")
	local z = -32
	local floor = floorBelow(Vector3.new(0, 20, z), 40) or Vector3.new(0, 0, z)
	for _, x in { -6.5, 6.5 } do
		P({ Name = "Post", Size = Vector3.new(1.4, 13, 1.4), CFrame = CFrame.new(x, floor.Y + 6.5, z),
			Material = Enum.Material.Wood, Color = WOOD, Parent = entrance })
	end
	P({ Name = "Lintel", Size = Vector3.new(16, 1.6, 1.8), CFrame = CFrame.new(0, floor.Y + 13.4, z),
		Material = Enum.Material.Wood, Color = DARKWOOD, Parent = entrance })
	sign(entrance, CFrame.new(0, floor.Y + 15.6, z + 1.05) * CFrame.Angles(0, math.pi, 0), Vector3.new(14, 2.8, 0.3),
		"ABANDONED COAL MINE")
	lantern(entrance, Vector3.new(-5, floor.Y + 12.6, z + 1.2), 1)
	lantern(entrance, Vector3.new(5, floor.Y + 12.6, z + 1.2), 1)
end

-- Spawn deck.
local spawnPos = Vector3.new(0, 0, 46)
do
	local deck = P({ Name = "SpawnDeck", Size = Vector3.new(14, 1, 14), CFrame = CFrame.new(spawnPos + Vector3.new(0, 0.3, 0)),
		Material = Enum.Material.WoodPlanks, Color = WOOD, Parent = camp })
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 0.2, 6)
	spawn.CFrame = CFrame.new(spawnPos + Vector3.new(0, 0.9, 0)) * CFrame.Angles(0, math.pi, 0)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = camp
	_ = deck
end

-- Campfire.
do
	local fire = folder("Campfire", camp, "Model")
	local c = Vector3.new(0, 0, 18)
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		P({ Name = "Stone", Size = Vector3.new(1.4, 0.9, 1.4), CFrame = CFrame.new(c + Vector3.new(math.cos(a) * 2.4, 0.3, math.sin(a) * 2.4))
			* CFrame.Angles(0, a, 0), Material = Enum.Material.Slate, Color = Color3.fromRGB(90, 86, 82), Parent = fire })
	end
	for i = 1, 3 do
		P({ Name = "Log", Size = Vector3.new(0.6, 0.6, 3.2), CFrame = CFrame.new(c + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0.35, i * 2.1, 0),
			Material = Enum.Material.Wood, Color = DARKWOOD, CanCollide = false, Parent = fire })
	end
	local core = P({ Name = "Embers", Size = Vector3.new(1.4, 0.4, 1.4), CFrame = CFrame.new(c + Vector3.new(0, 0.4, 0)),
		Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 120, 40), CanCollide = false, Parent = fire })
	local flame = Instance.new("Fire")
	flame.Size = 4
	flame.Heat = 6
	flame.Color = Color3.fromRGB(255, 140, 50)
	flame.SecondaryColor = Color3.fromRGB(255, 60, 20)
	flame.Parent = core
	local light = Instance.new("PointLight")
	light.Range = 24
	light.Brightness = 2
	light.Color = Color3.fromRGB(255, 150, 70)
	light.Shadows = true
	light.Parent = core
end

-- Station builder: counter + sign + prompt.
local function station(name, pos, facing, title, actionText, objectText)
	local model = folder(name, camp, "Model")
	local cf = CFrame.lookAt(pos, pos + facing)
	P({ Name = "Counter", Size = Vector3.new(10, 3.4, 3), CFrame = cf * CFrame.new(0, 1.7, 0),
		Material = Enum.Material.WoodPlanks, Color = WOOD, Parent = model })
	P({ Name = "CounterTop", Size = Vector3.new(10.6, 0.4, 3.6), CFrame = cf * CFrame.new(0, 3.6, 0),
		Material = Enum.Material.Wood, Color = DARKWOOD, Parent = model })
	for _, x in { -5, 5 } do
		P({ Name = "Post", Size = Vector3.new(0.8, 10, 0.8), CFrame = cf * CFrame.new(x, 5, 1.6),
			Material = Enum.Material.Wood, Color = WOOD, Parent = model })
	end
	P({ Name = "Roof", Size = Vector3.new(12, 0.5, 6), CFrame = cf * CFrame.new(0, 10.2, 0.6) * CFrame.Angles(math.rad(-12), 0, 0),
		Material = Enum.Material.WoodPlanks, Color = DARKWOOD, Parent = model })
	sign(model, cf * CFrame.new(0, 8.2, 1.4) * CFrame.Angles(0, 0, 0), Vector3.new(9, 2.2, 0.3), title)
	lantern(model, (cf * CFrame.new(0, 9.6, -0.6)).Position, 0.6)
	local promptPart = P({ Name = "PromptPart", Size = Vector3.new(1, 1, 1), CFrame = cf * CFrame.new(0, 3, -2.2),
		Transparency = 1, CanCollide = false, CanQuery = false, Parent = model })
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptPart
	return model, cf
end

do
	local sell, sellCF = station("SellStation", Vector3.new(-24, 0, 10), Vector3.new(0.6, 0, 1).Unit,
		"ORE BUYER", "Sell Ore", "Ore Buyer")
	mineCart(sell, sellCF * CFrame.new(-7.5, 0, 0) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(150, 110, 70))
	crate(sell, sellCF * CFrame.new(6.8, 1.2, 0.5))
	-- scales on the counter
	P({ Name = "Scale", Size = Vector3.new(1.6, 0.3, 1.6), CFrame = sellCF * CFrame.new(-2, 3.95, 0),
		Material = Enum.Material.Metal, Color = Color3.fromRGB(176, 140, 70), Parent = sell })

	local up, upCF = station("UpgradeStation", Vector3.new(24, 0, 10), Vector3.new(-0.6, 0, 1).Unit,
		"UPGRADE BENCH", "Upgrade Gear", "Upgrade Bench")
	P({ Name = "Anvil", Size = Vector3.new(2.6, 1.4, 1.2), CFrame = upCF * CFrame.new(-7.2, 2.6, 0),
		Material = Enum.Material.Metal, Color = Color3.fromRGB(50, 50, 54), Parent = up })
	P({ Name = "AnvilStand", Size = Vector3.new(1.6, 1.9, 1), CFrame = upCF * CFrame.new(-7.2, 0.95, 0),
		Material = Enum.Material.Wood, Color = DARKWOOD, Parent = up })
	for i, x in { -3, 0, 3 } do
		-- pickaxes on display
		local base = upCF * CFrame.new(x, 4.6, 1.2)
		P({ Name = "DisplayHandle", Size = Vector3.new(0.25, 2.6, 0.25), CFrame = base * CFrame.Angles(0, 0, 0.3),
			Material = Enum.Material.Wood, Color = WOOD, CanCollide = false, Parent = up })
		P({ Name = "DisplayHead", Size = Vector3.new(2, 0.35, 0.35), CFrame = base * CFrame.Angles(0, 0, 0.3) * CFrame.new(0, 1.2, 0),
			Material = Enum.Material.Metal, Color = ({ Color3.fromRGB(128, 126, 120), Color3.fromRGB(170, 170, 176), Color3.fromRGB(90, 110, 130) })[i],
			CanCollide = false, Parent = up })
	end
end

-- Tents, crates and lamp posts around camp.
do
	local deco = folder("Decor", camp)
	local function tent(pos, yaw, color)
		local m = folder("Tent", deco, "Model")
		local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
		-- Two wedges back to back make an A-frame; tall faces meet at the ridge.
		for _, side in { -1, 1 } do
			P({ Class = "WedgePart", Name = "Canvas", Size = Vector3.new(8, 5, 3.2),
				CFrame = cf * CFrame.new(0, 2.5, side * 1.6) * CFrame.Angles(0, if side == 1 then math.pi else 0, 0),
				Material = Enum.Material.Fabric, Color = color, Parent = m })
		end
		P({ Name = "Ridge", Size = Vector3.new(8.6, 0.4, 0.4), CFrame = cf * CFrame.new(0, 5.05, 0),
			Material = Enum.Material.Wood, Color = DARKWOOD, Parent = m })
	end
	tent(Vector3.new(-30, 0, 42), 0.4, Color3.fromRGB(150, 130, 96))
	tent(Vector3.new(32, 0, 44), -0.5, Color3.fromRGB(120, 112, 90))
	crate(deco, CFrame.new(-36, 1.2, 30) * CFrame.Angles(0, 0.4, 0))
	crate(deco, CFrame.new(-34, 1.2, 33) * CFrame.Angles(0, 1.1, 0))
	crate(deco, CFrame.new(-35, 3.4, 31.4) * CFrame.Angles(0, 0.7, 0), 2)
	barrel(deco, Vector3.new(36, 0, 28))
	barrel(deco, Vector3.new(38.5, 0, 30))
	for _, pos in { Vector3.new(-6, 0, -14), Vector3.new(6, 0, -14), Vector3.new(-6, 0, 6), Vector3.new(6, 0, 30) } do
		P({ Name = "LampPost", Size = Vector3.new(0.6, 8, 0.6), CFrame = CFrame.new(pos + Vector3.new(0, 4, 0)),
			Material = Enum.Material.Wood, Color = WOOD, Parent = deco })
		P({ Name = "Arm", Size = Vector3.new(0.4, 0.4, 2), CFrame = CFrame.new(pos + Vector3.new(0, 7.8, 0.8)),
			Material = Enum.Material.Wood, Color = WOOD, Parent = deco })
		lantern(deco, pos + Vector3.new(0, 7.6, 1.6), 0.4)
	end
	sign(deco, CFrame.lookAt(Vector3.new(4, 4, 24), Vector3.new(4, 4, 34)), Vector3.new(6, 2, 0.2), "MINE  ↑")
	P({ Name = "SignPost", Size = Vector3.new(0.4, 4, 0.4), CFrame = CFrame.new(4, 2, 24), Material = Enum.Material.Wood,
		Color = WOOD, Parent = deco })
end


-- Mine lift: a timber headframe over a cage. The cage prompt opens the
-- destination picker; players riding up from a mine arrive here.
do
	local pos = Vector3.new(-17, 0, -12)
	local facing = Vector3.new(1, 0, 0.35).Unit
	local floor = floorBelow(pos + Vector3.new(0, 20, 0), 40) or pos
	local cage = liftCage(camp, "MineLift", floor, facing, "Take the Lift", "Mine Lift")
	cage:SetAttribute("LiftId", "Camp")
	local cable = cage:FindFirstChild("Cable")
	if cable then
		cable:Destroy()
	end
	local cf = CFrame.lookAt(floor, floor + facing)
	for _, x in { -5.5, 5.5 } do
		P({ Name = "HeadframeLeg", Size = Vector3.new(1.2, 24, 1.2), CFrame = cf * CFrame.new(x, 12, 0) * CFrame.Angles(0, 0, x > 0 and 0.08 or -0.08),
			Material = Enum.Material.Wood, Color = WOOD, Parent = cage })
	end
	P({ Name = "HeadframeBeam", Size = Vector3.new(12, 1.2, 1.4), CFrame = cf * CFrame.new(0, 23.4, 0),
		Material = Enum.Material.Wood, Color = DARKWOOD, Parent = cage })
	P({ Name = "Wheel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 5, 5), CFrame = cf * CFrame.new(0, 24.6, 0) * CFrame.Angles(0, math.rad(90), 0),
		Material = Enum.Material.Metal, Color = IRON, Parent = cage })
	P({ Name = "Cable", Size = Vector3.new(0.3, 11, 0.3), CFrame = cf * CFrame.new(0, 17.4, 0),
		Material = Enum.Material.Metal, Color = Color3.fromRGB(40, 40, 42), CanCollide = false, Parent = cage })
	sign(cage, cf * CFrame.new(0, 13.5, -4.2), Vector3.new(7, 1.6, 0.25), "MINE LIFT")
end

-- Prestige monument: a dark obelisk with a glowing crack that opens the
-- prestige dialog (usable after completing the final mine).
do
	local model = folder("PrestigeMonument", camp, "Model")
	local base = Vector3.new(-48, 0, 6)
	local floor = floorBelow(base + Vector3.new(0, 20, 0), 40) or base
	P({ Name = "Plinth", Size = Vector3.new(7, 1.2, 7), CFrame = CFrame.new(floor + Vector3.new(0, 0.6, 0)),
		Material = Enum.Material.Slate, Color = Color3.fromRGB(50, 46, 56), Parent = model })
	-- Faces +X, toward the camp.
	local obelisk = P({ Name = "Obelisk", Size = Vector3.new(3.4, 12, 3.4),
		CFrame = CFrame.lookAt(floor + Vector3.new(0, 7.2, 0), floor + Vector3.new(10, 7.2, 0)),
		Material = Enum.Material.Slate, Color = Color3.fromRGB(34, 28, 44), Parent = model })
	P({ Name = "Cap", Size = Vector3.new(2.4, 1.6, 2.4), CFrame = obelisk.CFrame * CFrame.new(0, 6.8, 0),
		Material = Enum.Material.Slate, Color = Color3.fromRGB(34, 28, 44), Parent = model })
	P({ Name = "Tip", Size = Vector3.new(1.2, 1.2, 1.2), CFrame = obelisk.CFrame * CFrame.new(0, 8.1, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		Material = Enum.Material.Neon, Color = Color3.fromRGB(170, 90, 255), CanCollide = false, Parent = model })
	local crack = P({ Name = "Crack", Size = Vector3.new(0.4, 9, 0.3), CFrame = obelisk.CFrame * CFrame.new(0, 0, -1.72),
		Material = Enum.Material.Neon, Color = Color3.fromRGB(170, 90, 255), CanCollide = false, Parent = model })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(170, 90, 255)
	light.Range = 14
	light.Brightness = 1.2
	light.Parent = crack
	sign(model, CFrame.lookAt(floor + Vector3.new(4.6, 2.2, 0), floor + Vector3.new(10, 2.2, 0)), Vector3.new(5, 1.4, 0.2),
		"THE DEEP CALLS", Color3.fromRGB(210, 180, 255))
	local promptPart = invisible("PromptPart", CFrame.new(floor + Vector3.new(0, 3, 0)), Vector3.new(1, 1, 1), model)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Collapse the Mines"
	prompt.ObjectText = "Prestige"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptPart
end

-- Pet Nursery: a fenced pen with a big egg on a straw nest. Its prompt opens
-- the pets window on the Eggs tab (PetService); hatching requires being here.
do
	local model = folder("PetNursery", camp, "Model")
	local base = Vector3.new(-50, 0, 30)
	local floor = floorBelow(base + Vector3.new(0, 20, 0), 40) or base
	-- Local -Z (forward) faces the camp centre (+X); the open side and the sign face it.
	local center = CFrame.lookAt(floor, floor + Vector3.new(10, 0, 0))
	P({ Name = "Straw", Size = Vector3.new(12, 0.4, 12), CFrame = center * CFrame.new(0, 0.2, 0), Material = Enum.Material.Fabric,
		Color = Color3.fromRGB(200, 170, 100), Parent = model })
	-- Low fence on the back and both sides, open towards camp.
	for _, side in { { 0, 6, 12, 0 }, { -6, 0, 0.4, 12 }, { 6, 0, 0.4, 12 } } do
		local x, z, w, d = side[1], side[2], side[3], side[4]
		local along = if w > 1 then Vector3.new(1, 0, 0) else Vector3.new(0, 0, 1)
		local length = math.max(w, d)
		for i = 0, 3 do
			local t = -length / 2 + i * length / 3
			P({ Name = "FencePost", Size = Vector3.new(0.5, 3, 0.5), CFrame = center * CFrame.new(Vector3.new(x, 1.5, z) + along * t),
				Material = Enum.Material.Wood, Color = WOOD, Parent = model })
		end
		P({ Name = "FenceRail", Size = if w > 1 then Vector3.new(length, 0.35, 0.3) else Vector3.new(0.3, 0.35, length),
			CFrame = center * CFrame.new(x, 2.4, z), Material = Enum.Material.Wood, Color = WOOD, Parent = model })
	end
	-- The big egg.
	local egg = P({ Name = "BigEgg", Shape = Enum.PartType.Ball, Size = Vector3.new(4.4, 5.6, 4.4), CFrame = center * CFrame.new(0, 3, 0),
		Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(240, 226, 196), Parent = model })
	for i = 1, 7 do
		local a = i / 7 * math.pi * 2
		P({ Name = "Spot", Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.9, 0.9),
			CFrame = egg.CFrame * CFrame.new(math.cos(a) * 2.05, (i % 3 - 1) * 1.2, math.sin(a) * 2.05), Material = Enum.Material.SmoothPlastic,
			Color = Color3.fromRGB(150, 110, 70), CanCollide = false, Parent = model })
	end
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		P({ Name = "Nest", Size = Vector3.new(2.2, 0.8, 0.9), CFrame = center * CFrame.new(math.cos(a) * 2.4, 0.7, math.sin(a) * 2.4)
			* CFrame.Angles(0, -a, 0.3), Material = Enum.Material.Fabric, Color = Color3.fromRGB(170, 140, 80), Parent = model })
	end
	sign(model, center * CFrame.new(0, 5.4, 5.6), Vector3.new(7, 1.6, 0.25), "PET NURSERY", Color3.fromRGB(255, 220, 150))
	for _, x in { -3.2, 3.2 } do
		P({ Name = "SignPost", Size = Vector3.new(0.5, 6, 0.5), CFrame = center * CFrame.new(x, 3, 5.8), Material = Enum.Material.Wood,
			Color = WOOD, Parent = model })
	end
	local promptPart = invisible("PromptPart", center * CFrame.new(0, 2.5, -3), Vector3.new(1, 1, 1), model)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Hatch Eggs"
	prompt.ObjectText = "Pet Nursery"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptPart
end

-- Leaderboard board (deepest Abyss divers / most prestiges), filled in by
-- LeaderboardService, with the group-reward plaque under it. Mirrors the
-- prestige obelisk on the other side of camp and faces the camp centre.
do
	local model = folder("Leaderboard", camp, "Model")
	local base = Vector3.new(48, 0, 8)
	local floor = floorBelow(base + Vector3.new(0, 20, 0), 40) or base
	local face = CFrame.lookAt(floor + Vector3.new(0, 9, 0), floor + Vector3.new(-10, 9, 0))
	for _, x in { -8.8, 8.8 } do
		P({ Name = "Post", Size = Vector3.new(0.9, 17, 0.9), CFrame = face * CFrame.new(x, -2, 0.4),
			Material = Enum.Material.Wood, Color = WOOD, Parent = model })
	end
	P({ Name = "Frame", Size = Vector3.new(17.8, 10.8, 0.5), CFrame = face * CFrame.new(0, 0, 0.45),
		Material = Enum.Material.WoodPlanks, Color = DARKWOOD, Parent = model })
	P({ Name = "Roof", Size = Vector3.new(19.6, 0.6, 2.6), CFrame = face * CFrame.new(0, 6.6, 0),
		Material = Enum.Material.WoodPlanks, Color = WOOD, Parent = model })
	local screen = P({ Name = "Screen", Size = Vector3.new(16.6, 9.6, 0.2), CFrame = face * CFrame.new(0, 0, 0.12),
		Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(24, 21, 19), CanCollide = false, Parent = model })
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Board"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Brightness = 1.2
	gui.Parent = screen
	lantern(model, (face * CFrame.new(-7.6, 6.2, -0.9)).Position, 0.4)
	lantern(model, (face * CFrame.new(7.6, 6.2, -0.9)).Position, 0.4)

	local plaque = sign(model, face * CFrame.new(0, -6.6, 0.1), Vector3.new(8, 1.6, 0.25), "GROUP REWARD", Color3.fromRGB(255, 208, 92))
	plaque.Name = "GroupPlaque"
	local promptPart = invisible("GroupPromptPart", face * CFrame.new(0, -6.6, -1.5), Vector3.new(1, 1, 1), model)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GroupPrompt"
	prompt.ActionText = "Claim Group Reward"
	prompt.ObjectText = "Join our Roblox group"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptPart
end

return table.concat(buildReport, " | ")
