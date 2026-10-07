--!strict
-- Gives each character its equipment: the pickaxe Tool for their tier, the
-- drill Tool once owned, and the lamp (headlamp + belt lantern). Rebuilds
-- whatever changed when the player's tiers change.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Equipment = require(Shared.Config.Equipment)
local Skins = require(Shared.Config.Skins)

local DataService = require(script.Parent.DataService)

local ToolService = {}

local givenTier: { [Player]: number } = {}
local givenSkin: { [Player]: string } = {}
local givenDrill: { [Player]: number } = {}
local givenLamp: { [Player]: number } = {}

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

local function buildPickaxe(tier: number, skinId: string?): Tool
	local base = Equipment.Pickaxes[tier] or Equipment.Pickaxes[1]
	-- A skin only changes the look; tier stats are untouched.
	local skin = skinId and skinId ~= "Classic" and Skins.Get(skinId)
	local config = {
		Name = base.Name,
		HeadColor = if skin then skin.HeadColor else base.HeadColor,
		HeadMaterial = if skin then skin.HeadMaterial else base.HeadMaterial,
		Glow = if skin then skin.Glow else base.Glow,
	}
	local handleColor = if skin then skin.HandleColor else Color3.fromRGB(110, 76, 48)
	local tool = Instance.new("Tool")
	tool.Name = "Pickaxe"
	tool.ToolTip = config.Name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("Tier", tier)
	-- Handle runs along Z with the head at -Z. Hold it near the +Z end, handle
	-- upright (grip up = -Z) and the head's spikes pointing forward.
	tool.Grip = CFrame.fromMatrix(Vector3.new(0, 0, 1.2), Vector3.new(-1, 0, 0), Vector3.new(0, 0, -1))

	local handle = part({
		Name = "Handle",
		Size = Vector3.new(0.28, 0.28, 3.6),
		Material = Enum.Material.Wood,
		Color = handleColor,
	})
	handle.Parent = tool

	local headCF = handle.CFrame * CFrame.new(0, 0, -1.65)
	local head = part({
		Name = "Head",
		Size = Vector3.new(0.4, 2.8, 0.45),
		CFrame = headCF,
		Material = config.HeadMaterial,
		Color = config.HeadColor,
	})
	head.Parent = tool
	weld(handle, head)

	for _, dir in { 1, -1 } do
		local tip = Instance.new("WedgePart")
		tip.Name = "Tip"
		tip.CanCollide = false
		tip.CanTouch = false
		tip.CanQuery = false
		tip.Massless = true
		tip.Size = Vector3.new(0.4, 0.6, 0.45)
		tip.CFrame = headCF * CFrame.new(0, dir * 1.7, 0) * CFrame.Angles(if dir == 1 then 0 else math.pi, 0, 0)
		tip.Material = config.HeadMaterial
		tip.Color = config.HeadColor
		tip.Parent = tool
		weld(handle, tip)
	end

	local wrap = part({
		Name = "Wrap",
		Size = Vector3.new(0.34, 0.34, 0.8),
		CFrame = handle.CFrame * CFrame.new(0, 0, 1.2),
		Material = Enum.Material.Fabric,
		Color = Color3.fromRGB(60, 44, 34),
	})
	wrap.Parent = tool
	weld(handle, wrap)

	if skin and skin.Trail then
		-- Swing trail between the two spikes of the head.
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 1.6, 0)
		a0.Parent = head
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -1.6, 0)
		a1.Parent = head
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Color = ColorSequence.new(skin.Trail)
		trail.LightEmission = 1
		trail.Lifetime = 0.25
		trail.MinLength = 0.05
		trail.Transparency = NumberSequence.new(0.2, 1)
		trail.FaceCamera = true
		trail.Parent = head
	end
	tool:SetAttribute("Skin", if skin then skin.Id else "Classic")
	if config.Glow then
		local light = Instance.new("PointLight")
		light.Color = config.HeadColor
		light.Range = 8
		light.Brightness = 1.2
		light.Parent = head
	end

	return tool
end

-- Builds the drill: yellow body, side grip and a spinning bit. The bit is
-- attached with a Weld (not WeldConstraint) so the client can spin it.
local function buildDrill(tier: number): Tool
	local config = Equipment.Drills[tier] or Equipment.Drills[1]
	local tool = Instance.new("Tool")
	tool.Name = "Drill"
	tool.ToolTip = config.Name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("Tier", tier)
	-- Body runs along Z with the bit at -Z, held pointing forward.
	tool.Grip = CFrame.new(0, -0.35, 0.5)

	local handle = part({
		Name = "Handle",
		Size = Vector3.new(0.8, 1, 2.2),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(226, 178, 40),
	})
	handle.Parent = tool

	local motor = part({
		Name = "Motor",
		Size = Vector3.new(1, 1.1, 1),
		CFrame = handle.CFrame * CFrame.new(0, 0.1, 0.7),
		Material = Enum.Material.DiamondPlate,
		Color = Color3.fromRGB(60, 60, 64),
	})
	motor.Parent = tool
	weld(handle, motor)

	local grip = part({
		Name = "SideGrip",
		Size = Vector3.new(0.3, 0.9, 0.3),
		CFrame = handle.CFrame * CFrame.new(-0.6, -0.4, -0.2),
		Material = Enum.Material.Fabric,
		Color = Color3.fromRGB(40, 36, 34),
	})
	grip.Parent = tool
	weld(handle, grip)

	local bit = part({
		Name = "Bit",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.6, 0.5, 0.5),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(150, 150, 160),
	})
	local bitWeld = Instance.new("Weld")
	bitWeld.Name = "BitWeld"
	bitWeld.Part0 = handle
	bitWeld.Part1 = bit
	bitWeld.C0 = CFrame.new(0, 0, -1.85) * CFrame.Angles(0, math.rad(90), 0)
	bitWeld.Parent = handle
	bit.Parent = tool
	for i = 1, 3 do
		local flute = part({
			Name = "Flute",
			Size = Vector3.new(0.18, 0.62, 0.18),
			CFrame = bit.CFrame * CFrame.new(-0.6 + i * 0.35, 0, 0) * CFrame.Angles(i * 1.2, 0, 0),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(110, 110, 120),
		})
		flute.Parent = tool
		weld(bit, flute)
	end
	return tool
end

-- Replaces a named tool in the player's backpack/character, keeping it
-- equipped if it was.
local function giveTool(player: Player, name: string, tool: Tool?)
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not character or not backpack then
		return
	end
	local wasEquipped = character:FindFirstChild(name) ~= nil
	for _, container in { backpack, character } do
		local old = container:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	if not tool then
		return
	end
	tool.Parent = backpack
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if wasEquipped and humanoid then
		humanoid:EquipTool(tool)
	end
end

local function equipTool(player: Player)
	local data = DataService:Get(player)
	if not data then
		return
	end
	givenTier[player] = data.PickaxeTier
	givenSkin[player] = data.EquippedSkin
	giveTool(player, "Pickaxe", buildPickaxe(data.PickaxeTier, data.EquippedSkin))
end

local function equipDrill(player: Player)
	local data = DataService:Get(player)
	if not data then
		return
	end
	givenDrill[player] = data.DrillTier
	giveTool(player, "Drill", if data.DrillTier > 0 then buildDrill(data.DrillTier) else nil)
end

-- Headlamp spotlight + glow on the head, and a lantern on the belt from
-- the Miner's Lantern upward.
local function applyLamp(player: Player)
	local data = DataService:Get(player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if not data or not character or not head then
		return
	end
	local lamp = Equipment.Lamps[data.LampTier] or Equipment.Lamps[1]
	givenLamp[player] = data.LampTier

	local spot = head:FindFirstChild("Headlamp") :: SpotLight?
	if not spot then
		spot = Instance.new("SpotLight")
		spot.Name = "Headlamp"
		spot.Face = Enum.NormalId.Front
		spot.Angle = 70
		spot.Shadows = true
		spot.Parent = head
	end
	local glow = head:FindFirstChild("Glow") :: PointLight?
	if not glow then
		glow = Instance.new("PointLight")
		glow.Name = "Glow"
		glow.Parent = head
	end
	local headlamp = spot :: SpotLight
	headlamp.Range = lamp.Range
	headlamp.Brightness = lamp.Brightness
	headlamp.Color = lamp.Color
	local headGlow = glow :: PointLight
	headGlow.Range = lamp.GlowRange
	headGlow.Brightness = lamp.GlowBrightness
	headGlow.Color = lamp.Color

	local old = character:FindFirstChild("HipLantern")
	if old then
		old:Destroy()
	end
	local hip = character:FindFirstChild("LowerTorso") or character:FindFirstChild("Torso")
	if lamp.HipLantern and hip and hip:IsA("BasePart") then
		local lantern = part({
			Name = "HipLantern",
			Size = Vector3.new(0.45, 0.7, 0.45),
			CFrame = hip.CFrame * CFrame.new(1.05, -0.35, 0),
			Material = Enum.Material.Neon,
			Color = lamp.Color,
			CastShadow = false,
		})
		local cap = part({
			Name = "Cap",
			Size = Vector3.new(0.55, 0.12, 0.55),
			CFrame = lantern.CFrame * CFrame.new(0, 0.4, 0),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(60, 58, 56),
		})
		cap.Parent = lantern
		weld(lantern, cap)
		local light = Instance.new("PointLight")
		light.Range = lamp.GlowRange * 0.6
		light.Brightness = lamp.GlowBrightness
		light.Color = lamp.Color
		light.Parent = lantern
		weld(hip, lantern)
		lantern.Parent = character
	end
end

local function onCharacter(player: Player, character: Model)
	character:WaitForChild("Head", 5)
	applyLamp(player)
	equipTool(player)
	equipDrill(player)
end

function ToolService:Init()
	DataService:OnLoaded(function(player)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
		player.CharacterAdded:Connect(function(character)
			-- Backpack is recreated on respawn; wait a frame for it.
			task.defer(onCharacter, player, character)
		end)
	end)
	DataService.Changed:Connect(function(player, data)
		if givenTier[player] ~= data.PickaxeTier or givenSkin[player] ~= data.EquippedSkin then
			equipTool(player)
		end
		if givenDrill[player] ~= data.DrillTier then
			equipDrill(player)
		end
		if givenLamp[player] ~= data.LampTier then
			applyLamp(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		givenTier[player] = nil
		givenDrill[player] = nil
		givenLamp[player] = nil
	end)
end

return ToolService
