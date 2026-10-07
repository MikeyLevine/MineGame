--!strict
-- The Journal: overall game completion plus three tabs —
--  Mines:        completion per mine (areas, secrets, artifacts)
--  Collection:   every resource and how many you've mined (unseen ones hidden)
--  Achievements: progress towards each achievement
-- Open with the HUD button, J, or Y on a gamepad.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Achievements = require(Shared.Config.Achievements)
local Completion = require(Shared.Completion)
local Format = require(Shared.Util.Format)
local Mines = require(Shared.Config.Mines)
local Modifiers = require(Shared.Modifiers)
local Resources = require(Shared.Config.Resources)

local Theme = require(script.Parent.Theme)
local StateController = require(script.Parent.Parent.Controllers.StateController)

local Journal = {}

local gui: ScreenGui
local window: Frame
local overall: TextLabel
local overallFill: Frame
local content: ScrollingFrame
local tabs: { [string]: TextButton } = {}
local selected = "Mines"
local isOpen = false

local TAB_ORDER = { "Mines", "Collection", "Achievements" }

local function clear()
	for _, c in content:GetChildren() do
		if not c:IsA("UIListLayout") and not c:IsA("UIGridLayout") and not c:IsA("UIPadding") then
			c:Destroy()
		end
	end
	for _, c in content:GetChildren() do
		if c:IsA("UIListLayout") or c:IsA("UIGridLayout") then
			c:Destroy()
		end
	end
end

local function bar(parent: Instance, ratio: number, color: Color3, position: UDim2, size: UDim2)
	local track = Instance.new("Frame")
	track.BackgroundColor3 = Theme.Colors.Panel
	track.BorderSizePixel = 0
	track.Position = position
	track.Size = size
	Theme.Corner(track, 4)
	track.Parent = parent
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
	Theme.Corner(fill, 4)
	fill.Parent = track
end

local function row(order: number, height: number): Frame
	local f = Instance.new("Frame")
	f.LayoutOrder = order
	f.BackgroundColor3 = Theme.Colors.PanelLight
	f.BorderSizePixel = 0
	f.Size = UDim2.new(1, -8, 0, height)
	Theme.Corner(f, 8)
	Theme.Padding(f, 10)
	f.Parent = content
	return f
end

local function listLayout(padding: number)
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, padding)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = content
end

local function renderMines(state: any)
	listLayout(8)
	local level = state.Prestige or 0
	if level > 0 then
		local f = row(0, 54)
		Theme.Label({ Text = `PRESTIGE {level}`, TextSize = 20, FontFace = Theme.FontHeavy, TextColor3 = Color3.fromRGB(190, 140, 255),
			Size = UDim2.new(1, 0, 0, 24) }).Parent = f
		Theme.Label({
			Text = `Sell value +{math.floor((Modifiers.PRESTIGE_SELL ^ level - 1) * 100 + 0.5)}%   ·   Mining power +{math.floor((Modifiers.PRESTIGE_POWER ^ level - 1) * 100 + 0.5)}%   ·   Upgrades +{math.floor((Modifiers.PRESTIGE_PRICE ^ level - 1) * 100 + 0.5)}% cost`,
			TextSize = 15, FontFace = Theme.FontMedium, TextColor3 = Theme.Colors.TextDim,
			Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 18),
		}).Parent = f
	end
	for i, mineId in Completion.OrderedMines() do
		local mine = Mines.ById[mineId]
		local s = Completion.Mine(state, mineId)
		local f = row(i, 74)
		local known = s.Visited
		Theme.Label({
			Text = if known then `{mine.Order}. {mine.DisplayName}` else `{mine.Order}. ???`,
			TextSize = 20, FontFace = Theme.FontHeavy, Size = UDim2.new(1, -90, 0, 24),
			TextColor3 = if known then Theme.Colors.Text else Theme.Colors.TextDim,
		}).Parent = f
		Theme.Label({
			Text = if s.Completed then `ASCENDED · {s.Percent}%` else `{s.Percent}%`,
			TextSize = 18, FontFace = Theme.FontHeavy, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromOffset(200, 24), TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = if s.Completed then Theme.Colors.Good else Theme.Colors.Accent,
		}).Parent = f
		bar(f, s.Percent / 100, if s.Completed then Theme.Colors.Good else Theme.Colors.Accent,
			UDim2.fromOffset(0, 30), UDim2.new(1, 0, 0, 8))
		local details = { `Areas {s.ZonesReached}/{s.ZonesTotal}` }
		if s.SecretsTotal > 0 then
			table.insert(details, `Secrets {s.SecretsFound}/{s.SecretsTotal}`)
		end
		if s.ArtifactsTotal > 0 then
			table.insert(details, `Artifacts {s.ArtifactsFound}/{s.ArtifactsTotal}`)
		end
		Theme.Label({
			Text = if known then table.concat(details, "   ·   ") else "Not yet discovered",
			TextSize = 15, FontFace = Theme.FontMedium, TextColor3 = Theme.Colors.TextDim,
			Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 0, 18),
		}).Parent = f
	end
end

local function renderCollection(state: any)
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.25, -8, 0, 64)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = content
	for i, id in Resources.Order do
		local r = Resources.ById[id]
		local count = state.Stats.Mined[id] or 0
		local seen = count > 0
		local f = Instance.new("Frame")
		f.LayoutOrder = i
		f.BackgroundColor3 = Theme.Colors.PanelLight
		f.BorderSizePixel = 0
		Theme.Corner(f, 8)
		Theme.Padding(f, 8)
		f.Parent = content
		local swatch = Instance.new("Frame")
		swatch.Size = UDim2.fromOffset(16, 16)
		swatch.BackgroundColor3 = if seen then r.OreColor else Theme.Colors.Stroke
		Theme.Corner(swatch, 8)
		swatch.Parent = f
		Theme.Label({
			Text = if seen then r.DisplayName else "???", TextSize = 16, Position = UDim2.fromOffset(22, -1),
			Size = UDim2.new(1, -22, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = if seen then (Resources.RarityColors[r.Rarity] or Theme.Colors.Text) else Theme.Colors.TextDim,
		}).Parent = f
		Theme.Label({
			Text = if seen then `{Format.Commas(count)} mined · {Format.Cash(r.Value)}` else "Undiscovered",
			TextSize = 13, FontFace = Theme.FontMedium, TextColor3 = Theme.Colors.TextDim,
			Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd,
		}).Parent = f
	end
end

local function renderAchievements(state: any)
	listLayout(6)
	-- Unlocked first, then by how close they are.
	local list = {}
	for i, a in Achievements.List do
		local ok, current, target = pcall(a.Progress, state)
		if not ok then
			current, target = 0, 1
		end
		table.insert(list, { a = a, done = state.Achievements[a.Id] ~= nil, current = current, target = target, i = i })
	end
	table.sort(list, function(x, y)
		if x.done ~= y.done then
			return x.done
		end
		local rx, ry = x.current / x.target, y.current / y.target
		if rx ~= ry then
			return rx > ry
		end
		return x.i < y.i
	end)
	for order, item in list do
		local a = item.a
		local f = row(order, 68)
		Theme.Label({
			Text = (if item.done then "★  " else "") .. a.Name, TextSize = 17, FontFace = Theme.FontHeavy,
			Size = UDim2.new(1, -110, 0, 20),
			TextColor3 = if item.done then Theme.Colors.Cash else Theme.Colors.Text,
		}).Parent = f
		Theme.Label({
			Text = a.Description, TextSize = 14, FontFace = Theme.FontMedium, TextColor3 = Theme.Colors.TextDim,
			Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, -110, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd,
		}).Parent = f
		Theme.Label({
			Text = "+" .. Format.Cash(a.Reward), TextSize = 15, TextColor3 = Theme.Colors.Cash,
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(110, 18),
			TextXAlignment = Enum.TextXAlignment.Right,
		}).Parent = f
		if not item.done then
			bar(f, item.current / item.target, Theme.Colors.Accent, UDim2.new(0, 0, 1, -6), UDim2.new(1, -110, 0, 6))
			Theme.Label({
				Text = `{Format.Commas(item.current)}/{Format.Commas(item.target)}`, TextSize = 13, FontFace = Theme.FontMedium,
				TextColor3 = Theme.Colors.TextDim, AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1),
				Size = UDim2.fromOffset(110, 16), TextXAlignment = Enum.TextXAlignment.Right,
			}).Parent = f
		end
	end
end

local function render()
	local state = StateController.State
	if not state or not isOpen then
		return
	end
	local percent = Completion.Game(state)
	overall.Text = `Game completion  {percent}%`
	TweenService:Create(overallFill, TweenInfo.new(0.3), { Size = UDim2.fromScale(percent / 100, 1) }):Play()
	for id, tab in tabs do
		tab.BackgroundColor3 = if id == selected then Theme.Colors.AccentDark else Theme.Colors.PanelLight
	end
	clear()
	content.CanvasPosition = Vector2.zero
	if selected == "Mines" then
		renderMines(state)
	elseif selected == "Collection" then
		renderCollection(state)
	else
		renderAchievements(state)
	end
end

function Journal:Toggle()
	if isOpen then
		self:Close()
	else
		self:Open()
	end
end

function Journal:Open()
	isOpen = true
	gui.Enabled = true
	render()
	window.Position = UDim2.fromScale(0.5, 0.55)
	TweenService:Create(window, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
	if UserInputService.GamepadEnabled then
		GuiService.SelectedObject = tabs[selected]
	end
end

function Journal:Close()
	isOpen = false
	gui.Enabled = false
	GuiService.SelectedObject = nil
end

function Journal:Init()
	gui = Theme.Screen("Journal", 32)
	gui.Enabled = false
	window = Theme.Panel({
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(760, 500),
		BackgroundTransparency = 0.04,
	})
	Theme.Padding(window, 18)
	window.Parent = gui

	Theme.Label({ Text = "JOURNAL", TextSize = 30, FontFace = Theme.FontHeavy, Size = UDim2.new(0.4, 0, 0, 34) }).Parent = window
	overall = Theme.Label({ Text = "", TextSize = 16, TextColor3 = Theme.Colors.Accent, Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(0.5, 0, 0, 18) })
	overall.Parent = window
	local track = Instance.new("Frame")
	track.BackgroundColor3 = Theme.Colors.PanelLight
	track.BorderSizePixel = 0
	track.Position = UDim2.fromOffset(0, 58)
	track.Size = UDim2.new(0.42, 0, 0, 8)
	Theme.Corner(track, 4)
	track.Parent = window
	overallFill = Instance.new("Frame")
	overallFill.BackgroundColor3 = Theme.Colors.Accent
	overallFill.BorderSizePixel = 0
	overallFill.Size = UDim2.fromScale(0, 1)
	Theme.Corner(overallFill, 4)
	overallFill.Parent = track

	local close = Theme.Button({ Text = "X", TextSize = 20, BackgroundColor3 = Theme.Colors.PanelLight, TextColor3 = Theme.Colors.Text,
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(40, 40) })
	close.Parent = window
	close.Activated:Connect(function()
		self:Close()
	end)

	local tabBar = Instance.new("Frame")
	tabBar.Name = "Tabs"
	tabBar.BackgroundTransparency = 1
	tabBar.AnchorPoint = Vector2.new(1, 0)
	tabBar.Position = UDim2.new(1, -50, 0, 18)
	tabBar.Size = UDim2.fromOffset(390, 40)
	tabBar.Parent = window
	local tl = Instance.new("UIListLayout")
	tl.FillDirection = Enum.FillDirection.Horizontal
	tl.HorizontalAlignment = Enum.HorizontalAlignment.Right
	tl.Padding = UDim.new(0, 6)
	tl.SortOrder = Enum.SortOrder.LayoutOrder
	tl.Parent = tabBar
	for i, id in TAB_ORDER do
		local tab = Theme.Button({ Name = id, Text = id:upper(), TextSize = 15, LayoutOrder = i,
			BackgroundColor3 = Theme.Colors.PanelLight, TextColor3 = Theme.Colors.Text, Size = UDim2.fromOffset(124, 36) })
		tab.Parent = tabBar
		tab.Activated:Connect(function()
			selected = id
			render()
		end)
		tabs[id] = tab
	end

	content = Instance.new("ScrollingFrame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.Position = UDim2.fromOffset(0, 80)
	content.Size = UDim2.new(1, 0, 1, -80)
	content.ScrollBarThickness = 6
	content.ScrollBarImageColor3 = Theme.Colors.Stroke
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.CanvasSize = UDim2.new()
	content.Parent = window

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- HUD button under the status card.
	local hud = Players.LocalPlayer.PlayerGui:WaitForChild("Hud")
	local button = Theme.Button({
		Name = "JournalButton", Text = "JOURNAL  (J)", TextSize = 15, BackgroundColor3 = Theme.Colors.Panel,
		TextColor3 = Theme.Colors.Text, Position = UDim2.fromOffset(14, 122), Size = UDim2.fromOffset(150, 34),
	})
	Theme.Stroke(button, nil, 1.5, 0.2)
	button.Parent = hud
	button.Activated:Connect(function()
		self:Toggle()
	end)

	StateController.Changed:Connect(function()
		if isOpen then
			render()
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed and input.KeyCode ~= Enum.KeyCode.ButtonY then
			return
		end
		if input.KeyCode == Enum.KeyCode.J or input.KeyCode == Enum.KeyCode.ButtonY then
			self:Toggle()
		elseif isOpen and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) then
			self:Close()
		end
	end)
end

return Journal
