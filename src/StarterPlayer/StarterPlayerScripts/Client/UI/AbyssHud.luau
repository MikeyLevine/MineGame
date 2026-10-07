--!strict
-- Endless Abyss panel (top right, in place of the mine objectives while in
-- the Abyss): floor, band, best floor and Descent Shaft progress. Driven by
-- the AbyssFloor/AbyssMined/AbyssQuota/AbyssOpen player attributes the
-- server sets.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Abyss = require(Shared.Config.Abyss)

local Theme = require(script.Parent.Theme)
local StateController = require(script.Parent.Parent.Controllers.StateController)

local AbyssHud = {}

local player = Players.LocalPlayer
local panel: Frame
local floorLabel: TextLabel
local bandLabel: TextLabel
local bestLabel: TextLabel
local fill: Frame
local shaftLabel: TextLabel

local function render()
	local floor = (player:GetAttribute("AbyssFloor") :: number?) or 0
	local inAbyss = floor > 0
	panel.Visible = inAbyss
	local objectives = player.PlayerGui:FindFirstChild("Objectives") :: ScreenGui?
	if objectives then
		objectives.Enabled = not inAbyss
	end
	if not inAbyss then
		return
	end
	local band = Abyss.BandFor(floor)
	local mined = (player:GetAttribute("AbyssMined") :: number?) or 0
	local quota = math.max(1, (player:GetAttribute("AbyssQuota") :: number?) or 1)
	local open = player:GetAttribute("AbyssOpen") == true
	local state = StateController.State
	local best = state and state.Abyss and state.Abyss.Best or 0

	floorLabel.Text = `FLOOR {floor}`
	bandLabel.Text = band.Name:upper()
	bandLabel.TextColor3 = band.Glow
	bestLabel.Text = if floor >= best then "DEEPEST YET" else `Best: floor {best}`
	bestLabel.TextColor3 = if floor >= best then Theme.Colors.Good else Theme.Colors.TextDim
	TweenService:Create(fill, TweenInfo.new(0.25), { Size = UDim2.fromScale(math.clamp(mined / quota, 0, 1), 1) }):Play()
	fill.BackgroundColor3 = if open then band.Glow else Theme.Colors.Accent
	shaftLabel.Text = if open
		then "Descent Shaft OPEN: find it in the deepest chamber"
		else `Mine ore to open the shaft  {mined}/{quota}`
end

function AbyssHud:Init()
	local gui = Theme.Screen("AbyssHud", 11)
	panel = Theme.Panel({
		Name = "Panel",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 10),
		Size = UDim2.fromOffset(270, 118),
		Visible = false,
	})
	Theme.Padding(panel, 10)
	panel.Parent = gui

	bandLabel = Theme.Label({ Name = "Band", Text = "", TextSize = 14, Size = UDim2.new(1, 0, 0, 18) })
	bandLabel.Parent = panel
	floorLabel = Theme.Label({ Name = "Floor", Text = "", TextSize = 26, FontFace = Theme.FontHeavy, Position = UDim2.fromOffset(0, 16),
		Size = UDim2.new(1, 0, 0, 30) })
	floorLabel.Parent = panel
	bestLabel = Theme.Label({ Name = "Best", Text = "", TextSize = 14, FontFace = Theme.FontHeavy, AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 24), Size = UDim2.fromOffset(120, 18), TextXAlignment = Enum.TextXAlignment.Right })
	bestLabel.Parent = panel

	local track = Instance.new("Frame")
	track.BackgroundColor3 = Theme.Colors.PanelLight
	track.BorderSizePixel = 0
	track.Position = UDim2.fromOffset(0, 54)
	track.Size = UDim2.new(1, 0, 0, 8)
	Theme.Corner(track, 4)
	track.Parent = panel
	fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	Theme.Corner(fill, 4)
	fill.Parent = track

	shaftLabel = Theme.Label({ Name = "Shaft", Text = "", TextSize = 14, FontFace = Theme.FontMedium, TextWrapped = true,
		Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 0, 32), TextYAlignment = Enum.TextYAlignment.Top })
	shaftLabel.Parent = panel

	gui.Parent = player:WaitForChild("PlayerGui")
	for _, name in { "AbyssFloor", "AbyssMined", "AbyssQuota", "AbyssOpen" } do
		player:GetAttributeChangedSignal(name):Connect(render)
	end
	StateController:Observe(function()
		render()
	end)
	render()
end

return AbyssHud
