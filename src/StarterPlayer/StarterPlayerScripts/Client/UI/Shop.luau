--!strict
-- Upgrade bench window: equipment categories on the left, the selected
-- category's next upgrade on the right. Opened by the server when the bench
-- prompt is used; purchases go through the Purchase RemoteFunction (the
-- server validates price, requirements and distance).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Equipment = require(Shared.Config.Equipment)
local Format = require(Shared.Util.Format)
local Mines = require(Shared.Config.Mines)
local Modifiers = require(Shared.Modifiers)
local Remotes = require(Shared.Remotes)

local Theme = require(script.Parent.Theme)
local Toasts = require(script.Parent.Toasts)
local StateController = require(script.Parent.Parent.Controllers.StateController)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)

local Shop = {}

local CLOSE_DISTANCE = 26

local gui: ScreenGui
local window: Frame
local tabs: { [string]: TextButton } = {}
local detail: {
	Header: TextLabel,
	Current: TextLabel,
	Next: TextLabel,
	Stats: TextLabel,
	Blurb: TextLabel,
	Buy: TextButton,
}
local selected = "Pickaxe"
local isOpen = false
local busy = false
local distanceConn: RBXScriptConnection?

local function stat(label: string, from: string, to: string): string
	return `<font color="#B0A494">{label}</font>  {from}  <font color="#F2A63A">→ {to}</font>`
end

local function tierOf(state: StateController.State, categoryId: string): number
	local category = Equipment.Category(categoryId)
	return ((state :: any)[category.Field] :: number?) or category.StartTier
end

-- Dark zones a lamp tier unlocks, for the lamp card.
local function darkZonesFor(tier: number): { string }
	local names = {}
	for _, mine in Mines.ById do
		for _, zone in mine.Zones do
			if zone.Dark == tier then
				table.insert(names, zone.DisplayName)
			end
		end
	end
	return names
end

local function statsFor(categoryId: string, cur: any?, nxt: any): string
	local lines = {}
	if categoryId == "Pickaxe" then
		table.insert(lines, stat("Power", tostring(cur.Power), tostring(nxt.Power)))
		table.insert(lines, stat("Swing", string.format("%.2fs", cur.Cooldown), string.format("%.2fs", nxt.Cooldown)))
		if nxt.Hardness > cur.Hardness then
			table.insert(lines, stat("Hardness", tostring(cur.Hardness), tostring(nxt.Hardness)))
		end
	elseif categoryId == "Backpack" then
		table.insert(lines, stat("Capacity", tostring(cur.Capacity), tostring(nxt.Capacity)))
	elseif categoryId == "Lamp" then
		table.insert(lines, stat("Reach", `{cur.Range}`, `{nxt.Range}`))
		table.insert(lines, stat("Glow", `{cur.GlowRange}`, `{nxt.GlowRange}`))
		local zones = darkZonesFor(table.find(Equipment.Lamps, nxt) or 0)
		if #zones > 0 then
			table.insert(lines, `<font color="#76CC70">Reveals: {table.concat(zones, ", ")}</font>`)
		end
	elseif categoryId == "Suit" then
		for hazard, level in nxt.Protection do
			local from = if cur then cur.Protection[hazard] or 0 else 0
			table.insert(lines, stat(`{hazard} protection`, tostring(from), tostring(level)))
		end
	elseif categoryId == "Drill" then
		table.insert(lines, stat("Power / tick", if cur then tostring(cur.Power) else "-", tostring(nxt.Power)))
		table.insert(lines, stat("Splash radius", if cur then tostring(cur.SplashRadius) else "-", tostring(nxt.SplashRadius)))
	end
	return table.concat(lines, "\n")
end

local function setBuyButton(button: TextButton, nxt: any?, state: StateController.State)
	local function disable(text: string)
		button.Text = text
		button.BackgroundColor3 = Theme.Colors.Stroke
		button.TextColor3 = Theme.Colors.TextDim
		button.Active = false
	end
	if not nxt then
		disable("MAXED")
		return
	end
	local ok, hint = Equipment.MeetsRequirements(nxt, state)
	if not ok then
		disable((hint or "LOCKED"):upper())
		return
	end
	local price = Modifiers.Price(nxt.Price, state)
	local affordable = state.Cash >= price
	button.Active = affordable
	button.BackgroundColor3 = if affordable then Theme.Colors.Accent else Theme.Colors.Stroke
	button.TextColor3 = if affordable then Color3.fromRGB(30, 20, 10) else Theme.Colors.TextDim
	button.Text = if affordable then `BUY  {Format.Cash(price)}` else `NEED {Format.Cash(price - state.Cash)} MORE`
end

local function render()
	local state = StateController.State
	if not state or not window then
		return
	end
	for _, category in Equipment.Categories do
		local tab = tabs[category.Id]
		local list = Equipment.List(category.Id)
		local current = list[tierOf(state, category.Id)]
		local sub = tab:FindFirstChild("Sub") :: TextLabel
		sub.Text = if current then current.Name else "None"
		local isSelected = category.Id == selected
		tab.BackgroundColor3 = if isSelected then Theme.Colors.AccentDark else Theme.Colors.PanelLight
		-- Dot when something here is affordable and unlocked.
		local nxt = list[tierOf(state, category.Id) + 1]
		local dot = tab:FindFirstChild("Dot") :: Frame
		dot.Visible = nxt ~= nil and state.Cash >= Modifiers.Price(nxt.Price, state) and (Equipment.MeetsRequirements(nxt, state))
	end

	local category = Equipment.Category(selected)
	local list = Equipment.List(selected)
	local tier = tierOf(state, selected)
	local cur = list[tier]
	local nxt = list[tier + 1]
	detail.Header.Text = category.Name:upper()
	detail.Current.Text = "Current: " .. (if cur then cur.Name else "None")
	detail.Next.Text = if nxt then nxt.Name else (if cur then cur.Name else "-")
	detail.Stats.Text = if nxt then statsFor(selected, cur, nxt) else "The best you can get for now."
	detail.Blurb.Text = if nxt then nxt.Blurb else ""
	setBuyButton(detail.Buy, nxt, state)
end

function Shop:Close()
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

function Shop:Open()
	render()
	isOpen = true
	gui.Enabled = true
	window.Position = UDim2.fromScale(0.5, 0.55)
	TweenService:Create(window, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
	if UserInputService.GamepadEnabled then
		GuiService.SelectedObject = tabs[selected]
	end
	local station = workspace:FindFirstChild("Camp") and workspace.Camp:FindFirstChild("UpgradeStation")
	local anchor = station and station:FindFirstChild("PromptPart") :: BasePart?
	distanceConn = RunService.Heartbeat:Connect(function()
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root or not anchor or (root.Position - anchor.Position).Magnitude > CLOSE_DISTANCE then
			self:Close()
		end
	end)
end

local function buildTab(category, order: number, parent: Instance)
	local tab = Instance.new("TextButton")
	tab.Name = category.Id
	tab.LayoutOrder = order
	tab.AutoButtonColor = true
	tab.Text = ""
	tab.BackgroundColor3 = Theme.Colors.PanelLight
	tab.BorderSizePixel = 0
	tab.Size = UDim2.new(1, 0, 0, 56)
	Theme.Corner(tab, 8)
	Theme.Padding(tab, 8)
	tab.Parent = parent
	local name = Theme.Label({ Text = category.Name:upper(), TextSize = 16, FontFace = Theme.FontHeavy, Size = UDim2.new(1, -14, 0, 18) })
	name.Parent = tab
	local sub = Theme.Label({
		Name = "Sub",
		Text = "",
		TextSize = 14,
		FontFace = Theme.FontMedium,
		TextColor3 = Theme.Colors.TextDim,
		Position = UDim2.fromOffset(0, 20),
		Size = UDim2.new(1, 0, 0, 18),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	sub.Parent = tab
	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.AnchorPoint = Vector2.new(1, 0)
	dot.Position = UDim2.new(1, 0, 0, 2)
	dot.Size = UDim2.fromOffset(10, 10)
	dot.BackgroundColor3 = Theme.Colors.Good
	dot.Visible = false
	Theme.Corner(dot, 5)
	dot.Parent = tab
	tab.Activated:Connect(function()
		selected = category.Id
		render()
	end)
	tabs[category.Id] = tab
end

function Shop:Init()
	gui = Theme.Screen("Shop", 30)
	gui.Enabled = false

	window = Theme.Panel({
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(700, 440),
		BackgroundTransparency = 0.04,
	})
	Theme.Padding(window, 18)
	window.Parent = gui

	local title = Theme.Label({ Text = "UPGRADE BENCH", TextSize = 30, FontFace = Theme.FontHeavy, Size = UDim2.new(1, -50, 0, 34) })
	title.Parent = window
	local subtitle = Theme.Label({
		Text = "Better gear lets you dig deeper.",
		TextSize = 16,
		FontFace = Theme.FontMedium,
		TextColor3 = Theme.Colors.TextDim,
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, -50, 0, 20),
	})
	subtitle.Parent = window
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

	local tabList = Instance.new("Frame")
	tabList.Name = "Tabs"
	tabList.BackgroundTransparency = 1
	tabList.Position = UDim2.fromOffset(0, 66)
	tabList.Size = UDim2.new(0, 200, 1, -66)
	tabList.Parent = window
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = tabList
	for i, category in Equipment.Categories do
		buildTab(category, i, tabList)
	end

	local card = Instance.new("Frame")
	card.Name = "Detail"
	card.BackgroundColor3 = Theme.Colors.PanelLight
	card.BorderSizePixel = 0
	card.Position = UDim2.fromOffset(214, 66)
	card.Size = UDim2.new(1, -214, 1, -66)
	Theme.Corner(card, 10)
	Theme.Padding(card, 16)
	card.Parent = window

	local header = Theme.Label({ Text = "", TextSize = 15, TextColor3 = Theme.Colors.Accent, Size = UDim2.new(1, 0, 0, 18) })
	header.Parent = card
	local current = Theme.Label({
		Text = "",
		TextSize = 16,
		FontFace = Theme.FontMedium,
		TextColor3 = Theme.Colors.TextDim,
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 20),
	})
	current.Parent = card
	local nextLabel = Theme.Label({
		Text = "",
		TextSize = 28,
		FontFace = Theme.FontHeavy,
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 0, 32),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	nextLabel.Parent = card
	local stats = Theme.Label({
		Text = "",
		TextSize = 18,
		FontFace = Theme.FontMedium,
		RichText = true,
		Position = UDim2.fromOffset(0, 92),
		Size = UDim2.new(1, 0, 0, 92),
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	stats.Parent = card
	local blurb = Theme.Label({
		Text = "",
		TextSize = 15,
		FontFace = Theme.FontMedium,
		TextColor3 = Theme.Colors.TextDim,
		TextWrapped = true,
		Position = UDim2.fromOffset(0, 190),
		Size = UDim2.new(1, 0, 0, 40),
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	blurb.Parent = card
	local buy = Theme.Button({
		Name = "Buy",
		Text = "BUY",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 48),
	})
	buy.Parent = card
	detail = { Header = header, Current = current, Next = nextLabel, Stats = stats, Blurb = blurb, Buy = buy }

	buy.Activated:Connect(function()
		if busy or not buy.Active then
			SoundController:Play("Denied")
			return
		end
		busy = true
		local ok, message = Remotes.Function("Purchase"):InvokeServer(selected)
		busy = false
		Toasts:Notify(message, if ok then "Good" else "Warn")
		SoundController:Play(if ok then "Purchase" else "Denied")
	end)

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	StateController.Changed:Connect(function()
		if isOpen then
			render()
		end
	end)
	Remotes.Event("OpenShop").OnClientEvent:Connect(function()
		self:Open()
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if isOpen and (input.KeyCode == Enum.KeyCode.ButtonB or (not processed and input.KeyCode == Enum.KeyCode.Escape)) then
			self:Close()
		end
	end)
end

return Shop
