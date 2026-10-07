--!strict
-- Compact mine-progress tracker (top-right): the current mine's completion
-- objectives and overall percentage. Tap the header to collapse it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Mines = require(Shared.Config.Mines)
local Progress = require(Shared.Progress)
local Remotes = require(Shared.Remotes)

local Theme = require(script.Parent.Theme)
local StateController = require(script.Parent.Parent.Controllers.StateController)

local Objectives = {}

local panel: Frame
local header: TextButton
local mineLabel: TextLabel
local percentLabel: TextLabel
local barFill: Frame
local list: Frame
local footer: TextLabel
local collapsed = false

local ROW_HEIGHT = 24

local function row(order: number, done: boolean, label: string, count: string?)
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	frame.LayoutOrder = order

	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0, 0.5)
	dot.Position = UDim2.new(0, 2, 0.5, 0)
	dot.Size = UDim2.fromOffset(12, 12)
	dot.BackgroundColor3 = if done then Theme.Colors.Good else Theme.Colors.Panel
	dot.BackgroundTransparency = if done then 0 else 0.2
	Theme.Corner(dot, 6)
	Theme.Stroke(dot, if done then Theme.Colors.Good else Theme.Colors.TextDim, 1.5)
	dot.Parent = frame

	local text = Theme.Label({
		Text = label,
		TextSize = 16,
		FontFace = Theme.FontMedium,
		TextColor3 = if done then Theme.Colors.TextDim else Theme.Colors.Text,
		Position = UDim2.fromOffset(22, 0),
		Size = UDim2.new(1, -80, 1, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	text.Parent = frame

	if count then
		local c = Theme.Label({
			Text = count,
			TextSize = 15,
			TextColor3 = if done then Theme.Colors.Good else Theme.Colors.Accent,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0, 60, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
		})
		c.Parent = frame
	end
	frame.Parent = list
end

local function render(state: StateController.State)
	local mineId = Progress.FrontierMine(state :: any)
	local mine = mineId and Mines.ById[mineId]
	local settings = state.Settings
	panel.Visible = mine ~= nil and not (settings and settings.Objectives == false)
	if not mineId or not mine then
		return
	end
	local items, ready, percent = Progress.Evaluate(state :: any, mineId)
	mineLabel.Text = mine.DisplayName:upper()
	percentLabel.Text = `{percent}%`
	TweenService:Create(barFill, TweenInfo.new(0.3), { Size = UDim2.fromScale(percent / 100, 1) }):Play()

	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for i, item in items do
		row(i, item.Done, item.Label, if item.ShowCount then `{item.Current}/{item.Target}` else nil)
	end
	footer.Text = if ready then `Ready! Go to {mine.WallName} and ascend.` else "Complete every objective to ascend."
	footer.TextColor3 = if ready then Theme.Colors.Good else Theme.Colors.TextDim

	list.Visible = not collapsed
	footer.Visible = not collapsed
	local rows = #items
	panel.Size = UDim2.fromOffset(270, if collapsed then 62 else 92 + rows * ROW_HEIGHT + 24)
end

function Objectives:Pulse()
	local stroke = panel:FindFirstChildOfClass("UIStroke")
	if not stroke then
		return
	end
	if collapsed then
		collapsed = false
		if StateController.State then
			render(StateController.State)
		end
	end
	for _ = 1, 3 do
		stroke.Color = Theme.Colors.Accent
		stroke.Thickness = 3
		task.wait(0.25)
		stroke.Color = Theme.Colors.Stroke
		stroke.Thickness = 1.5
		task.wait(0.2)
	end
end

function Objectives:Init()
	local gui = Theme.Screen("Objectives", 11)
	panel = Theme.Panel({
		Name = "Panel",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 10),
		Size = UDim2.fromOffset(270, 160),
		Visible = false,
	})
	Theme.Padding(panel, 10)
	panel.Parent = gui

	header = Instance.new("TextButton")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Text = ""
	header.Size = UDim2.new(1, 0, 0, 40)
	header.Parent = panel

	mineLabel = Theme.Label({ Text = "", TextSize = 14, TextColor3 = Theme.Colors.Accent, Size = UDim2.new(1, -50, 0, 18) })
	mineLabel.Parent = header
	local title = Theme.Label({
		Text = "Mine progress",
		TextSize = 18,
		FontFace = Theme.FontHeavy,
		Position = UDim2.fromOffset(0, 16),
		Size = UDim2.new(1, -50, 0, 20),
	})
	title.Parent = header
	percentLabel = Theme.Label({
		Text = "0%",
		TextSize = 22,
		FontFace = Theme.FontHeavy,
		TextColor3 = Theme.Colors.Accent,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 6),
		Size = UDim2.fromOffset(60, 26),
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	percentLabel.Parent = header

	local track = Instance.new("Frame")
	track.BackgroundColor3 = Theme.Colors.PanelLight
	track.BorderSizePixel = 0
	track.Position = UDim2.fromOffset(0, 44)
	track.Size = UDim2.new(1, 0, 0, 6)
	Theme.Corner(track, 3)
	track.Parent = panel
	barFill = Instance.new("Frame")
	barFill.BackgroundColor3 = Theme.Colors.Accent
	barFill.BorderSizePixel = 0
	barFill.Size = UDim2.fromScale(0, 1)
	Theme.Corner(barFill, 3)
	barFill.Parent = track

	list = Instance.new("Frame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(0, 58)
	list.Size = UDim2.new(1, 0, 1, -82)
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	footer = Theme.Label({
		Text = "",
		TextSize = 14,
		FontFace = Theme.FontMedium,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 18),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	footer.Parent = panel

	header.Activated:Connect(function()
		collapsed = not collapsed
		if StateController.State then
			render(StateController.State)
		end
	end)

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	-- Phones: start collapsed so it doesn't cover the view.
	local UserInputService = game:GetService("UserInputService")
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		collapsed = true
	end
	StateController:Observe(render)
	Remotes.Event("ObjectivesPulse").OnClientEvent:Connect(function()
		task.spawn(self.Pulse, self)
	end)
end

return Objectives
