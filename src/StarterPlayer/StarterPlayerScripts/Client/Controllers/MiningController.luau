--!strict
-- Turns pickaxe input into swings. Works with mouse, touch and gamepad:
--  * Mouse/touch: the rock under the cursor/tap is targeted if in reach.
--  * Otherwise (and on gamepad): the closest rock in front of the player.
-- Holding the button keeps swinging at the pickaxe's cooldown.
--
-- Effects play immediately on impact for responsiveness; rewards and damage
-- numbers come from the server's MineFeedback.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Mines = require(Shared.Config.Mines)
local Remotes = require(Shared.Remotes)
local Resources = require(Shared.Config.Resources)
local Targets = require(Shared.Util.Targets)

local StateController = require(script.Parent.StateController)
local EffectsController = require(script.Parent.EffectsController)
local SoundController = require(script.Parent.SoundController)
local CameraShake = require(script.Parent.CameraShake)
local Toasts = require(script.Parent.Parent.UI.Toasts)
local Theme = require(script.Parent.Parent.UI.Theme)

local MiningController = {}

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local REACH = GameConfig.MineRange - 0.75
-- Effects land on the down-stroke of the swing.
local function impactDelay(): number
	return math.min(StateController:Pickaxe().Cooldown * 0.9, 0.32) * 0.6
end
local GATE_COLOR = Color3.fromRGB(110, 100, 90)

local equippedTool: Tool? = nil
local holding = false
local looping = false

local healthGui: BillboardGui
local healthFill: Frame
local healthName: TextLabel
local healthHideAt = 0

local function rootPart(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function isGateOpen(model: Instance): boolean
	local state = StateController.State
	local id = model:GetAttribute("GateId")
	return state ~= nil and type(id) == "string" and state.Gates[id] == true
end

local function isValid(model: Instance, kind: string?): boolean
	if not model.Parent then
		return false
	end
	if kind == "Gate" then
		return not isGateOpen(model)
	end
	return true
end

local function centerOf(model: Instance): Vector3
	if model:IsA("Model") then
		return model:GetPivot().Position
	end
	return (model :: BasePart).Position
end

local function findTarget(root: BasePart): (Instance?, string?)
	local m, kind = Targets.Resolve(mouse.Target)
	if m and isValid(m, kind) and Targets.DistanceTo(m, root.Position) <= REACH then
		return m, kind
	end

	local best, bestKind, bestScore = nil, nil, math.huge
	for _, tag in { "Creature", "Ore", "Gate" } do
		for _, candidate in CollectionService:GetTagged(tag) do
			if not isValid(candidate, tag) or not candidate:IsDescendantOf(workspace) then
				continue
			end
			local d = Targets.DistanceTo(candidate, root.Position)
			if d > REACH then
				continue
			end
			local flat = (centerOf(candidate) - root.Position) * Vector3.new(1, 0, 1)
			local facing = if flat.Magnitude > 0.01 then flat.Unit:Dot(root.CFrame.LookVector) else 1
			if facing < -0.1 then
				continue
			end
			local score = d - facing * 5
			if score < bestScore then
				best, bestKind, bestScore = candidate, tag, score
			end
		end
	end
	return best, bestKind
end

local function impactPoint(root: BasePart, model: Instance): Vector3
	local center = centerOf(model)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { model }
	local origin = root.Position + Vector3.new(0, 1.5, 0)
	local hit = workspace:Raycast(origin, (center - origin).Unit * (GameConfig.MineRange + 6), params)
	return if hit then hit.Position else center
end

local function lookAt(root: BasePart, position: Vector3)
	local flat = Vector3.new(position.X, root.Position.Y, position.Z)
	if (flat - root.Position).Magnitude > 0.5 then
		root.CFrame = CFrame.lookAt(root.Position, flat)
	end
end

-- Procedural pickaxe swing: wind up over the head, chop down, recover.
-- Applied to the right shoulder each frame after the Animator has run, so it
-- layers on top of the normal tool-holding pose.
local swingStart = -math.huge
local swingDuration = 0.3
local WINDUP, STRIKE = 0.45, 0.7 -- phase boundaries (fraction of duration)

local function shoulder(): Motor6D?
	local character = player.Character
	if not character then
		return nil
	end
	local upper = character:FindFirstChild("RightUpperArm")
	local motor = upper and upper:FindFirstChild("RightShoulder")
		or (character:FindFirstChild("Torso") and (character :: any).Torso:FindFirstChild("Right Shoulder"))
	return if motor and motor:IsA("Motor6D") then motor else nil
end

local function swingAngle(t: number): number
	-- radians of extra shoulder pitch; positive raises the arm
	if t < WINDUP then
		local k = t / WINDUP
		return 1.5 * (1 - (1 - k) ^ 2)
	elseif t < STRIKE then
		local k = (t - WINDUP) / (STRIKE - WINDUP)
		return 1.5 - 2.3 * k ^ 1.6
	else
		local k = (t - STRIKE) / (1 - STRIKE)
		return -0.8 * (1 - k)
	end
end

RunService.PreSimulation:Connect(function()
	local t = (os.clock() - swingStart) / swingDuration
	if t < 0 or t > 1 then
		return
	end
	local motor = shoulder()
	if motor then
		motor.Transform = motor.Transform * CFrame.Angles(swingAngle(t), 0, 0)
	end
end)

local function playSwingAnimation(_tool: Tool)
	swingDuration = math.min(StateController:Pickaxe().Cooldown * 0.9, 0.32)
	swingStart = os.clock()
end

local function describe(model: Instance, kind: string?): (string, Color3, Enum.Material)
	if kind == "Creature" then
		local eye = model:FindFirstChild("Eye")
		return model.Name, if eye and eye:IsA("BasePart") then eye.Color else Color3.fromRGB(150, 80, 255), Enum.Material.Neon
	end
	if kind == "Gate" then
		return "Rubble", GATE_COLOR, Enum.Material.Slate
	end
	local resource = Resources.Get(model:GetAttribute("ResourceId") :: string)
	if resource then
		return resource.DisplayName, resource.OreColor, resource.OreMaterial
	end
	return "Rock", GATE_COLOR, Enum.Material.Rock
end

local function showHealth(model: Instance, name: string, health: number, maxHealth: number)
	local adornee = if model:IsA("Model") then model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart") else model
	if not adornee then
		return
	end
	healthGui.Adornee = adornee :: BasePart
	healthGui.Enabled = true
	healthName.Text = name
	local ratio = if maxHealth > 0 then math.clamp(health / maxHealth, 0, 1) else 0
	TweenService:Create(healthFill, TweenInfo.new(0.1), { Size = UDim2.fromScale(ratio, 1) }):Play()
	healthHideAt = os.clock() + 2.5
end

-- Returns a reason the swing can't do anything, judged from local state, so
-- we can explain it instantly instead of waiting on the server.
local function localBlocker(model: Instance, kind: string?): string?
	if kind == "Creature" then
		return nil
	end
	local pickaxe = StateController:Pickaxe()
	if kind == "Gate" then
		local gate = Mines.GetGate(model:GetAttribute("GateId") :: string)
		if gate and gate.Mechanism then
			return "This door won't budge. Ancient mechanisms must open it."
		end
		if gate and pickaxe.Hardness < gate.Hardness then
			if gate.Hidden then
				return `This wall sounds hollow... You'll need the {gate.RequiredPickaxeName} to break through.`
			end
			return `The {gate.DisplayName:lower()} is too tough. You need the {gate.RequiredPickaxeName}.`
		end
		return nil
	end
	local resource = Resources.Get(model:GetAttribute("ResourceId") :: string)
	if resource and pickaxe.Hardness < resource.Hardness then
		return `{resource.DisplayName} is too hard for your {pickaxe.Name}. Upgrade at camp!`
	end
	if StateController:Used() >= StateController:Capacity() then
		return "Backpack full! Head back up to camp and sell."
	end
	return nil
end

local function swing()
	local tool = equippedTool
	local root = rootPart()
	if not tool or not root then
		return
	end
	playSwingAnimation(tool)

	local model, kind = findTarget(root)
	if not model then
		return
	end
	lookAt(root, centerOf(model))
	local point = impactPoint(root, model)
	local _, color, material = describe(model, kind)

	local blocker = localBlocker(model, kind)
	if blocker then
		task.delay(impactDelay(), function()
			SoundController:Play("Denied", point)
			Toasts:Notify(blocker, "Warn")
		end)
		return
	end

	Remotes.Event("MineRequest"):FireServer(model)
	task.delay(impactDelay(), function()
		if model.Parent then
			EffectsController:Hit(model, point, color, material)
		end
		CameraShake:Shake(0.12, 0.12)
		SoundController:Play(if kind == "Gate" then "GateHit" else "Hit", point, 0.08)
		local resource = kind == "Ore" and Resources.Get(model:GetAttribute("ResourceId") :: string)
		if resource and resource.Crystal then
			SoundController:Play("CrystalHit", point, 0.12)
		end
	end)
end

local function swingLoop()
	if looping then
		return
	end
	looping = true
	while holding and equippedTool and equippedTool.Parent == player.Character do
		swing()
		task.wait(StateController:Pickaxe().Cooldown)
	end
	looping = false
end

local function onFeedback(payload: { [string]: any })
	if type(payload) ~= "table" then
		return
	end
	if payload.reason == "BackpackFull" then
		Toasts:Notify("Backpack full! Head back up to camp and sell.", "Warn")
		return
	elseif payload.reason == "TooHard" then
		Toasts:Notify(`Too hard! You need the {payload.requirement}.`, "Warn")
		return
	elseif payload.reason == "Mechanism" then
		Toasts:Notify("This door won't budge. Ancient mechanisms must open it.", "Warn")
		return
	elseif payload.reason == "TooDark" then
		Toasts:Notify(`Too dark to work here! You need the {payload.requirement}.`, "Warn")
		return
	end

	local model = payload.target
	local position: Vector3 = payload.position or Vector3.zero
	if payload.kind == "Creature" then
		if payload.broken then
			healthGui.Enabled = false
			EffectsController:Break(position, Color3.fromRGB(160, 80, 255), Enum.Material.Neon, 2.2)
		elseif model then
			showHealth(model, payload.name or "Creature", payload.health, payload.maxHealth)
		end
		return
	end
	if payload.kind == "Gate" then
		if payload.broken then
			healthGui.Enabled = false
			EffectsController:Break(position, GATE_COLOR, Enum.Material.Slate, 2.5)
			SoundController:Play("GateBreak", position)
			CameraShake:Shake(0.9, 0.5)
			if payload.hidden then
				SoundController:Play("HiddenFound")
				Toasts:Banner("HIDDEN CHAMBER", "You found a secret")
			else
				Toasts:Notify(`The {(payload.gateName or "rubble"):lower()} gives way. Deeper tunnels are open!`, "Good")
			end
		elseif model then
			showHealth(model, payload.gateName or "Rubble", payload.health, payload.maxHealth)
		end
		return
	end

	local resource = Resources.Get(payload.resourceId)
	if not resource then
		return
	end
	if payload.broken then
		if not payload.splash then
			healthGui.Enabled = false
		end
		EffectsController:Break(position, resource.OreColor, resource.OreMaterial, if payload.splash then 0.6 else 1)
		if (payload.amount or 0) > 0 then
			EffectsController:Collect(position, resource.OreColor, resource.OreMaterial, math.min(payload.amount + 1, 5))
		end
		if not payload.splash then
			CameraShake:Shake(if payload.rich then 0.5 else 0.25, 0.2)
		end
		SoundController:Play("Break", position, 0.1)
		if (payload.amount or 0) > 0 then
			SoundController:Play("Pickup", nil, 0.1)
			local color = Resources.RarityColors[resource.Rarity] or Theme.Colors.Text
			if payload.rich then
				SoundController:Play("RichFind")
				EffectsController:Break(position, resource.OreColor, resource.OreMaterial, 1.6)
				Toasts:Pickup(`+{payload.amount} {resource.DisplayName}  RICH VEIN!`, Theme.Colors.Cash)
			else
				Toasts:Pickup(`+{payload.amount} {resource.DisplayName}`, color)
			end
		end
	elseif model then
		local name = if payload.rich then `Rich {resource.DisplayName} Vein` else resource.DisplayName
		showHealth(model, name, payload.health, payload.maxHealth)
	end
end

local function buildHealthGui()
	healthGui = Instance.new("BillboardGui")
	healthGui.Name = "OreHealth"
	healthGui.Size = UDim2.fromOffset(150, 40)
	healthGui.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
	healthGui.AlwaysOnTop = true
	healthGui.Enabled = false
	healthGui.ResetOnSpawn = false

	healthName = Theme.Label({
		Text = "",
		TextSize = 16,
		Size = UDim2.new(1, 0, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1.5
	stroke.Transparency = 0.3
	stroke.Parent = healthName
	healthName.Parent = healthGui

	local track = Instance.new("Frame")
	track.BackgroundColor3 = Color3.fromRGB(20, 18, 16)
	track.BackgroundTransparency = 0.2
	track.BorderSizePixel = 0
	track.Position = UDim2.fromOffset(15, 22)
	track.Size = UDim2.new(1, -30, 0, 10)
	Theme.Corner(track, 5)
	track.Parent = healthGui

	healthFill = Instance.new("Frame")
	healthFill.BackgroundColor3 = Theme.Colors.Accent
	healthFill.BorderSizePixel = 0
	healthFill.Size = UDim2.fromScale(1, 1)
	Theme.Corner(healthFill, 5)
	healthFill.Parent = track

	healthGui.Parent = player:WaitForChild("PlayerGui")

	task.spawn(function()
		while true do
			task.wait(0.25)
			if healthGui.Enabled and os.clock() > healthHideAt then
				healthGui.Enabled = false
			end
		end
	end)
end

local function bindTool(tool: Tool)
	equippedTool = tool
	tool.Activated:Connect(function()
		holding = true
		task.spawn(swingLoop)
	end)
	tool.Deactivated:Connect(function()
		holding = false
	end)
	tool.Unequipped:Connect(function()
		holding = false
		if equippedTool == tool then
			equippedTool = nil
		end
	end)
end

local function onCharacter(character: Model)
	holding = false
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child.Name == "Pickaxe" then
			bindTool(child)
		end
	end)
	local existing = character:FindFirstChild("Pickaxe")
	if existing and existing:IsA("Tool") then
		bindTool(existing)
	end
end

-- Shared with the drill so both tools pick targets the same way.
MiningController.FindTarget = findTarget
MiningController.ImpactPoint = impactPoint
MiningController.CenterOf = centerOf
MiningController.LookAt = lookAt
MiningController.Describe = describe
MiningController.ShowHealth = showHealth

function MiningController:Init()
	buildHealthGui()
	Remotes.Event("MineFeedback").OnClientEvent:Connect(onFeedback)
	if player.Character then
		onCharacter(player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
end

return MiningController
