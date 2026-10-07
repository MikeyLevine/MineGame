--!strict
-- The Mining Drill, client side. Holding the tool sends one DrillRequest per
-- tick at the same target the pickaxe would pick. The bit spins, a motor
-- loop plays and a heat bar shows how close the drill is to overheating
-- (heat itself is server-authoritative, mirrored via player attributes).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Equipment = require(Shared.Config.Equipment)
local Remotes = require(Shared.Remotes)
local Sounds = require(Shared.Config.Sounds)

local StateController = require(script.Parent.StateController)
local MiningController = require(script.Parent.MiningController)
local EffectsController = require(script.Parent.EffectsController)
local SoundController = require(script.Parent.SoundController)
local Toasts = require(script.Parent.Parent.UI.Toasts)
local Theme = require(script.Parent.Parent.UI.Theme)

local DrillController = {}

local player = Players.LocalPlayer

local equipped: Tool? = nil
local holding = false
local looping = false
local spin = 0
local motorSound: Sound? = nil

local heatGui: ScreenGui
local heatFill: Frame
local heatLabel: TextLabel

local function drillConfig(): Equipment.Drill?
	local state = StateController.State
	return if state and state.DrillTier > 0 then Equipment.Drills[state.DrillTier] else nil
end

local function setMotor(on: boolean)
	if on and not motorSound and equipped then
		local handle = equipped:FindFirstChild("Handle")
		local s = Instance.new("Sound")
		s.SoundId = Sounds.DrillLoop.Id
		s.Volume = Sounds.DrillLoop.Volume
		s.PlaybackSpeed = Sounds.DrillLoop.Speed or 1
		s.Looped = true
		s.SoundGroup = SoundController.SfxGroup
		s.RollOffMaxDistance = 60
		s.Parent = handle or equipped
		s:Play()
		motorSound = s
	elseif not on and motorSound then
		motorSound:Destroy()
		motorSound = nil
	end
end

local function renderHeat()
	local heat = (player:GetAttribute("DrillHeat") :: number?) or 0
	local overheated = player:GetAttribute("DrillOverheated") == true
	TweenService:Create(heatFill, TweenInfo.new(0.1), { Size = UDim2.fromScale(math.clamp(heat / 100, 0, 1), 1) }):Play()
	heatFill.BackgroundColor3 = if overheated then Theme.Colors.Bad
		else Color3.fromRGB(255, 200, 70):Lerp(Color3.fromRGB(255, 90, 40), heat / 100)
	heatLabel.Text = if overheated then "OVERHEATED - COOLING" else "DRILL HEAT"
end

local function tickLoop()
	if looping then
		return
	end
	looping = true
	local tickCount = 0
	while holding and equipped and equipped.Parent == player.Character do
		local drill = drillConfig()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not drill or not root then
			break
		end
		if player:GetAttribute("DrillOverheated") then
			setMotor(false)
			task.wait(0.1)
			continue
		end
		setMotor(true)
		local model, kind = MiningController.FindTarget(root)
		if model then
			MiningController.LookAt(root, MiningController.CenterOf(model))
			Remotes.Event("DrillRequest"):FireServer(model)
			tickCount += 1
			local point = MiningController.ImpactPoint(root, model)
			local _, color, material = MiningController.Describe(model, kind)
			if tickCount % 3 == 0 then
				EffectsController:Hit(model, point, color, material)
			end
		end
		task.wait(drill.Tick)
	end
	setMotor(false)
	looping = false
end

local function bind(tool: Tool)
	equipped = tool
	heatGui.Enabled = true
	renderHeat()
	tool.Activated:Connect(function()
		holding = true
		task.spawn(tickLoop)
	end)
	tool.Deactivated:Connect(function()
		holding = false
	end)
	tool.Unequipped:Connect(function()
		holding = false
		if equipped == tool then
			equipped = nil
			heatGui.Enabled = false
			setMotor(false)
		end
	end)
end

local function onCharacter(character: Model)
	holding = false
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child.Name == "Drill" then
			bind(child)
		end
	end)
end

function DrillController:Init()
	heatGui = Theme.Screen("DrillHeat", 12)
	heatGui.Enabled = false
	-- Sits to the right of the backpack bar so pickup popups don't cover it.
	local frame = Theme.Panel({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0.5, 180, 1, -89),
		Size = UDim2.fromOffset(200, 30),
	})
	frame.Parent = heatGui
	local track = Instance.new("Frame")
	track.BackgroundColor3 = Theme.Colors.PanelLight
	track.BorderSizePixel = 0
	track.Position = UDim2.fromOffset(5, 5)
	track.Size = UDim2.new(1, -10, 1, -10)
	Theme.Corner(track, 6)
	track.Parent = frame
	heatFill = Instance.new("Frame")
	heatFill.BorderSizePixel = 0
	heatFill.Size = UDim2.fromScale(0, 1)
	Theme.Corner(heatFill, 6)
	heatFill.Parent = track
	heatLabel = Theme.Label({
		Text = "DRILL HEAT",
		TextSize = 14,
		FontFace = Theme.FontHeavy,
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 2,
	})
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1.2
	stroke.Transparency = 0.4
	stroke.Parent = heatLabel
	heatLabel.Parent = track
	heatGui.Parent = player:WaitForChild("PlayerGui")

	player:GetAttributeChangedSignal("DrillHeat"):Connect(renderHeat)
	player:GetAttributeChangedSignal("DrillOverheated"):Connect(function()
		renderHeat()
		if player:GetAttribute("DrillOverheated") and equipped then
			SoundController:Play("DrillOverheat")
			Toasts:Notify("Drill overheated! Give it a moment to cool.", "Warn")
			local handle = equipped:FindFirstChild("Handle") :: BasePart?
			if handle then
				EffectsController:Break(handle.Position, Color3.fromRGB(200, 200, 200), Enum.Material.Metal, 0.4)
			end
		end
	end)

	-- Spin the bit while drilling.
	RunService.RenderStepped:Connect(function(dt)
		if not (holding and equipped and motorSound) then
			return
		end
		local handle = equipped:FindFirstChild("Handle")
		local weld = handle and handle:FindFirstChild("BitWeld") :: Weld?
		if weld then
			spin = (spin + dt * 45) % (math.pi * 2)
			weld.C0 = CFrame.new(0, 0, -1.85) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(spin, 0, 0)
		end
	end)

	if player.Character then
		onCharacter(player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
end

return DrillController
