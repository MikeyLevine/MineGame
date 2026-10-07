--!strict
-- Destination picker for the camp mine lift. Shows every lift stop; locked
-- ones explain how to unlock them. The server validates the ride.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Abyss = require(Shared.Config.Abyss)
local Mines = require(Shared.Config.Mines)
local Progress = require(Shared.Progress)
local Remotes = require(Shared.Remotes)

local Theme = require(script.Parent.Theme)
local Toasts = require(script.Parent.Toasts)
local StateController = require(script.Parent.Parent.Controllers.StateController)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)

local LiftMenu = {}

local CLOSE_DISTANCE = 18

local gui: ScreenGui
local window: Frame
local listFrame: ScrollingFrame
local isOpen = false
local busy = false
local distanceConn: RBXScriptConnection?
local firstButton: GuiObject?

local function lockedHint(lift: Mines.Lift): string
	if lift.Abyss then
		return "Complete the Unknown Depths to unlock"
	end
	if lift.UnlockGate then
		for _, mine in Mines.ById do
			local gate = mine.Gates[lift.UnlockGate]
			if gate then
				return `Break through the {gate.DisplayName:lower()} to unlock`
			end
		end
	end
	if lift.UnlockMine then
		for _, mine in Mines.ById do
			if mine.NextMine == lift.UnlockMine then
				return `Complete the {mine.DisplayName} to unlock`
			end
		end
		return "Reach this mine to unlock"
	end
	return "Locked"
end

local function render()
	local state = StateController.State
	if not state then
		return
	end
	for _, child in listFrame:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	firstButton = nil
	for i, lift in Mines.Lifts do
		local unlocked = Progress.IsLiftUnlocked(state :: any, lift)
		local rowFrame = Instance.new("Frame")
		rowFrame.LayoutOrder = i
		rowFrame.BackgroundColor3 = Theme.Colors.PanelLight
		rowFrame.BorderSizePixel = 0
		rowFrame.Size = UDim2.new(1, -10, 0, 64)
		Theme.Corner(rowFrame, 10)
		Theme.Padding(rowFrame, 10)
		rowFrame.Parent = listFrame

		local name = Theme.Label({
			Text = lift.DisplayName,
			TextSize = 20,
			FontFace = Theme.FontHeavy,
			TextColor3 = if unlocked then Theme.Colors.Text else Theme.Colors.TextDim,
			Size = UDim2.new(1, -130, 0, 24),
		})
		name.Parent = rowFrame
		local desc = Theme.Label({
			Text = if not unlocked then lockedHint(lift)
				elseif lift.Abyss then `Starts at floor {Abyss.StartFloor(state.Abyss and state.Abyss.Best or 0)} · best {state.Abyss and state.Abyss.Best or 0}`
				else lift.Description,
			TextSize = 14,
			FontFace = Theme.FontMedium,
			TextColor3 = Theme.Colors.TextDim,
			Position = UDim2.fromOffset(0, 24),
			Size = UDim2.new(1, -130, 0, 18),
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		desc.Parent = rowFrame

		local button = Theme.Button({
			Name = "Go",
			Text = if unlocked then "RIDE" else "LOCKED",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(110, 40),
			BackgroundColor3 = if unlocked then Theme.Colors.Accent else Theme.Colors.Stroke,
			TextColor3 = if unlocked then Color3.fromRGB(30, 20, 10) else Theme.Colors.TextDim,
		})
		button.Parent = rowFrame
		if unlocked and not firstButton then
			firstButton = button
		end
		button.Activated:Connect(function()
			if not unlocked or busy then
				SoundController:Play("Denied")
				return
			end
			busy = true
			local ok, message = Remotes.Function("UseLift"):InvokeServer(lift.Id)
			busy = false
			if ok then
				LiftMenu:Close()
			else
				Toasts:Notify(message, "Warn")
			end
		end)
	end
	-- Cap the height (it must fit a 720p screen at UI scale 1.1); the list scrolls.
	window.Size = UDim2.fromOffset(460, math.min(92 + #Mines.Lifts * 72, 560))
end

function LiftMenu:Close()
	if not isOpen then
		return
	end
	isOpen = false
	if distanceConn then
		distanceConn:Disconnect()
		distanceConn = nil
	end
	gui.Enabled = false
	GuiService.SelectedObject = nil
end

function LiftMenu:Open()
	render()
	isOpen = true
	gui.Enabled = true
	window.Position = UDim2.fromScale(0.5, 0.55)
	TweenService:Create(window, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
	if UserInputService.GamepadEnabled and firstButton then
		GuiService.SelectedObject = firstButton
	end
	local camp = workspace:FindFirstChild("Camp")
	local lift = camp and camp:FindFirstChild("MineLift")
	local anchor = lift and lift:FindFirstChild("PromptPart") :: BasePart?
	distanceConn = RunService.Heartbeat:Connect(function()
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root or not anchor or (root.Position - anchor.Position).Magnitude > CLOSE_DISTANCE then
			self:Close()
		end
	end)
end

function LiftMenu:Init()
	gui = Theme.Screen("LiftMenu", 30)
	gui.Enabled = false

	window = Theme.Panel({
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, 240),
		BackgroundTransparency = 0.04,
	})
	Theme.Padding(window, 18)
	window.Parent = gui

	local title = Theme.Label({ Text = "MINE LIFT", TextSize = 30, FontFace = Theme.FontHeavy, Size = UDim2.new(1, -50, 0, 34) })
	title.Parent = window
	local close = Theme.Button({
		Name = "Close",
		Text = "X",
		TextSize = 20,
		BackgroundColor3 = Theme.Colors.PanelLight,
		TextColor3 = Theme.Colors.Text,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(40, 40),
	})
	close.Parent = window
	close.Activated:Connect(function()
		self:Close()
	end)

	listFrame = Instance.new("ScrollingFrame")
	listFrame.Name = "List"
	listFrame.BackgroundTransparency = 1
	listFrame.BorderSizePixel = 0
	listFrame.ScrollBarThickness = 6
	listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	listFrame.CanvasSize = UDim2.new()
	listFrame.ScrollingDirection = Enum.ScrollingDirection.Y
	listFrame.Position = UDim2.fromOffset(0, 52)
	listFrame.Size = UDim2.new(1, 0, 1, -52)
	listFrame.Parent = window
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = listFrame

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	Remotes.Event("OpenLift").OnClientEvent:Connect(function()
		self:Open()
	end)
	StateController.Changed:Connect(function()
		if isOpen then
			render()
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if isOpen and (input.KeyCode == Enum.KeyCode.ButtonB or (not processed and input.KeyCode == Enum.KeyCode.Escape)) then
			self:Close()
		end
	end)
end

return LiftMenu
