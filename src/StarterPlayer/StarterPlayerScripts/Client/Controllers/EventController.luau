--!strict
-- Random event announcements (banner + notice + sound), the event countdown
-- chip on the HUD, and achievement unlock pop-ups.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Achievements = require(Shared.Config.Achievements)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)

local SoundController = require(script.Parent.SoundController)
local Toasts = require(script.Parent.Parent.UI.Toasts)
local Theme = require(script.Parent.Parent.UI.Theme)

local EventController = {}

local chip: Frame
local chipLabel: TextLabel
local popup: CanvasGroup
local popupName: TextLabel
local popupDesc: TextLabel
local popupReward: TextLabel
local popupToken = 0

local function buildChip(gui: ScreenGui)
	chip = Theme.Panel({
		Name = "EventChip",
		Position = UDim2.fromOffset(14, 162),
		Size = UDim2.fromOffset(230, 34),
		Visible = false,
	})
	local stroke = chip:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = Theme.Colors.Cash
	end
	chip.Parent = gui
	chipLabel = Theme.Label({
		Text = "",
		TextSize = 16,
		TextColor3 = Theme.Colors.Cash,
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	chipLabel.Parent = chip
end

local function buildPopup(gui: ScreenGui)
	popup = Instance.new("CanvasGroup")
	popup.Name = "Achievement"
	popup.AnchorPoint = Vector2.new(0.5, 0)
	popup.Position = UDim2.new(0.5, 0, 0, 70)
	popup.Size = UDim2.fromOffset(380, 76)
	popup.BackgroundColor3 = Theme.Colors.Panel
	popup.BackgroundTransparency = 0.04
	popup.BorderSizePixel = 0
	popup.GroupTransparency = 1
	popup.Visible = false
	Theme.Corner(popup, 12)
	Theme.Stroke(popup, Theme.Colors.Cash, 2)
	Theme.Padding(popup, 10)
	popup.Parent = gui

	local badge = Instance.new("Frame")
	badge.Size = UDim2.fromOffset(52, 52)
	badge.Position = UDim2.fromOffset(2, 2)
	badge.BackgroundColor3 = Theme.Colors.Cash
	Theme.Corner(badge, 26)
	badge.Parent = popup
	local star = Theme.Label({
		Text = "★",
		TextSize = 32,
		TextColor3 = Color3.fromRGB(110, 70, 10),
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	star.Parent = badge

	local header = Theme.Label({ Text = "ACHIEVEMENT UNLOCKED", TextSize = 13, TextColor3 = Theme.Colors.Cash,
		Position = UDim2.fromOffset(66, 0), Size = UDim2.new(1, -66, 0, 16) })
	header.Parent = popup
	popupName = Theme.Label({ Text = "", TextSize = 21, FontFace = Theme.FontHeavy, Position = UDim2.fromOffset(66, 16),
		Size = UDim2.new(1, -150, 0, 24), TextTruncate = Enum.TextTruncate.AtEnd })
	popupName.Parent = popup
	popupDesc = Theme.Label({ Text = "", TextSize = 14, FontFace = Theme.FontMedium, TextColor3 = Theme.Colors.TextDim,
		Position = UDim2.fromOffset(66, 40), Size = UDim2.new(1, -66, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })
	popupDesc.Parent = popup
	popupReward = Theme.Label({ Text = "", TextSize = 18, FontFace = Theme.FontHeavy, TextColor3 = Theme.Colors.Cash,
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 18), Size = UDim2.fromOffset(90, 22),
		TextXAlignment = Enum.TextXAlignment.Right })
	popupReward.Parent = popup
end

local function showAchievement(id: string)
	local a = Achievements.Get(id)
	if not a then
		return
	end
	popupName.Text = a.Name
	popupDesc.Text = a.Description
	popupReward.Text = "+" .. Format.Cash(a.Reward)
	SoundController:Play("RichFind")
	popup.Visible = true
	popup.Position = UDim2.new(0.5, 0, 0, 50)
	TweenService:Create(popup, TweenInfo.new(0.35, Enum.EasingStyle.Back), { GroupTransparency = 0, Position = UDim2.new(0.5, 0, 0, 70) }):Play()
	popupToken += 1
	local token = popupToken
	task.delay(3.4, function()
		if token ~= popupToken then
			return
		end
		TweenService:Create(popup, TweenInfo.new(0.4), { GroupTransparency = 1 }):Play()
		task.wait(0.4)
		if token == popupToken then
			popup.Visible = false
		end
	end)
end

local function onEvent(payload)
	if type(payload) ~= "table" then
		return
	end
	SoundController:Play("MineComplete")
	Toasts:Banner(payload.name or "Event", "RANDOM EVENT")
	task.delay(1, function()
		Toasts:Notify(payload.description or "", "Good")
	end)
end

function EventController:Init()
	local gui = Theme.Screen("Events", 35)
	buildChip(gui)
	buildPopup(gui)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	Remotes.Event("Achievement").OnClientEvent:Connect(showAchievement)
	Remotes.Event("GameEvent").OnClientEvent:Connect(onEvent)

	-- Countdown for timed events.
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.25 then
			return
		end
		accumulator = 0
		local name = ReplicatedStorage:GetAttribute("EventName")
		local ends = ReplicatedStorage:GetAttribute("EventEnds")
		if type(name) == "string" and type(ends) == "number" then
			local left = math.max(0, math.floor(ends - workspace:GetServerTimeNow()))
			chipLabel.Text = string.format("%s  %d:%02d", name:upper(), left // 60, left % 60)
			chip.Visible = true
		else
			chip.Visible = false
		end
	end)
end

return EventController
