--!strict
-- Screen fades around server teleports (lifts, portals) and the arrival intro.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local SoundController = require(script.Parent.SoundController)
local Toasts = require(script.Parent.Parent.UI.Toasts)

local TravelController = {}

local overlay: Frame

function TravelController:Flash(color: Color3?, duration: number?)
	overlay.BackgroundColor3 = color or Color3.new(1, 1, 1)
	overlay.BackgroundTransparency = 0.05
	TweenService:Create(overlay, TweenInfo.new(duration or 0.8, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
end

local function onTravel(payload: { [string]: any })
	if type(payload) ~= "table" then
		return
	end
	if payload.phase == "out" then
		overlay.BackgroundColor3 = Color3.new(0, 0, 0)
		SoundController:Play("LiftRide")
		TweenService:Create(overlay, TweenInfo.new(0.4), { BackgroundTransparency = 0 }):Play()
	elseif payload.phase == "in" then
		TweenService:Create(overlay, TweenInfo.new(0.7), { BackgroundTransparency = 1 }):Play()
		if payload.title then
			Toasts:Banner(payload.title, payload.subtitle)
		end
		if payload.tagline then
			task.delay(1.2, function()
				Toasts:Notify(payload.tagline, "Info")
			end)
		end
	end
end

function TravelController:Init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Fade"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100
	overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 1
	overlay.BorderSizePixel = 0
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.Active = false
	overlay.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	Remotes.Event("Travel").OnClientEvent:Connect(onTravel)
end

return TravelController
