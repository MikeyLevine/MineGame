--!strict
-- Confirmation window for prestige ("Collapse the Mines"). Opened from the
-- camp monument (server fires OpenPrestige) or the ending screen. Lists
-- exactly what is kept, what is lost and what is gained before the player
-- commits; the server re-checks eligibility.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Mines = require(Shared.Config.Mines)
local Modifiers = require(Shared.Modifiers)
local Skins = require(Shared.Config.Skins)
local Remotes = require(Shared.Remotes)

local Theme = require(script.Parent.Theme)
local Toasts = require(script.Parent.Toasts)
local StateController = require(script.Parent.Parent.Controllers.StateController)

local PrestigeDialog = {}

local gui: ScreenGui
local title: TextLabel
local gainLabel: TextLabel
local confirm: TextButton
local closeButton: TextButton
local busy = false

local function endingMine(): string?
	for id, mine in Mines.ById do
		if (mine :: any).Ending then
			return id
		end
	end
	return nil
end

local function eligible(state: StateController.State): boolean
	local id = endingMine()
	local record = id and state.Mines[id]
	return record ~= nil and record.Completed == true
end

local function pct(multiplier: number): string
	return `+{math.floor((multiplier - 1) * 100 + 0.5)}%`
end

local function refresh()
	local state = StateController.State
	if not state then
		return
	end
	local current = state.Prestige or 0
	local nextLevel = current + 1
	title.Text = `PRESTIGE {nextLevel}`
	local lines = {
		`<font color="#76CC70">GAIN</font>  Sell value {pct(Modifiers.PRESTIGE_SELL ^ nextLevel)}, mining power {pct(Modifiers.PRESTIGE_POWER ^ nextLevel)} (permanent)`,
	}
	for _, skin in Skins.List do
		if skin.Source == "Prestige" and skin.Requires == nextLevel then
			table.insert(lines, `<font color="#76CC70">GAIN</font>  The {skin.Name} pickaxe skin`)
		end
	end
	table.insert(lines, `<font color="#96DCD2">KEEP</font>  Artifacts, achievements, stats, pets, skins, game passes, boosts and settings`)
	table.insert(lines, `<font color="#E25448">LOSE</font>  All cash, your backpack contents, every tool and equipment tier, opened gates and mine completion`)
	table.insert(lines, `<font color="#B0A494">NOTE</font>  Upgrades cost {pct(Modifiers.PRESTIGE_PRICE ^ nextLevel)} more at this level`)
	gainLabel.Text = table.concat(lines, "\n\n")

	local ok = eligible(state)
	confirm.Active = ok
	confirm.Text = if ok then "COLLAPSE THE MINES" else "COMPLETE THE WORLDHEART FIRST"
	confirm.BackgroundColor3 = if ok then Color3.fromRGB(150, 80, 230) else Theme.Colors.Stroke
	confirm.TextColor3 = if ok then Theme.Colors.Text else Theme.Colors.TextDim
end

function PrestigeDialog:Open()
	refresh()
	gui.Enabled = true
	if UserInputService.GamepadEnabled then
		-- Start on Close so a stray A press can't wipe a run.
		GuiService.SelectedObject = closeButton
	end
end

function PrestigeDialog:Close()
	gui.Enabled = false
	GuiService.SelectedObject = nil
end

function PrestigeDialog:Init()
	gui = Theme.Screen("PrestigeDialog", 95)
	gui.Enabled = false
	local window = Theme.Panel({ Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(560, 430), BackgroundTransparency = 0.03 })
	Theme.Padding(window, 20)
	window.Parent = gui
	Theme.Stroke(window, Color3.fromRGB(150, 80, 230), 2, 0.1)

	Theme.Label({ Text = "COLLAPSE THE MINES", TextSize = 16, TextColor3 = Color3.fromRGB(190, 140, 255),
		Size = UDim2.new(1, -50, 0, 20) }).Parent = window
	title = Theme.Label({ Text = "PRESTIGE 1", TextSize = 36, FontFace = Theme.FontHeavy, Position = UDim2.fromOffset(0, 20),
		Size = UDim2.new(1, -50, 0, 40) })
	title.Parent = window
	local close = Theme.Button({ Name = "Close", Text = "X", TextSize = 20, BackgroundColor3 = Theme.Colors.PanelLight,
		TextColor3 = Theme.Colors.Text, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(40, 40) })
	close.Parent = window
	closeButton = close
	close.Activated:Connect(function()
		PrestigeDialog:Close()
	end)

	Theme.Label({
		Text = "The deep collapses behind you and you start again from the coal mine: stronger, richer, and with new rewards to chase.",
		TextSize = 16, FontFace = Theme.FontMedium, TextColor3 = Theme.Colors.TextDim, TextWrapped = true,
		Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 0, 40),
	}).Parent = window

	gainLabel = Theme.Label({ Name = "Details", Text = "", RichText = true, TextSize = 17, TextWrapped = true,
		Position = UDim2.fromOffset(0, 116), Size = UDim2.new(1, 0, 0, 220), TextYAlignment = Enum.TextYAlignment.Top })
	gainLabel.Parent = window

	confirm = Theme.Button({ Name = "Confirm", Text = "COLLAPSE THE MINES", AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.new(1, 0, 0, 54) })
	confirm.Parent = window
	confirm.Activated:Connect(function()
		if busy or not confirm.Active then
			return
		end
		busy = true
		local ok, result, message = pcall(function()
			return Remotes.Function("Prestige"):InvokeServer()
		end)
		busy = false
		if ok and result then
			PrestigeDialog:Close()
		else
			Toasts:Notify(if ok and message then message else "Prestige failed, try again", "Warn")
		end
	end)

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	UserInputService.InputBegan:Connect(function(input, processed)
		if gui.Enabled and (input.KeyCode == Enum.KeyCode.ButtonB or (not processed and input.KeyCode == Enum.KeyCode.Escape)) then
			PrestigeDialog:Close()
		end
	end)
	Remotes.Event("OpenPrestige").OnClientEvent:Connect(function()
		PrestigeDialog:Open()
	end)
	StateController:Observe(function()
		if gui.Enabled then
			refresh()
		end
	end)
end

return PrestigeDialog
