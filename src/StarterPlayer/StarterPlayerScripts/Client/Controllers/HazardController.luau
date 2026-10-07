--!strict
-- Feedback while standing in a hazard volume: a pulsing edge glow in the
-- hazard's colour and a warning when unprotected, a reassurance when the
-- suit is doing its job.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Hazards = require(Shared.Config.Hazards)
local Remotes = require(Shared.Remotes)

local SoundController = require(script.Parent.SoundController)
local Toasts = require(script.Parent.Parent.UI.Toasts)

local HazardController = {}

local vignette: Frame
local lastWarning = 0
local lastSafe = 0

local function pulse(color: Color3)
	vignette.BackgroundColor3 = color
	vignette.BackgroundTransparency = 0.55
	TweenService:Create(vignette, TweenInfo.new(0.45), { BackgroundTransparency = 1 }):Play()
end

function HazardController:Init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hazard"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	vignette = Instance.new("Frame")
	vignette.BackgroundTransparency = 1
	vignette.BorderSizePixel = 0
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.Parent = gui
	-- Transparent in the middle, coloured at the edges.
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.25, 0.85),
		NumberSequenceKeypoint.new(0.75, 0.85),
		NumberSequenceKeypoint.new(1, 0),
	})
	gradient.Parent = vignette
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	Remotes.Event("Hazard").OnClientEvent:Connect(function(payload)
		local hazard = type(payload) == "table" and Hazards[payload.type]
		if not hazard then
			return
		end
		local now = os.clock()
		if payload.protected then
			if now - lastSafe > 20 then
				lastSafe = now
				Toasts:Notify(`Your suit shields you from the {hazard.DisplayName:lower()}.`, "Good")
			end
			return
		end
		pulse(hazard.Color)
		if now - lastWarning > 4 then
			lastWarning = now
			Toasts:Notify(hazard.Warning, "Warn")
			SoundController:Play("HeatWarning")
		end
	end)
end

return HazardController
