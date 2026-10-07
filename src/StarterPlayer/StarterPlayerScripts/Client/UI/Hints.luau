--!strict
-- One contextual tip at a time for new players (bottom-left). Each hint has
-- a condition on the player's state; the first matching, undismissed hint is
-- shown. Players can dismiss tips, or turn hints off in Settings.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Equipment = require(Shared.Config.Equipment)
local Format = require(Shared.Util.Format)
local Modifiers = require(Shared.Modifiers)

local Theme = require(script.Parent.Theme)
local Settings = require(script.Parent.Settings)
local StateController = require(script.Parent.Parent.Controllers.StateController)

local Hints = {}

type Hint = { Id: string, When: (any) -> boolean, Text: (any) -> string }

local player = Players.LocalPlayer
local dismissed: { [string]: boolean } = {}
local panel: Frame
local label: TextLabel
local currentId: string? = nil

local function mineVerb(): string
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Tap"
	elseif UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		return "Hold R2 near"
	end
	return "Click (or hold) on"
end

local function holdingPickaxe(): boolean
	local character = player.Character
	return character ~= nil and character:FindFirstChild("Pickaxe") ~= nil
end

local HINTS: { Hint } = {
	{
		Id = "Equip",
		When = function(s)
			return s.Stats.TotalMined == 0 and not holdingPickaxe()
		end,
		Text = function()
			return "Equip your pickaxe from the toolbar, then head into the mine entrance."
		end,
	},
	{
		Id = "Mine",
		When = function(s)
			return s.Stats.TotalMined == 0
		end,
		Text = function()
			return `{mineVerb()} a rock to mine it. Ore goes into your backpack.`
		end,
	},
	{
		Id = "Sell",
		When = function(s)
			return s.Stats.TotalEarned == 0 and s.Stats.TotalMined >= 5
		end,
		Text = function()
			return "Got some ore? Walk back to camp and sell it at the Ore Buyer."
		end,
	},
	{
		Id = "Upgrade",
		When = function(s)
			local nextPick = Equipment.Pickaxes[s.PickaxeTier + 1]
			return s.PickaxeTier <= 2 and nextPick ~= nil and s.Cash >= Modifiers.Price(nextPick.Price, s)
		end,
		Text = function(s)
			local nextPick = Equipment.Pickaxes[s.PickaxeTier + 1]
			return `You can afford the {nextPick.Name} ({Format.Cash(Modifiers.Price(nextPick.Price, s))})! Visit the Upgrade Bench at camp.`
		end,
	},
	{
		Id = "Rubble",
		When = function(s)
			return s.PickaxeTier >= 2 and not s.Gates.CopperGate
		end,
		Text = function()
			return "Your new pickaxe can break the cave-in below the Upper Tunnels. Copper lies beyond!"
		end,
	},
	{
		Id = "Journal",
		When = function(s)
			return s.Mines.Mine1 ~= nil and s.Mines.Mine1.Completed == true
		end,
		Text = function()
			return "Open your Journal (J) to track every mine, secret and achievement."
		end,
	},
}

local function show(text: string)
	label.Text = "TIP  ·  " .. text
	if not panel.Visible then
		panel.Visible = true
		panel.Position = UDim2.new(0, 14, 1, -36)
		TweenService:Create(panel, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Position = UDim2.new(0, 14, 1, -44) }):Play()
	end
end

local function refresh()
	local state = StateController.State
	local settings = Settings:Get()
	if not state or not settings.Hints then
		panel.Visible = false
		currentId = nil
		return
	end
	for _, hint in HINTS do
		if not dismissed[hint.Id] and hint.When(state) then
			currentId = hint.Id
			show(hint.Text(state))
			return
		end
	end
	currentId = nil
	panel.Visible = false
end

function Hints:Init()
	local gui = Theme.Screen("Hints", 15)
	panel = Theme.Panel({ Name = "Tip", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -44),
		Size = UDim2.fromOffset(420, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = false })
	local stroke = panel:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = Theme.Colors.Accent
	end
	Theme.Padding(panel, 12)
	panel.Parent = gui
	label = Theme.Label({ Text = "", TextSize = 17, FontFace = Theme.FontMedium, TextWrapped = true,
		Size = UDim2.new(1, -34, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
	label.Parent = panel
	local close = Theme.Button({ Name = "Dismiss", Text = "X", TextSize = 14, BackgroundColor3 = Theme.Colors.PanelLight,
		TextColor3 = Theme.Colors.TextDim, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(26, 26) })
	close.Parent = panel
	close.Activated:Connect(function()
		if currentId then
			dismissed[currentId] = true
		end
		refresh()
	end)
	gui.Parent = player:WaitForChild("PlayerGui")

	StateController.Changed:Connect(refresh)
	Settings.Changed.Event:Connect(refresh)
	-- Equipping the pickaxe changes which hint applies.
	local function watchCharacter(character: Model)
		character.ChildAdded:Connect(refresh)
		character.ChildRemoved:Connect(refresh)
	end
	if player.Character then
		watchCharacter(player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)
	refresh()
end

return Hints
