--!strict
-- Draws every player's equipped pets (player attribute "EquippedPets", set
-- by the server) as small floating models that follow behind them. Purely
-- visual and local to this client: smooth movement with no network cost.
-- Pets of players far from the camera aren't drawn.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Pets = require(ReplicatedStorage:WaitForChild("Shared").Config.Pets)

local PetController = {}

local DRAW_DISTANCE = 220
-- Follow offsets in the owner's local space (behind is +Z).
local SLOTS = { Vector3.new(-3.2, 2.4, 3.6), Vector3.new(3.2, 2.4, 3.6), Vector3.new(0, 3.6, 5.4) }

type Drawn = { Model: Model, Body: BasePart, Flaps: { { Part: BasePart, Offset: CFrame, Side: number } }, Phase: number }

local container: Folder
local drawn: { [Player]: { ids: string, pets: { Drawn } } } = {}

local function part(model: Model, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = model
	return p
end

-- Builds a pet at the origin (facing -Z); returns the model, its body and any flapping parts.
function PetController.Build(pet: Pets.Pet): (Model, BasePart, { { Part: BasePart, Offset: CFrame, Side: number } })
	local model = Instance.new("Model")
	model.Name = pet.Id
	local flaps = {}
	local origin = CFrame.new()
	local bodySize = Vector3.new(1.9, 1.7, 1.9)
	local bodyShape = Enum.PartType.Ball
	local material = Enum.Material.SmoothPlastic
	if pet.Shape == "Golem" then
		bodySize, bodyShape = Vector3.new(1.9, 1.9, 1.6), Enum.PartType.Block
		material = Enum.Material.Slate
	elseif pet.Shape == "Bug" then
		bodySize = Vector3.new(1.4, 1.2, 1.6)
	elseif pet.Shape == "Crystal" then
		bodySize, bodyShape = Vector3.new(1.5, 1.5, 1.5), Enum.PartType.Block
		material = Enum.Material.Glass
	elseif pet.Shape == "Bat" then
		bodySize = Vector3.new(1.5, 1.4, 1.5)
	end
	local body = part(model, { Name = "Body", Shape = bodyShape, Size = bodySize, CFrame = if pet.Shape == "Crystal"
		then origin * CFrame.Angles(math.rad(45), 0, math.rad(45)) else origin, Material = material, Color = pet.Body })
	if pet.Shape == "Wisp" then
		body.Material = Enum.Material.Neon
		body.Transparency = 0.25
		body.Color = pet.Accent:Lerp(pet.Body, 0.4)
	end
	model.PrimaryPart = body

	-- Eyes on the front.
	local eyeZ = -(bodySize.Z / 2) + 0.05
	for _, x in { -0.38, 0.38 } do
		part(model, { Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.5, 0.3), CFrame = origin * CFrame.new(x, 0.25, eyeZ),
			Material = Enum.Material.SmoothPlastic, Color = Color3.new(1, 1, 1) })
		part(model, { Name = "Pupil", Shape = Enum.PartType.Ball, Size = Vector3.new(0.26, 0.26, 0.2), CFrame = origin * CFrame.new(x, 0.22, eyeZ - 0.14),
			Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(20, 16, 24) })
	end

	if pet.Shape == "Blob" then
		for _, x in { -0.55, 0.55 } do
			part(model, { Name = "Ear", Shape = Enum.PartType.Ball, Size = Vector3.new(0.6, 0.6, 0.6), CFrame = origin * CFrame.new(x, 0.85, 0.1),
				Material = Enum.Material.SmoothPlastic, Color = pet.Accent })
		end
	elseif pet.Shape == "Bat" then
		for _, side in { -1, 1 } do
			local offset = CFrame.new(side * 0.75, 0.2, 0.1)
			local wing = part(model, { Name = "Wing", Size = Vector3.new(1.8, 0.12, 1.1), CFrame = origin * offset * CFrame.new(side * 0.9, 0, 0),
				Material = Enum.Material.SmoothPlastic, Color = pet.Accent })
			table.insert(flaps, { Part = wing :: BasePart, Offset = offset, Side = side })
		end
	elseif pet.Shape == "Bug" then
		part(model, { Name = "Abdomen", Shape = Enum.PartType.Ball, Size = Vector3.new(1.1, 1.0, 1.2), CFrame = origin * CFrame.new(0, -0.1, 1.1),
			Material = Enum.Material.Neon, Color = pet.Accent })
		for _, x in { -0.3, 0.3 } do
			part(model, { Name = "Antenna", Size = Vector3.new(0.08, 0.8, 0.08), CFrame = origin * CFrame.new(x, 0.9, -0.4) * CFrame.Angles(-0.4, 0, x),
				Material = Enum.Material.SmoothPlastic, Color = pet.Body })
		end
	elseif pet.Shape == "Golem" then
		part(model, { Name = "Rune", Size = Vector3.new(1.5, 0.25, 0.05), CFrame = origin * CFrame.new(0, -0.45, -0.81),
			Material = Enum.Material.Neon, Color = pet.Accent })
	elseif pet.Shape == "Crystal" then
		body.Transparency = 0.2
		part(model, { Name = "Core", Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 0.8, 0.8), CFrame = origin,
			Material = Enum.Material.Neon, Color = pet.Accent })
	end

	if pet.Glow then
		local light = Instance.new("PointLight")
		light.Color = pet.Accent
		light.Range = 8
		light.Brightness = 0.8
		light.Shadows = false
		light.Parent = body
	end
	if pet.Rarity == "Legendary" then
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkle.Color = ColorSequence.new(pet.Accent)
		sparkle.LightEmission = 1
		sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
		sparkle.Lifetime = NumberRange.new(0.5, 1)
		sparkle.Rate = 6
		sparkle.Speed = NumberRange.new(0.5, 1.5)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		sparkle.Parent = body
	end
	return model, body, flaps
end

local function clear(player: Player)
	local entry = drawn[player]
	if entry then
		for _, d in entry.pets do
			d.Model:Destroy()
		end
	end
	drawn[player] = nil
end

local function rebuild(player: Player, ids: string)
	clear(player)
	local pets = {}
	for i, id in string.split(ids, ",") do
		local def = Pets.Get(id)
		if def and i <= #SLOTS then
			local model, body, flaps = PetController.Build(def)
			model.Parent = container
			table.insert(pets, { Model = model, Body = body, Flaps = flaps, Phase = i * 1.7 })
		end
	end
	drawn[player] = { ids = ids, pets = pets }
end

local function step(dt: number)
	local camera = workspace.CurrentCamera
	local camPos = camera and camera.CFrame.Position or Vector3.zero
	local t = os.clock()
	local alpha = 1 - math.exp(-dt * 8)
	for _, player in Players:GetPlayers() do
		local ids = (player:GetAttribute("EquippedPets") :: string?) or ""
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local visible = ids ~= "" and root ~= nil and (root.Position - camPos).Magnitude <= DRAW_DISTANCE
		local entry = drawn[player]
		if not visible then
			if entry then
				clear(player)
			end
			continue
		end
		if not entry or entry.ids ~= ids then
			rebuild(player, ids)
			entry = drawn[player]
		end
		local base = (root :: BasePart).CFrame
		local flat = CFrame.lookAt(base.Position, base.Position + base.LookVector * Vector3.new(1, 0, 1) + Vector3.new(0, 0, 0.001))
		for i, d in (entry :: any).pets do
			local bob = math.sin(t * 3 + d.Phase) * 0.35
			local target = flat * CFrame.new(SLOTS[i] + Vector3.new(0, bob, 0))
			local current = d.Model:GetPivot()
			-- Snap when far (teleports), glide otherwise.
			local nextCf = if (current.Position - target.Position).Magnitude > 40 then target else current:Lerp(target, alpha)
			d.Model:PivotTo(nextCf)
			for _, flap in d.Flaps do
				local angle = math.sin(t * 14 + d.Phase) * 0.6 * flap.Side
				flap.Part.CFrame = nextCf * flap.Offset * CFrame.Angles(0, 0, angle) * CFrame.new(flap.Side * 0.9, 0, 0)
			end
		end
	end
end

function PetController:Init()
	container = Instance.new("Folder")
	container.Name = "ClientPets"
	container.Parent = workspace
	Players.PlayerRemoving:Connect(clear)
	RunService.RenderStepped:Connect(step)
end

return PetController
