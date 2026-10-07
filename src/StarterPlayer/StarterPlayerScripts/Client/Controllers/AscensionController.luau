--!strict
-- The Sealed Wall, client side: hides walls of mines this player completed,
-- and plays the breaking sequence when the server confirms an ascension:
-- camera frames the wall, it rumbles and cracks, then blows apart.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Mines = require(Shared.Config.Mines)
local Remotes = require(Shared.Remotes)

local StateController = require(script.Parent.StateController)
local SoundController = require(script.Parent.SoundController)
local EffectsController = require(script.Parent.EffectsController)
local TravelController = require(script.Parent.TravelController)
local Toasts = require(script.Parent.Parent.UI.Toasts)
local LocalSnapshot = require(script.Parent.Parent.Util.LocalSnapshot)

local AscensionController = {}

local player = Players.LocalPlayer
local opened: { [Instance]: boolean } = {}
local playing = false

local CRACK_TIME = 3.2
local BLAST_COLOR = Color3.fromRGB(110, 106, 124)

local function wallFor(mineId: string): Model?
	for _, wall in CollectionService:GetTagged("AscensionWall") do
		if wall:GetAttribute("MineId") == mineId and wall:IsA("Model") then
			return wall
		end
	end
	return nil
end

local function sealParts(wall: Instance): { BasePart }
	local parts = {}
	for _, name in { "Blocks", "Runes", "Cracks" } do
		local f = wall:FindFirstChild(name)
		if f then
			for _, p in f:GetChildren() do
				if p:IsA("BasePart") then
					table.insert(parts, p)
				end
			end
		end
	end
	return parts
end

local function setPrompt(wall: Instance, enabled: boolean)
	local prompt = wall:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		prompt.Enabled = enabled
	end
end

-- Instantly open a wall (already completed when we joined).
local function openInstant(wall: Instance)
	if opened[wall] then
		return
	end
	opened[wall] = true
	LocalSnapshot.Save(wall)
	for _, p in sealParts(wall) do
		p.Transparency = 1
		p.CanCollide = false
		p.CanQuery = false
	end
	local blocker = wall:FindFirstChild("Blocker")
	if blocker and blocker:IsA("BasePart") then
		blocker.CanCollide = false
	end
	setPrompt(wall, false)
end

local function shakeCamera(camera: Camera, base: CFrame, duration: number, maxAmp: number): RBXScriptConnection
	local start = os.clock()
	return RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - start) / duration, 0, 1)
		local amp = maxAmp * t * t
		camera.CFrame = base * CFrame.new(
			(math.random() - 0.5) * amp,
			(math.random() - 0.5) * amp,
			0
		) * CFrame.Angles(0, 0, (math.random() - 0.5) * amp * 0.02)
	end)
end

local function playSequence(wall: Model, mineId: string)
	if playing or opened[wall] then
		return
	end
	playing = true
	LocalSnapshot.Save(wall)
	setPrompt(wall, false)

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local camera = workspace.CurrentCamera
	local blocker = wall:FindFirstChild("Blocker") :: BasePart?
	local camPoint = wall:FindFirstChild("CameraPoint") :: BasePart?
	local center = if blocker then blocker.Position else wall:GetPivot().Position

	local savedSpeed, savedJump = 16, 7.2
	if humanoid then
		savedSpeed, savedJump = humanoid.WalkSpeed, humanoid.JumpHeight
		humanoid.WalkSpeed = 0
		humanoid.JumpHeight = 0
	end

	-- Frame the wall.
	camera.CameraType = Enum.CameraType.Scriptable
	local shot = CFrame.lookAt(if camPoint then camPoint.Position else center + Vector3.new(0, 6, 30), center)
	TweenService:Create(camera, TweenInfo.new(1.2, Enum.EasingStyle.Sine), { CFrame = shot }):Play()
	task.wait(1.2)

	-- Rumble, runes ignite, cracks spread.
	SoundController:Play("AscendRumble", center)
	local shake = shakeCamera(camera, shot, CRACK_TIME, 1.4)
	local runes = wall:FindFirstChild("Runes")
	if runes then
		local glow = runes:FindFirstChild("Glow", true)
		if glow and glow:IsA("PointLight") then
			TweenService:Create(glow, TweenInfo.new(CRACK_TIME), { Brightness = 3, Range = 40 }):Play()
		end
		for _, r in runes:GetChildren() do
			if r:IsA("BasePart") then
				TweenService:Create(r, TweenInfo.new(CRACK_TIME), { Transparency = 0, Color = Color3.fromRGB(210, 180, 255) }):Play()
			end
		end
	end
	local cracks = wall:FindFirstChild("Cracks")
	local crackList = if cracks then cracks:GetChildren() else {}
	for i, c in crackList do
		if c:IsA("BasePart") then
			task.delay((i / #crackList) * (CRACK_TIME - 0.4), function()
				TweenService:Create(c, TweenInfo.new(0.25), { Transparency = 0 }):Play()
				if i % 4 == 0 then
					EffectsController:Break(c.Position, BLAST_COLOR, Enum.Material.Slate, 0.35)
				end
			end)
		end
	end
	task.wait(CRACK_TIME)
	shake:Disconnect()

	-- Blast.
	TravelController:Flash(Color3.fromRGB(230, 215, 255), 1.1)
	SoundController:Play("AscendBlast", center)
	local facing = if blocker then -blocker.CFrame.LookVector else Vector3.zAxis
	for _, p in sealParts(wall) do
		p.CanCollide = false
		p.CanQuery = false
		local push = facing * math.random(6, 16) + Vector3.new((math.random() - 0.5) * 10, math.random(-6, 3), 0)
		local spin = CFrame.Angles(math.random() * 2, math.random() * 2, math.random() * 2)
		TweenService:Create(p, TweenInfo.new(0.9 + math.random() * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = (p.CFrame + push) * spin,
			Transparency = 1,
		}):Play()
	end
	if blocker then
		blocker.CanCollide = false
	end
	for _ = 1, 6 do
		local offset = Vector3.new((math.random() - 0.5) * 30, (math.random() - 0.3) * 24, 0)
		EffectsController:Break(center + offset, BLAST_COLOR, Enum.Material.Slate, 2.5)
	end
	opened[wall] = true
	local afterShake = shakeCamera(camera, shot, 0.6, 0.8)
	task.wait(0.6)
	afterShake:Disconnect()
	task.wait(0.8)

	local mine = Mines.ById[mineId]
	SoundController:Play("MineComplete")
	Toasts:Banner("MINE COMPLETE", if mine then mine.DisplayName else nil)
	task.wait(2.2)

	camera.CameraType = Enum.CameraType.Custom
	if humanoid then
		humanoid.WalkSpeed = savedSpeed
		humanoid.JumpHeight = savedJump
	end
	if mine and mine.Ending then
		Toasts:Notify("The way to the Heart of the Deep is open.", "Good")
	else
		Toasts:Notify("The way is open. Step into the portal to go deeper.", "Good")
	end
	playing = false
end

local function sync()
	local state = StateController.State
	if not state or playing then
		return
	end
	for _, wall in CollectionService:GetTagged("AscensionWall") do
		local mineId = wall:GetAttribute("MineId")
		local mineState = type(mineId) == "string" and state.Mines[mineId]
		if mineState and mineState.Completed then
			openInstant(wall)
		end
	end
end

function AscensionController:Init()
	-- Only open walls instantly for completions we didn't just watch happen.
	StateController:Observe(function(state, previous)
		if previous == nil then
			sync()
		end
		-- Progress reset (prestige): re-seal walls of mines no longer completed.
		if playing then
			return
		end
		for wall in opened do
			local mineId = wall:GetAttribute("MineId")
			local mineState = type(mineId) == "string" and state.Mines[mineId]
			if not (mineState and mineState.Completed) then
				opened[wall] = nil
				LocalSnapshot.Restore(wall)
			end
		end
	end)
	CollectionService:GetInstanceAddedSignal("AscensionWall"):Connect(sync)
	Remotes.Event("Ascended").OnClientEvent:Connect(function(mineId: string)
		local wall = wallFor(mineId)
		if wall then
			task.spawn(playSequence, wall, mineId)
		end
	end)
end

return AscensionController
