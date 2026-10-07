--!strict
-- Transient messages: pickup popups, notices and big area banners.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local Toasts = {}
Toasts.LastBannerAt = -math.huge

local gui: ScreenGui
local pickupColumn: Frame
local noticeColumn: Frame
local banner: Frame
local lastNotice: { text: string, at: number } = { text = "", at = 0 }

local function fadeOut(frame: GuiObject, delay: number, duration: number)
	task.delay(delay, function()
		if not frame.Parent then
			return
		end
		local info = TweenInfo.new(duration)
		for _, d in frame:GetDescendants() do
			if d:IsA("TextLabel") then
				TweenService:Create(d, info, { TextTransparency = 1 }):Play()
			elseif d:IsA("UIStroke") then
				TweenService:Create(d, info, { Transparency = 1 }):Play()
			end
		end
		if frame:IsA("Frame") then
			TweenService:Create(frame, info, { BackgroundTransparency = 1 }):Play()
		end
		task.wait(duration)
		frame:Destroy()
	end)
end

-- "+1 Coal" just above the backpack bar.
function Toasts:Pickup(text: string, color: Color3)
	local label = Theme.Label({
		Text = text,
		TextColor3 = color,
		TextSize = 24,
		FontFace = Theme.FontHeavy,
		Size = UDim2.new(1, 0, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Transparency = 0.3
	stroke.Parent = label
	label.Parent = pickupColumn
	label.TextTransparency = 1
	TweenService:Create(label, TweenInfo.new(0.12), { TextTransparency = 0 }):Play()
	fadeOut(label, 1.0, 0.5)
end

-- Short status message at the top of the screen. kind: "Info" | "Warn" | "Good"
function Toasts:Notify(text: string, kind: string?)
	local now = os.clock()
	if lastNotice.text == text and now - lastNotice.at < 1.5 then
		return
	end
	lastNotice = { text = text, at = now }

	local accent = if kind == "Warn" then Theme.Colors.Bad elseif kind == "Good" then Theme.Colors.Good else Theme.Colors.Accent
	local frame = Theme.Panel({
		Size = UDim2.fromOffset(0, 44),
		AutomaticSize = Enum.AutomaticSize.X,
	})
	local stroke = frame:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = accent
	end
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 18)
	pad.PaddingRight = UDim.new(0, 18)
	pad.Parent = frame
	local label = Theme.Label({
		Text = text,
		TextSize = 20,
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
	})
	label.Parent = frame
	frame.Parent = noticeColumn
	fadeOut(frame, 2.6, 0.4)
end

-- Big centered title, used when entering a new area of the mine.
function Toasts:Banner(title: string, subtitle: string?)
	Toasts.LastBannerAt = os.clock()
	banner:ClearAllChildren()
	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 2)
	layout.Parent = banner
	local sub = Theme.Label({
		Text = (subtitle or ""):upper(),
		TextSize = 18,
		TextColor3 = Theme.Colors.Accent,
		Size = UDim2.new(1, 0, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 1,
	})
	sub.Parent = banner
	local main = Theme.Label({
		Text = title,
		TextSize = 46,
		FontFace = Theme.FontHeavy,
		Size = UDim2.new(1, 0, 0, 52),
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 2,
	})
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Transparency = 0.4
	stroke.Parent = main
	main.Parent = banner
	for _, l in { sub, main } do
		l.TextTransparency = 1
		TweenService:Create(l, TweenInfo.new(0.5), { TextTransparency = 0 }):Play()
	end
	task.delay(2.8, function()
		for _, l in { sub, main } do
			if l.Parent then
				TweenService:Create(l, TweenInfo.new(0.8), { TextTransparency = 1 }):Play()
				TweenService:Create(stroke, TweenInfo.new(0.8), { Transparency = 1 }):Play()
			end
		end
	end)
end

function Toasts:Init()
	gui = Theme.Screen("Toasts", 20)

	pickupColumn = Instance.new("Frame")
	pickupColumn.Name = "Pickups"
	pickupColumn.BackgroundTransparency = 1
	pickupColumn.AnchorPoint = Vector2.new(0.5, 1)
	pickupColumn.Position = UDim2.new(0.5, 0, 1, -150)
	pickupColumn.Size = UDim2.fromOffset(440, 140)
	pickupColumn.Parent = gui
	local pl = Instance.new("UIListLayout")
	pl.VerticalAlignment = Enum.VerticalAlignment.Bottom
	pl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	pl.Parent = pickupColumn

	noticeColumn = Instance.new("Frame")
	noticeColumn.Name = "Notices"
	noticeColumn.BackgroundTransparency = 1
	noticeColumn.AnchorPoint = Vector2.new(0.5, 0)
	noticeColumn.Position = UDim2.new(0.5, 0, 0, 12)
	noticeColumn.Size = UDim2.fromOffset(600, 160)
	noticeColumn.Parent = gui
	local nl = Instance.new("UIListLayout")
	nl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	nl.Padding = UDim.new(0, 6)
	nl.Parent = noticeColumn

	banner = Instance.new("Frame")
	banner.Name = "Banner"
	banner.BackgroundTransparency = 1
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.fromScale(0.5, 0.3)
	banner.Size = UDim2.fromOffset(700, 90)
	banner.Parent = gui

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

return Toasts
