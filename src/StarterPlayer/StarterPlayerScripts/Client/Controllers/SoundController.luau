--!strict
-- One-shot sounds (2D or positional) and the looping ambience bed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sounds = require(Shared.Config.Sounds)

local SoundController = {}

local ambience: { [string]: Sound } = {}

-- Volume buses, controlled from the Settings menu.
local function group(name: string): SoundGroup
	local g = SoundService:FindFirstChild(name) :: SoundGroup?
	if not g then
		g = Instance.new("SoundGroup")
		g.Name = name
		g.Volume = 1
		g.Parent = SoundService
	end
	return g :: SoundGroup
end
SoundController.SfxGroup = group("SFX")
SoundController.AmbienceGroup = group("Ambience")
local currentAmbience: string? = nil

local function make(name: string): Sound?
	local def = (Sounds :: any)[name]
	if not def then
		return nil
	end
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = def.Id
	s.Volume = def.Volume or 0.5
	s.PlaybackSpeed = def.Speed or 1
	s.SoundGroup = if name:find("Ambience") then SoundController.AmbienceGroup else SoundController.SfxGroup
	return s
end

-- Plays a sound once. With `at`, it plays from that world position.
function SoundController:Play(name: string, at: Vector3?, pitchJitter: number?)
	local s = make(name)
	if not s then
		return
	end
	if pitchJitter then
		s.PlaybackSpeed *= 1 + (math.random() * 2 - 1) * pitchJitter
	end
	if at then
		local holder = Instance.new("Attachment")
		holder.WorldPosition = at
		holder.Parent = workspace.Terrain
		s.RollOffMinDistance = 8
		s.RollOffMaxDistance = 80
		s.Parent = holder
		s.Ended:Once(function()
			holder:Destroy()
		end)
		task.delay(6, function()
			if holder.Parent then
				holder:Destroy()
			end
		end)
	else
		s.Parent = SoundService
		s.Ended:Once(function()
			s:Destroy()
		end)
	end
	s:Play()
end

local function ensureLoop(key: string)
	if ambience[key] then
		return
	end
	local s = make(key)
	if s then
		s.Looped = true
		s.Volume = 0
		s.Parent = SoundService
		s:Play()
		ambience[key] = s
	end
end

-- Crossfades to the named ambience loop (any Sounds key, e.g. "CaveAmbience").
function SoundController:SetAmbience(name: string)
	if currentAmbience == name then
		return
	end
	currentAmbience = name
	ensureLoop(name)
	for key, sound in ambience do
		local target = if key == name then (Sounds :: any)[key].Volume else 0
		TweenService:Create(sound, TweenInfo.new(2), { Volume = target }):Play()
	end
end

function SoundController:SetVolumes(sfx: number, ambienceVolume: number)
	self.SfxGroup.Volume = sfx
	self.AmbienceGroup.Volume = ambienceVolume
end

function SoundController:Init()
	for _, key in { "CaveAmbience", "SurfaceAmbience" } do
		ensureLoop(key)
	end
	self:SetAmbience("SurfaceAmbience")
end

return SoundController
