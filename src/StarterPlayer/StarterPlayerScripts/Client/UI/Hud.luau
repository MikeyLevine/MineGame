--!strict
-- Always-on HUD: cash + pickaxe (top-left), backpack bar (bottom-center),
-- and a small "not saving" warning when DataStores are unavailable.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Equipment = require(Shared.Config.Equipment)
local Artifacts = require(Shared.Config.Artifacts)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)
local Store = require(Shared.Config.Store)

local Theme = require(script.Parent.Theme)
local StateController = require(script.Parent.Parent.Controllers.StateController)

local Hud = {}

local cashLabel: TextLabel
local pickaxeLabel: TextLabel
local artifactLabel: TextLabel
local bagFill: Frame
local bagText: TextLabel
local bagHint: TextLabel
local bagFrame: Frame
local saveWarning: TextLabel
local prestigeLabel: TextLabel
local sellButton: TextButton
local boostList: Frame
local boostChips: { [string]: TextLabel } = {}
local selling = false
local shownCash = 0
local cashValue: NumberValue

local function build(gui: ScreenGui)
	-- Cash + pickaxe card
	local card = Theme.Panel({
		Name = "Status",
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.fromOffset(230, 104),
	})
	Theme.Padding(card, 10)
	card.Parent = gui

	local coin = Instance.new("Frame")
	coin.Size = UDim2.fromOffset(30, 30)
	coin.Position = UDim2.fromOffset(2, 2)
	coin.BackgroundColor3 = Theme.Colors.Cash
	Theme.Corner(coin, 15)
	Theme.Stroke(coin, Color3.fromRGB(150, 100, 20), 2)
	coin.Parent = card
	local coinMark = Theme.Label({
		Text = "$",
		TextSize = 20,
		FontFace = Theme.FontHeavy,
		TextColor3 = Color3.fromRGB(120, 76, 10),
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	coinMark.Parent = coin

	cashLabel = Theme.Label({
		Name = "Cash",
		Text = "$0",
		TextSize = 30,
		FontFace = Theme.FontHeavy,
		TextColor3 = Theme.Colors.Cash,
		Position = UDim2.fromOffset(42, 0),
		Size = UDim2.new(1, -42, 0, 34),
	})
	cashLabel.Parent = card

	pickaxeLabel = Theme.Label({
		Name = "Pickaxe",
		Text = "Rusty Pickaxe",
		TextSize = 17,
		FontFace = Theme.FontMedium,
		TextColor3 = Theme.Colors.TextDim,
		Position = UDim2.fromOffset(2, 40),
		Size = UDim2.new(1, -2, 0, 22),
	})
	pickaxeLabel.Parent = card

	artifactLabel = Theme.Label({
		Name = "Artifacts",
		Text = "",
		TextSize = 15,
		FontFace = Theme.FontMedium,
		TextColor3 = Color3.fromRGB(150, 220, 210),
		Position = UDim2.fromOffset(2, 62),
		Size = UDim2.new(1, -2, 0, 20),
	})
	artifactLabel.Parent = card

	prestigeLabel = Theme.Label({
		Name = "Prestige",
		Text = "",
		TextSize = 14,
		FontFace = Theme.FontHeavy,
		TextColor3 = Color3.fromRGB(190, 140, 255),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 62),
		Size = UDim2.fromOffset(100, 20),
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	prestigeLabel.Parent = card

	-- Backpack bar
	bagFrame = Theme.Panel({
		Name = "Backpack",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -84),
		Size = UDim2.fromOffset(340, 40),
	})
	bagFrame.Parent = gui

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.BackgroundColor3 = Theme.Colors.PanelLight
	track.BorderSizePixel = 0
	track.Position = UDim2.fromOffset(6, 6)
	track.Size = UDim2.new(1, -12, 1, -12)
	Theme.Corner(track, 7)
	track.Parent = bagFrame

	bagFill = Instance.new("Frame")
	bagFill.Name = "Fill"
	bagFill.BackgroundColor3 = Theme.Colors.Accent
	bagFill.BorderSizePixel = 0
	bagFill.Size = UDim2.fromScale(0, 1)
	Theme.Corner(bagFill, 7)
	bagFill.Parent = track

	bagText = Theme.Label({
		Name = "Text",
		Text = "BACKPACK 0 / 15",
		TextSize = 18,
		FontFace = Theme.FontHeavy,
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 2,
	})
	local textStroke = Instance.new("UIStroke")
	textStroke.Thickness = 1.5
	textStroke.Transparency = 0.4
	textStroke.Parent = bagText
	bagText.Parent = track

	bagHint = Theme.Label({
		Name = "Hint",
		Text = "Backpack full! Head back up to camp and sell.",
		TextSize = 18,
		TextColor3 = Theme.Colors.Bad,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -4),
		Size = UDim2.fromOffset(460, 22),
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
	})
	local hintStroke = Instance.new("UIStroke")
	hintStroke.Thickness = 1.5
	hintStroke.Transparency = 0.3
	hintStroke.Parent = bagHint
	bagHint.Parent = bagFrame

	-- Remote Seller pass: sell from anywhere.
	sellButton = Theme.Button({
		Name = "RemoteSell",
		Text = "SELL",
		TextSize = 18,
		BackgroundColor3 = Theme.Colors.Good,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(0, -8, 0, 0),
		Size = UDim2.fromOffset(78, 40),
		Visible = false,
	})
	sellButton.Parent = bagFrame
	sellButton.Activated:Connect(function()
		if selling then
			return
		end
		selling = true
		pcall(function()
			Remotes.Function("RemoteSell"):InvokeServer()
		end)
		task.wait(0.5)
		selling = false
	end)

	-- Active boost timers, under the event chip.
	boostList = Instance.new("Frame")
	boostList.Name = "Boosts"
	boostList.BackgroundTransparency = 1
	boostList.Position = UDim2.fromOffset(14, 202)
	boostList.Size = UDim2.fromOffset(230, 120)
	boostList.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = boostList

	saveWarning = Theme.Label({
		Name = "SaveWarning",
		Text = "Progress is not being saved (no DataStore access)",
		TextSize = 14,
		TextColor3 = Theme.Colors.Bad,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, -10),
		Size = UDim2.fromOffset(360, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		Visible = false,
	})
	saveWarning.Parent = gui
end

local function render(state: StateController.State, previous: StateController.State?)
	local pickaxe = Equipment.Pickaxes[state.PickaxeTier]
	pickaxeLabel.Text = "⛏  " .. pickaxe.Name
	local found, total = Artifacts.CountIn(state.Artifacts)
	artifactLabel.Text = `◆  Artifacts {found}/{total}`

	local used, capacity = StateController:Used(), StateController:Capacity()
	local ratio = if capacity > 0 then math.clamp(used / capacity, 0, 1) else 0
	TweenService:Create(bagFill, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(ratio, 1) }):Play()
	bagText.Text = `BACKPACK  {used} / {capacity}`
	local full = used >= capacity
	bagFill.BackgroundColor3 = if full then Theme.Colors.Bad elseif ratio > 0.75 then Color3.fromRGB(240, 200, 70) else Theme.Colors.Accent
	bagHint.Visible = full

	local previousBackpack = previous and Equipment.Backpacks[previous.BackpackTier]
	if previousBackpack and capacity ~= previousBackpack.Capacity then
		bagFrame.Size = UDim2.fromOffset(380, 44)
		TweenService:Create(bagFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(340, 40) }):Play()
	end

	TweenService:Create(cashValue, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Value = state.Cash }):Play()
	if previous and state.Cash > previous.Cash then
		cashLabel.TextSize = 36
		TweenService:Create(cashLabel, TweenInfo.new(0.35, Enum.EasingStyle.Back), { TextSize = 30 }):Play()
	end

	local level = state.Prestige or 0
	local vip = StateController:HasPass("VIP")
	prestigeLabel.Text = (if vip then `<font color="#FFC846">VIP</font>  ` else "") .. (if level > 0 then `PRESTIGE {level}` else "")
	prestigeLabel.RichText = true

	saveWarning.Visible = not state.Saving
end

local function clock(seconds: number): string
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function renderBoosts()
	local state = StateController.State
	local now = os.time()
	for order, boost in Store.Boosts do
		local ends = state and state.Boosts and state.Boosts[boost.Id]
		local left = if type(ends) == "number" then ends - now else 0
		local chip = boostChips[boost.Id]
		if left > 0 then
			if not chip then
				local panel = Theme.Panel({ Name = boost.Id, LayoutOrder = order, Size = UDim2.fromOffset(230, 28) })
				local stroke = panel:FindFirstChildOfClass("UIStroke")
				if stroke then
					stroke.Color = boost.Color
				end
				panel.Parent = boostList
				chip = Theme.Label({ Name = "Text", TextSize = 15, TextColor3 = boost.Color, Position = UDim2.fromOffset(10, 0),
					Size = UDim2.new(1, -20, 1, 0) })
				chip.Parent = panel
				boostChips[boost.Id] = chip
			end
			chip.Text = `{boost.Name}  {clock(left)}`
		elseif chip then
			(chip.Parent :: Instance):Destroy()
			boostChips[boost.Id] = nil
		end
	end
end

local function refreshPasses()
	sellButton.Visible = StateController:HasPass("RemoteSell")
	if StateController.State then
		render(StateController.State, nil)
	end
end

function Hud:Init()
	local gui = Theme.Screen("Hud", 10)
	cashValue = Instance.new("NumberValue")
	cashValue.Changed:Connect(function(v)
		shownCash = math.floor(v + 0.5)
		cashLabel.Text = Format.Cash(shownCash)
	end)
	build(gui)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	StateController:Observe(render)
	StateController:Observe(renderBoosts)
	refreshPasses()
	Players.LocalPlayer.AttributeChanged:Connect(function(name)
		if string.sub(name, 1, 5) == "Pass_" then
			refreshPasses()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			renderBoosts()
		end
	end)
end

return Hud
