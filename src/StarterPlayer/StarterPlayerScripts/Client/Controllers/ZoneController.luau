--!strict
-- Tracks which mine/zone the player is in (see Shared.Util.ZoneLocator) to:
--  * show an area banner the first time a zone is entered this session
--  * crossfade surface/cave ambience
--  * switch lighting: sunlit surface vs. each mine's own cave mood

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Mines = require(Shared.Config.Mines)
local ZoneLocator = require(Shared.Util.ZoneLocator)

local Equipment = require(Shared.Config.Equipment)
local SoundController = require(script.Parent.SoundController)
local StateController = require(script.Parent.StateController)
local Toasts = require(script.Parent.Parent.UI.Toasts)

local ZoneController = {}
ZoneController.Current = nil :: string?
ZoneController.CurrentMine = nil :: string?
ZoneController.InDark = false

local seen: { [string]: boolean } = {}

local SURFACE = {
	Lighting = {
		Brightness = 2.4,
		Ambient = Color3.fromRGB(16, 14, 13),
		OutdoorAmbient = Color3.fromRGB(118, 110, 104),
		EnvironmentDiffuseScale = 0.25,
		EnvironmentSpecularScale = 0.4,
		ExposureCompensation = 0.1,
	},
	Atmosphere = { Density = 0.32, Haze = 1.6, Glare = 0.2, Color = Color3.fromRGB(214, 190, 160), Decay = Color3.fromRGB(110, 90, 76) },
}

-- Underground the sky can't reach you. Sun/sky are zeroed rather than relying
-- on shadows: on low graphics quality (and many phones) shadows are off and
-- the sun would light the caves. Lanterns, crystals and the headlamp do the work.
local function cavePreset(mineId: string)
	local mine = Mines.ById[mineId]
	local lighting = mine and mine.Lighting
	return {
		Lighting = {
			Brightness = 0,
			Ambient = if lighting then lighting.Ambient else Color3.fromRGB(14, 12, 11),
			OutdoorAmbient = Color3.fromRGB(0, 0, 0),
			EnvironmentDiffuseScale = 0,
			EnvironmentSpecularScale = 0,
			ExposureCompensation = 0,
		},
		Atmosphere = {
			Density = 0.42,
			Haze = 0,
			Glare = 0,
			Color = if lighting then lighting.AtmosphereColor else Color3.fromRGB(26, 22, 20),
			Decay = if lighting then lighting.AtmosphereDecay else Color3.fromRGB(12, 10, 9),
		},
	}
end

-- Pitch-black areas: no ambient at all, thick black fog. Only lamps help.
local DARK = {
	Lighting = {
		Brightness = 0,
		Ambient = Color3.fromRGB(2, 2, 3),
		OutdoorAmbient = Color3.fromRGB(0, 0, 0),
		EnvironmentDiffuseScale = 0,
		EnvironmentSpecularScale = 0,
		ExposureCompensation = 0,
	},
	Atmosphere = { Density = 0.6, Haze = 0, Glare = 0, Color = Color3.fromRGB(3, 3, 4), Decay = Color3.fromRGB(0, 0, 0) },
}

local function applyPreset(preset)
	local info = TweenInfo.new(1.6, Enum.EasingStyle.Sine)
	TweenService:Create(Lighting, info, preset.Lighting):Play()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		TweenService:Create(atmosphere, info, preset.Atmosphere):Play()
	end
end

-- Floating dust motes around the camera while underground.
local motes: Part
local motesEmitter: ParticleEmitter

local function buildMotes()
	motes = Instance.new("Part")
	motes.Name = "CaveMotes"
	motes.Anchored = true
	motes.CanCollide = false
	motes.CanQuery = false
	motes.CanTouch = false
	motes.Transparency = 1
	motes.Size = Vector3.new(36, 18, 36)
	motesEmitter = Instance.new("ParticleEmitter")
	motesEmitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	motesEmitter.LightEmission = 0.4
	motesEmitter.LightInfluence = 0.6
	motesEmitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.12), NumberSequenceKeypoint.new(1, 0) })
	motesEmitter.Transparency = NumberSequence.new(0.3)
	motesEmitter.Lifetime = NumberRange.new(5, 9)
	motesEmitter.Rate = 14
	motesEmitter.Speed = NumberRange.new(0.2, 0.8)
	motesEmitter.SpreadAngle = Vector2.new(180, 180)
	motesEmitter.Acceleration = Vector3.new(0, 0.05, 0)
	motesEmitter.Enabled = false
	motesEmitter.Parent = motes
	motes.Parent = workspace
	game:GetService("RunService").RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if camera and motesEmitter.Enabled then
			motes.CFrame = CFrame.new(camera.CFrame.Position)
		end
	end)
end

local function setMotes(mineId: string?)
	local mine = mineId and Mines.ById[mineId]
	motesEmitter.Enabled = mine ~= nil
	if mine then
		motesEmitter.Color = ColorSequence.new(mine.Lighting.AtmosphereColor:Lerp(Color3.new(1, 1, 1), 0.6))
	end
end

function ZoneController:Init()
	buildMotes()
	task.spawn(function()
		while true do
			task.wait(0.4)
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root then
				continue
			end
			local mineId, zoneId = ZoneLocator.Locate(root.Position)
			local key = if mineId and zoneId then mineId .. "/" .. zoneId else nil
			if key == self.Current then
				continue
			end
			self.Current = key
			local zone = if mineId and zoneId then Mines.GetZone(mineId, zoneId) else nil
			local dark = zone ~= nil and zone.Dark ~= nil
			if mineId ~= self.CurrentMine or not key or dark ~= self.InDark then
				self.CurrentMine = mineId
				self.InDark = dark
				local mineConfig = mineId and Mines.ById[mineId]
				SoundController:SetAmbience(if mineConfig then mineConfig.Ambience or "CaveAmbience" else "SurfaceAmbience")
				applyPreset(if dark then DARK elseif mineId then cavePreset(mineId) else SURFACE)
				setMotes(mineId)
			end
			if dark and zone and zone.Dark then
				local state = StateController.State
				local needed = Equipment.Lamps[zone.Dark]
				if state and state.LampTier < zone.Dark then
					Toasts:Notify(`It's pitch black. A {needed.Name} might reveal what's hidden here.`, "Warn")
				else
					Toasts:Notify("Your lamp cuts through the darkness.", "Good")
				end
			end
			if key and not seen[key] then
				seen[key] = true
				local mine = Mines.ById[mineId :: string]
				-- Don't stomp on a banner that is still showing (e.g. an arrival intro).
				if zone and mine and os.clock() - Toasts.LastBannerAt > 4 then
					Toasts:Banner(zone.DisplayName, mine.DisplayName)
				end
			end
		end
	end)
end

return ZoneController
