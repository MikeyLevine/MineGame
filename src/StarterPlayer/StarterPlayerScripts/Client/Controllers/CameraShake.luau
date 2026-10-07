--!strict
-- Small camera shakes for impacts, applied through Humanoid.CameraOffset so
-- the normal camera keeps working. Respects the player's Shake setting.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local StateController = require(script.Parent.StateController)

local CameraShake = {}

local intensity = 0
local decay = 0

function CameraShake:Shake(amount: number, duration: number?)
	local state = StateController.State
	if state and state.Settings and state.Settings.Shake == false then
		return
	end
	intensity = math.max(intensity, amount)
	decay = intensity / (duration or 0.25)
end

function CameraShake:Init()
	RunService.RenderStepped:Connect(function(dt)
		local character = Players.LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end
		if intensity <= 0 then
			if humanoid.CameraOffset ~= Vector3.zero then
				humanoid.CameraOffset = Vector3.zero
			end
			return
		end
		humanoid.CameraOffset = Vector3.new(
			(math.random() - 0.5) * intensity,
			(math.random() - 0.5) * intensity,
			(math.random() - 0.5) * intensity * 0.5
		)
		intensity = math.max(0, intensity - decay * dt)
	end)
end

return CameraShake
