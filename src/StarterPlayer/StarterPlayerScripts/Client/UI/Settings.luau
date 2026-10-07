--!strict
-- Settings menu: sound and ambience volume, camera shake, objectives panel
-- and hints. Changes apply instantly and are saved to the server shortly
-- after the player stops adjusting.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local Theme = require(script.Parent.Theme)
local StateController = require(script.Parent.Parent.Controllers.StateController)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)

local Settings = {}

type Values = { Sfx: number, Ambience: number, Shake: boolean, Objectives: boolean, Hints: boolean }

local DEFAULTS: Values = { Sfx = 1, Ambience = 1, Shake = true, Objectives = true, Hints = true }

local gui: ScreenGui
local window: Frame
local values: Values = table.clone(DEFAULTS)
local refreshers: { () -> () } = {}
local saveToken = 0
local loadedFromServer = false

Settings.Changed = Instance.new("BindableEvent")

function Settings:Get(): Values
	return values
end

local function getValue(key: string): any
	return (values :: any)[key]
end

local function setValue(key: string, value: any)
	local t: any = values
	t[key] = value
end

local function apply()
	SoundController:SetVolumes(values.Sfx, values.Ambience)
	for _, refresh in refreshers do
		refresh()
	end
	Settings.Changed:Fire(values)
end

local function queueSave()
	saveToken += 1
	local token = saveToken
	task.delay(1, function()
		if token == saveToken then
			Remotes.Function("SaveSettings"):InvokeServer(values)
		end
	end)
end

local function rowFrame(order: number, label: string, key: string): Frame
	local f = Instance.new("Frame")
	f.Name = "Row_" .. key
	f.LayoutOrder = order
	f.BackgroundColor3 = Theme.Colors.PanelLight
	f.BorderSizePixel = 0
	f.Size = UDim2.new(1, 0, 0, 50)
	Theme.Corner(f, 8)
	Theme.Padding(f, 12)
	f.Parent = window:FindFirstChild("List")
	Theme.Label({ Text = label, TextSize = 18, Size = UDim2.new(0.45, 0, 1, 0) }).Parent = f
	return f
end

local function slider(order: number, label: string, key: string)
	local f = rowFrame(order, label, key)
	local track = Instance.new("TextButton")
	track.Name = key
	track.Text = ""
	track.AutoButtonColor = false
	track.BackgroundColor3 = Theme.Colors.Panel
	track.BorderSizePixel = 0
	track.AnchorPoint = Vector2.new(1, 0.5)
	track.Position = UDim2.new(1, -56, 0.5, 0)
	track.Size = UDim2.new(0.42, 0, 0, 12)
	Theme.Corner(track, 6)
	track.Parent = f
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Theme.Colors.Accent
	fill.BorderSizePixel = 0
	Theme.Corner(fill, 6)
	fill.Parent = track
	local knob = Instance.new("Frame")
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Size = UDim2.fromOffset(22, 22)
	knob.BackgroundColor3 = Theme.Colors.Text
	Theme.Corner(knob, 11)
	knob.Parent = track
	local pct = Theme.Label({ Text = "", TextSize = 16, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(46, 20), TextXAlignment = Enum.TextXAlignment.Right })
	pct.Parent = f

	local function refresh()
		local v = getValue(key) :: number
		fill.Size = UDim2.fromScale(v, 1)
		knob.Position = UDim2.fromScale(v, 0.5)
		pct.Text = `{math.floor(v * 100 + 0.5)}%`
	end
	table.insert(refreshers, refresh)

	local dragging = false
	local function setFromX(x: number)
		local v = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		setValue(key, math.floor(v * 20 + 0.5) / 20)
		apply()
		queueSave()
	end
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	-- Gamepad: A steps the volume down by a quarter, wrapping to full.
	track.Activated:Connect(function(_, count)
		if UserInputService.GamepadEnabled and count == 1 then
			local v = getValue(key) :: number
			setValue(key, if v <= 0 then 1 else math.max(0, v - 0.25))
			apply()
			queueSave()
		end
	end)
end

local function toggle(order: number, label: string, key: string)
	local f = rowFrame(order, label, key)
	local button = Theme.Button({ Name = key, Text = "", TextSize = 16, AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromOffset(96, 34) })
	button.Parent = f
	local function refresh()
		local on = getValue(key) == true
		button.Text = if on then "ON" else "OFF"
		button.BackgroundColor3 = if on then Theme.Colors.Accent else Theme.Colors.Stroke
		button.TextColor3 = if on then Color3.fromRGB(30, 20, 10) else Theme.Colors.TextDim
	end
	table.insert(refreshers, refresh)
	button.Activated:Connect(function()
		setValue(key, not getValue(key))
		apply()
		queueSave()
	end)
end

function Settings:Open()
	gui.Enabled = true
	if UserInputService.GamepadEnabled then
		local list = window:FindFirstChild("List")
		local first = list and list:FindFirstChild("Sfx", true)
		GuiService.SelectedObject = first :: GuiObject?
	end
end

function Settings:Close()
	gui.Enabled = false
	GuiService.SelectedObject = nil
end

function Settings:Toggle()
	if gui.Enabled then
		self:Close()
	else
		self:Open()
	end
end

function Settings:Init()
	gui = Theme.Screen("Settings", 33)
	gui.Enabled = false
	window = Theme.Panel({ Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, 400), BackgroundTransparency = 0.04 })
	Theme.Padding(window, 18)
	window.Parent = gui
	Theme.Label({ Text = "SETTINGS", TextSize = 30, FontFace = Theme.FontHeavy, Size = UDim2.new(1, -50, 0, 34) }).Parent = window
	local close = Theme.Button({ Name = "Close", Text = "X", TextSize = 20, BackgroundColor3 = Theme.Colors.PanelLight,
		TextColor3 = Theme.Colors.Text, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(40, 40) })
	close.Parent = window
	close.Activated:Connect(function()
		self:Close()
	end)
	local list = Instance.new("Frame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(0, 52)
	list.Size = UDim2.new(1, 0, 1, -52)
	list.Parent = window
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	slider(1, "Sound effects", "Sfx")
	slider(2, "Ambience", "Ambience")
	toggle(3, "Camera shake", "Shake")
	toggle(4, "Objectives panel", "Objectives")
	toggle(5, "Hints", "Hints")

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local hud = Players.LocalPlayer.PlayerGui:WaitForChild("Hud")
	local gear = Theme.Button({ Name = "SettingsButton", Text = "⚙", TextSize = 22, BackgroundColor3 = Theme.Colors.Panel,
		TextColor3 = Theme.Colors.Text, Position = UDim2.fromOffset(170, 122), Size = UDim2.fromOffset(40, 34) })
	Theme.Stroke(gear, nil, 1.5, 0.2)
	gear.Parent = hud
	gear.Activated:Connect(function()
		self:Toggle()
	end)

	-- Gamepad: D-pad down toggles, B closes.
	UserInputService.InputBegan:Connect(function(input, processed)
		if gui.Enabled and (input.KeyCode == Enum.KeyCode.ButtonB or (not processed and input.KeyCode == Enum.KeyCode.Escape)) then
			self:Close()
		elseif not processed and input.KeyCode == Enum.KeyCode.DPadDown then
			self:Toggle()
		end
	end)

	StateController:Observe(function(state)
		if loadedFromServer or not state.Settings then
			return
		end
		loadedFromServer = true
		for k, v in DEFAULTS do
			local saved = (state.Settings :: any)[k]
			setValue(k, if saved == nil then v else saved)
		end
		apply()
	end)
	apply()
end

return Settings
