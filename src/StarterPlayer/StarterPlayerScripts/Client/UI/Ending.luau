--!strict
-- Shown once when the player completes the final mine: a full-screen card
-- with their run's numbers, then back to mining.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Artifacts = require(Shared.Config.Artifacts)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)

local Theme = require(script.Parent.Theme)
local PrestigeDialog = require(script.Parent.PrestigeDialog)
local StateController = require(script.Parent.Parent.Controllers.StateController)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)

local Ending = {}

local gui: ScreenGui
local backdrop: Frame
local panel: CanvasGroup
local statsLabel: TextLabel

local function show()
	local state = StateController.State
	if state then
		local found, total = Artifacts.CountIn(state.Artifacts)
		statsLabel.Text = table.concat({
			`Total earned  <font color="#FFD05C">{Format.Cash(state.Stats.TotalEarned)}</font>`,
			`Ore mined  <font color="#F2A63A">{Format.Commas(state.Stats.TotalMined)}</font>`,
			`Creatures defeated  <font color="#C080FF">{Format.Commas(state.Stats.CreaturesDefeated or 0)}</font>`,
			`Artifacts  <font color="#96DCD2">{found}/{total}</font>`,
		}, "\n")
	end
	SoundController:Play("Ending")
	gui.Enabled = true
	backdrop.BackgroundTransparency = 1
	panel.GroupTransparency = 1
	TweenService:Create(backdrop, TweenInfo.new(1.5), { BackgroundTransparency = 0.25 }):Play()
	TweenService:Create(panel, TweenInfo.new(2, Enum.EasingStyle.Sine), { GroupTransparency = 0 }):Play()
end

function Ending:Init()
	gui = Theme.Screen("Ending", 90)
	gui.IgnoreGuiInset = true
	gui.Enabled = false
	backdrop = Instance.new("Frame")
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BorderSizePixel = 0
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.Parent = gui

	panel = Instance.new("CanvasGroup")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(620, 420)
	panel.BackgroundTransparency = 1
	panel.Parent = gui

	local over = Theme.Label({ Text = "YOU REACHED", TextSize = 20, TextColor3 = Theme.Colors.Accent,
		Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Center })
	over.Parent = panel
	local title = Theme.Label({ Text = "THE HEART OF THE WORLD", TextSize = 48, FontFace = Theme.FontHeavy,
		Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 56), TextXAlignment = Enum.TextXAlignment.Center })
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(120, 60, 200)
	stroke.Parent = title
	title.Parent = panel
	local sub = Theme.Label({
		Text = "Every depth is yours. The Origin waits beyond the seal.\nCollapse the mines to start again stronger, now or later at camp.",
		TextSize = 18, FontFace = Theme.FontMedium, TextColor3 = Theme.Colors.TextDim, TextWrapped = true,
		Position = UDim2.fromOffset(0, 96), Size = UDim2.new(1, 0, 0, 50), TextXAlignment = Enum.TextXAlignment.Center,
	})
	sub.Parent = panel
	statsLabel = Theme.Label({ Text = "", RichText = true, TextSize = 22, Position = UDim2.fromOffset(0, 170),
		Size = UDim2.new(1, 0, 0, 130), TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top })
	statsLabel.Parent = panel
	local function hide()
		TweenService:Create(backdrop, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(panel, TweenInfo.new(0.6), { GroupTransparency = 1 }):Play()
		task.delay(0.6, function()
			gui.Enabled = false
		end)
	end
	local keep = Theme.Button({ Name = "Keep", Text = "KEEP MINING", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(0.5, -8, 1, 0),
		Size = UDim2.fromOffset(260, 54) })
	keep.Parent = panel
	keep.Activated:Connect(hide)
	local collapse = Theme.Button({ Name = "Collapse", Text = "COLLAPSE THE MINES", AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0.5, 8, 1, 0), Size = UDim2.fromOffset(260, 54), BackgroundColor3 = Color3.fromRGB(150, 80, 230),
		TextColor3 = Theme.Colors.Text })
	collapse.Parent = panel
	collapse.Activated:Connect(function()
		hide()
		PrestigeDialog:Open()
	end)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	Remotes.Event("Ending").OnClientEvent:Connect(show)
end

return Ending
