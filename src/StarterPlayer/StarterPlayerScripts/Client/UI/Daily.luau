--!strict
-- Daily rewards calendar: seven tiles for the current streak week, a claim
-- button, and a countdown to the next reward. Opens itself on join when a
-- reward is waiting (server fires OpenDaily). The server decides everything.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Daily = require(Shared.Config.Daily)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)
local Store = require(Shared.Config.Store)

local Theme = require(script.Parent.Theme)
local Toasts = require(script.Parent.Toasts)
local StateController = require(script.Parent.Parent.Controllers.StateController)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)

local DailyUI = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local tiles: { Frame } = {}
local claimButton: TextButton
local timerLabel: TextLabel
local hudDot: Frame
local busy = false

-- Server time, so the countdown matches the server's day boundary.
local function now(): number
	return math.floor(Workspace:GetServerTimeNow())
end

local function render()
	local state = StateController.State
	if not state then
		return
	end
	local t = now()
	local canClaim = Daily.CanClaim(state, t)
	local current = if canClaim
		then Daily.NextDay(state, t)
		else ((math.max(state.Daily and state.Daily.Streak or 1, 1) - 1) % Daily.Days) + 1
	hudDot.Visible = canClaim

	for day, tile in tiles do
		local reward = Daily.Reward(day, state)
		local done = day < current or (not canClaim and day == current)
		local isToday = canClaim and day == current
		local cash = tile:FindFirstChild("Cash") :: TextLabel
		local extra = tile:FindFirstChild("Extra") :: TextLabel
		local check = tile:FindFirstChild("Check") :: TextLabel
		cash.Text = Format.Cash(reward.Cash)
		local boost = reward.Boost and Store.GetBoost(reward.Boost)
		extra.Text = if boost and reward.BoostSeconds then `+ {boost.Name} {reward.BoostSeconds // 60}m` else ""
		extra.TextColor3 = if boost then boost.Color else Theme.Colors.TextDim
		check.Visible = done
		tile.BackgroundColor3 = if isToday then Theme.Colors.AccentDark elseif done then Theme.Colors.Panel else Theme.Colors.PanelLight
		local stroke = tile:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = if isToday then Theme.Colors.Accent else Theme.Colors.Stroke
			stroke.Thickness = if isToday then 2.5 else 1
		end
	end

	claimButton.Active = canClaim and not busy
	claimButton.AutoButtonColor = canClaim
	claimButton.BackgroundColor3 = if canClaim then Theme.Colors.Accent else Theme.Colors.Stroke
	claimButton.TextColor3 = if canClaim then Color3.fromRGB(30, 20, 10) else Theme.Colors.TextDim
	claimButton.Text = if canClaim then `CLAIM DAY {current}` else "CLAIMED"
	local left = Daily.SecondsUntilReset(t)
	timerLabel.Text = if canClaim
		then "Miss a day and the streak starts over."
		else string.format("Next reward in %d:%02d:%02d", left // 3600, (left % 3600) // 60, left % 60)
end

function DailyUI:Open()
	gui.Enabled = true
	render()
	if UserInputService.GamepadEnabled then
		GuiService.SelectedObject = claimButton
	end
end

function DailyUI:Close()
	gui.Enabled = false
	GuiService.SelectedObject = nil
end

function DailyUI:Toggle()
	if gui.Enabled then
		self:Close()
	else
		self:Open()
	end
end

function DailyUI:Init()
	gui = Theme.Screen("Daily", 36)
	gui.Enabled = false
	local window = Theme.Panel({ Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(640, 300), BackgroundTransparency = 0.04 })
	Theme.Padding(window, 18)
	window.Parent = gui
	Theme.Label({ Text = "DAILY REWARDS", TextSize = 30, FontFace = Theme.FontHeavy, Size = UDim2.new(1, -50, 0, 34) }).Parent = window
	local close = Theme.Button({ Name = "Close", Text = "X", TextSize = 20, BackgroundColor3 = Theme.Colors.PanelLight,
		TextColor3 = Theme.Colors.Text, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(40, 40) })
	close.Parent = window
	close.Activated:Connect(function()
		DailyUI:Close()
	end)

	local row = Instance.new("Frame")
	row.Name = "Days"
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(0, 50)
	row.Size = UDim2.new(1, 0, 0, 120)
	row.Parent = window
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
	for day = 1, Daily.Days do
		local tile = Instance.new("Frame")
		tile.Name = "Day" .. day
		tile.LayoutOrder = day
		tile.BorderSizePixel = 0
		tile.Size = UDim2.new(1 / Daily.Days, -6, 1, 0)
		Theme.Corner(tile, 8)
		Theme.Stroke(tile, nil, 1, 0)
		tile.Parent = row
		Theme.Label({ Name = "Day", Text = if day == Daily.Days then "BIG DAY 7" else `DAY {day}`, TextSize = 14,
			FontFace = Theme.FontHeavy, TextColor3 = Theme.Colors.TextDim, Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 18),
			TextXAlignment = Enum.TextXAlignment.Center }).Parent = tile
		Theme.Label({ Name = "Cash", Text = "", TextSize = 16, FontFace = Theme.FontHeavy, TextColor3 = Theme.Colors.Cash,
			TextScaled = true, Position = UDim2.new(0, 4, 0, 36), Size = UDim2.new(1, -8, 0, 22),
			TextXAlignment = Enum.TextXAlignment.Center }).Parent = tile
		Theme.Label({ Name = "Extra", Text = "", TextSize = 12, FontFace = Theme.FontMedium, TextWrapped = true,
			Position = UDim2.new(0, 4, 0, 62), Size = UDim2.new(1, -8, 0, 30), TextXAlignment = Enum.TextXAlignment.Center }).Parent = tile
		Theme.Label({ Name = "Check", Text = "CLAIMED", TextSize = 12, FontFace = Theme.FontHeavy, TextColor3 = Theme.Colors.Good,
			AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -6), Size = UDim2.new(1, 0, 0, 16),
			TextXAlignment = Enum.TextXAlignment.Center, Visible = false }).Parent = tile
		tiles[day] = tile
	end

	claimButton = Theme.Button({ Name = "Claim", Text = "CLAIM", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -22),
		Size = UDim2.fromOffset(260, 50) })
	claimButton.Parent = window
	timerLabel = Theme.Label({ Name = "Timer", Text = "", TextSize = 14, FontFace = Theme.FontMedium, TextColor3 = Theme.Colors.TextDim,
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Center })
	timerLabel.Parent = window

	claimButton.Activated:Connect(function()
		if busy or not claimButton.Active then
			return
		end
		busy = true
		local ok, success, message = pcall(function()
			return Remotes.Function("ClaimDaily"):InvokeServer()
		end)
		busy = false
		if ok and success then
			SoundController:Play("Sell")
			Toasts:Notify(message, "Good")
		else
			Toasts:Notify(if ok and message then message else "Couldn't claim, try again", "Warn")
		end
		render()
	end)

	gui.Parent = player:WaitForChild("PlayerGui")

	-- HUD button with a dot when a reward is waiting.
	local hud = player.PlayerGui:WaitForChild("Hud")
	local open = Theme.Button({ Name = "DailyButton", Text = "DAILY", TextSize = 15, BackgroundColor3 = Theme.Colors.Panel,
		TextColor3 = Theme.Colors.Text, Position = UDim2.fromOffset(326, 122), Size = UDim2.fromOffset(74, 34) })
	Theme.Stroke(open, nil, 1.5, 0.2)
	open.Parent = hud
	hudDot = Instance.new("Frame")
	hudDot.Name = "Dot"
	hudDot.AnchorPoint = Vector2.new(0.5, 0.5)
	hudDot.Position = UDim2.new(1, -4, 0, 4)
	hudDot.Size = UDim2.fromOffset(12, 12)
	hudDot.BackgroundColor3 = Theme.Colors.Bad
	hudDot.Visible = false
	Theme.Corner(hudDot, 6)
	hudDot.Parent = open
	open.Activated:Connect(function()
		DailyUI:Toggle()
	end)

	Remotes.Event("OpenDaily").OnClientEvent:Connect(function()
		DailyUI:Open()
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if gui.Enabled and (input.KeyCode == Enum.KeyCode.ButtonB or (not processed and input.KeyCode == Enum.KeyCode.Escape)) then
			DailyUI:Close()
		elseif not processed and input.KeyCode == Enum.KeyCode.DPadRight then
			DailyUI:Toggle()
		end
	end)
	StateController:Observe(function()
		render()
	end)
	-- Countdown tick, and the dot lights up again at midnight.
	task.spawn(function()
		while true do
			task.wait(1)
			if gui.Enabled or not hudDot.Visible then
				render()
			end
		end
	end)
end

return DailyUI
