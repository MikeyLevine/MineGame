--!strict
-- Purely visual feedback for mining: dust/spark bursts, flying rock chips,
-- a white flash and a squash on the struck rock. Client-only, nothing here
-- affects gameplay.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Skins = require(ReplicatedStorage:WaitForChild("Shared").Config.Skins)
local StateController = require(script.Parent.StateController)

local EffectsController = {}

local DUST = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

local rng = Random.new()
local DEFAULT_SPARK = Color3.fromRGB(255, 220, 160)

-- The equipped pickaxe skin may tint the hit sparks.
local function sparkColor(): Color3
	local state = StateController.State
	local skin = state and Skins.Get(state.EquippedSkin or "Classic")
	return skin and skin.Spark or DEFAULT_SPARK
end

local function emitterAt(position: Vector3, lifetime: number): Attachment
	local a = Instance.new("Attachment")
	a.WorldPosition = position
	a.Parent = workspace.Terrain
	Debris:AddItem(a, lifetime)
	return a
end

local function burst(position: Vector3, color: Color3, amount: number, big: boolean)
	local a = emitterAt(position, 2.5)

	local dust = Instance.new("ParticleEmitter")
	dust.Texture = DUST
	dust.Color = ColorSequence.new(color:Lerp(Color3.fromRGB(150, 140, 125), 0.5))
	dust.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, if big then 1.4 else 0.7),
		NumberSequenceKeypoint.new(1, if big then 3.2 else 1.6),
	})
	dust.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	dust.Lifetime = NumberRange.new(0.5, 1.1)
	dust.Speed = NumberRange.new(4, if big then 12 else 7)
	dust.SpreadAngle = Vector2.new(180, 180)
	dust.Drag = 4
	dust.Rate = 0
	dust.LightInfluence = 1
	dust.Parent = a
	dust:Emit(amount)

	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = SPARK
	sparks.Color = ColorSequence.new(sparkColor())
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.25, 0)
	sparks.Lifetime = NumberRange.new(0.15, 0.35)
	sparks.Speed = NumberRange.new(12, 22)
	sparks.SpreadAngle = Vector2.new(70, 70)
	sparks.Acceleration = Vector3.new(0, -40, 0)
	sparks.Rate = 0
	sparks.Parent = a
	sparks:Emit(if big then 14 else 6)
end

local function chips(position: Vector3, color: Color3, material: Enum.Material, count: number)
	for _ = 1, count do
		local chip = Instance.new("Part")
		local s = rng:NextNumber(0.25, 0.55)
		chip.Size = Vector3.new(s, s, s)
		chip.CFrame = CFrame.new(position) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0)
		chip.Color = color
		chip.Material = material
		chip.CanCollide = true
		chip.CanQuery = false
		chip.CanTouch = false
		chip.CastShadow = false
		chip.CollisionGroup = "Default"
		chip.Parent = workspace
		chip.AssemblyLinearVelocity = Vector3.new(rng:NextNumber(-12, 12), rng:NextNumber(10, 22), rng:NextNumber(-12, 12))
		chip.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-20, 20), rng:NextNumber(-20, 20), rng:NextNumber(-20, 20))
		task.delay(1.1, function()
			if chip.Parent then
				TweenService:Create(chip, TweenInfo.new(0.4), { Transparency = 1, Size = chip.Size * 0.3 }):Play()
			end
		end)
		Debris:AddItem(chip, 1.6)
	end
end

local function flash(model: Instance)
	local h = Instance.new("Highlight")
	h.FillColor = Color3.new(1, 1, 1)
	h.FillTransparency = 0.55
	h.OutlineTransparency = 1
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = model
	TweenService:Create(h, TweenInfo.new(0.18), { FillTransparency = 1 }):Play()
	Debris:AddItem(h, 0.25)
end

local squashing: { [Instance]: boolean } = {}
local function squash(model: Instance)
	if not model:IsA("Model") or squashing[model] then
		return
	end
	squashing[model] = true
	local original = model:GetScale()
	model:ScaleTo(original * 0.93)
	task.delay(0.07, function()
		if model.Parent then
			model:ScaleTo(original)
		end
		squashing[model] = nil
	end)
end

-- Small hit: called immediately when the swing lands, before the server replies.
function EffectsController:Hit(model: Instance, position: Vector3, color: Color3, material: Enum.Material)
	burst(position, color, 6, false)
	chips(position, color, material, 3)
	flash(model)
	squash(model)
end

-- Ore chunks arc from the broken rock into the player, as if picked up.
function EffectsController:Collect(position: Vector3, color: Color3, material: Enum.Material, count: number)
	local character = game:GetService("Players").LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	for i = 1, count do
		task.delay(0.05 * i, function()
			local chunk = Instance.new("Part")
			chunk.Size = Vector3.new(0.6, 0.6, 0.6)
			chunk.Color = color
			chunk.Material = material
			chunk.Anchored = true
			chunk.CanCollide = false
			chunk.CanQuery = false
			chunk.CanTouch = false
			chunk.CastShadow = false
			local start = position + Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.5, 1.5), rng:NextNumber(-1, 1))
			chunk.CFrame = CFrame.new(start)
			chunk.Parent = workspace
			local duration = 0.4
			local t0 = os.clock()
			local conn
			conn = game:GetService("RunService").RenderStepped:Connect(function()
				local k = math.clamp((os.clock() - t0) / duration, 0, 1)
				local target = if root.Parent then root.Position else start
				local p = start:Lerp(target, k * k) + Vector3.new(0, math.sin(k * math.pi) * 3, 0)
				chunk.CFrame = CFrame.new(p) * CFrame.Angles(k * 8, k * 6, 0)
				chunk.Size = Vector3.new(0.6, 0.6, 0.6) * (1 - k * 0.7)
				if k >= 1 then
					conn:Disconnect()
					chunk:Destroy()
				end
			end)
		end)
	end
end

-- Big burst when a node or gate breaks.
function EffectsController:Break(position: Vector3, color: Color3, material: Enum.Material, size: number?)
	local scale = size or 1
	burst(position, color, math.floor(16 * scale), true)
	chips(position, color, material, math.floor(9 * scale))
end

return EffectsController
