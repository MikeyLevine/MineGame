--!strict
-- Store window: Robux game passes and boosts, plus the pickaxe skin picker
-- (earned, cash and Robux skins). Robux purchases go through
-- MarketplaceService prompts; the server grants them in ProcessReceipt.
-- Cash skins and equipping go through validated server remotes.

local GuiService = game:GetService("GuiService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)
local Skins = require(Shared.Config.Skins)
local PetsConfig = require(Shared.Config.Pets)
local StoreConfig = require(Shared.Config.Store)

local Theme = require(script.Parent.Theme)
local Toasts = require(script.Parent.Toasts)
local StateController = require(script.Parent.Parent.Controllers.StateController)

local Store = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local pages: { [string]: ScrollingFrame } = {}
local tabButtons: { [string]: TextButton } = {}
local refreshers: { () -> () } = {}
local robuxPrices: { [string]: number } = {} -- "pass:<id>" / "product:<id>" -> price
local busy = false

local TABS = { "Passes", "Boosts", "Skins", "Pets" }

local function priceText(key: string, id: number): string
	if id <= 0 then
		return "Coming soon"
	end
	local price = robuxPrices[key]
	return if price then `R$ {price}` else "R$ ..."
end

-- Prices come from the dashboard so the UI never shows a stale number.
local function fetchPrice(key: string, id: number, infoType: Enum.InfoType)
	if id <= 0 or robuxPrices[key] then
		return
	end
	task.spawn(function()
		local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, infoType)
		if ok and info and info.PriceInRobux then
			robuxPrices[key] = info.PriceInRobux
			for _, refresh in refreshers do
				refresh()
			end
		end
	end)
end

local function page(name: string, parent: Frame): ScrollingFrame
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = name
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.fromOffset(0, 96)
	scroll.Size = UDim2.new(1, 0, 1, -96)
	scroll.ScrollBarThickness = 6
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Visible = false
	scroll.Parent = parent
	pages[name] = scroll
	return scroll
end

local function card(parent: Instance, name: string, order: number, color: Color3): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.LayoutOrder = order
	f.BackgroundColor3 = Theme.Colors.PanelLight
	f.BorderSizePixel = 0
	Theme.Corner(f, 8)
	Theme.Padding(f, 12)
	local stripe = Instance.new("Frame")
	stripe.Name = "Stripe"
	stripe.BackgroundColor3 = color
	stripe.BorderSizePixel = 0
	stripe.Position = UDim2.new(0, -12, 0, -12)
	stripe.Size = UDim2.new(0, 5, 1, 24)
	stripe.Parent = f
	f.Parent = parent
	return f
end

local function setButton(button: TextButton, text: string, enabled: boolean, color: Color3?)
	button.Text = text
	button.Active = enabled
	button.AutoButtonColor = enabled
	button.BackgroundColor3 = if enabled then (color or Theme.Colors.Accent) else Theme.Colors.Stroke
	button.TextColor3 = if enabled then Color3.fromRGB(30, 20, 10) else Theme.Colors.TextDim
end

local function listLayout(parent: Instance, padding: number)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, padding)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = parent
end

local function buildPasses(parent: Frame)
	local scroll = page("Passes", parent)
	listLayout(scroll, 8)
	for order, pass in StoreConfig.Passes do
		local key = "pass:" .. pass.Id
		fetchPrice(key, pass.GamePassId, Enum.InfoType.GamePass)
		local f = card(scroll, pass.Id, order, pass.Color)
		f.Size = UDim2.new(1, -10, 0, 86)
		Theme.Label({ Text = pass.Name, TextSize = 20, FontFace = Theme.FontHeavy, TextColor3 = pass.Color,
			Size = UDim2.new(1, -140, 0, 24) }).Parent = f
		Theme.Label({ Text = pass.Description, TextSize = 15, FontFace = Theme.FontMedium, TextColor3 = Theme.Colors.TextDim,
			TextWrapped = true, Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, -140, 0, 36),
			TextYAlignment = Enum.TextYAlignment.Top }).Parent = f
		local buy = Theme.Button({ Name = "Buy", TextSize = 16, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(124, 40) })
		buy.Parent = f
		buy.Activated:Connect(function()
			if buy.Active and pass.GamePassId > 0 then
				MarketplaceService:PromptGamePassPurchase(player, pass.GamePassId)
			end
		end)
		table.insert(refreshers, function()
			if StateController:HasPass(pass.Id) then
				setButton(buy, "OWNED", false)
			else
				setButton(buy, priceText(key, pass.GamePassId), pass.GamePassId > 0, Theme.Colors.Good)
			end
		end)
	end
end

local function buildBoosts(parent: Frame)
	local scroll = page("Boosts", parent)
	listLayout(scroll, 8)
	Theme.Label({ Name = "Note", LayoutOrder = 0, Text = "Buying a boost again adds more time. Boosts keep ticking while you're offline.",
		TextSize = 14, FontFace = Theme.FontMedium, TextColor3 = Theme.Colors.TextDim, TextWrapped = true,
		Size = UDim2.new(1, -10, 0, 20) }).Parent = scroll
	for order, boost in StoreConfig.Boosts do
		local key = "product:" .. boost.Id
		fetchPrice(key, boost.ProductId, Enum.InfoType.Product)
		local f = card(scroll, boost.Id, order, boost.Color)
		f.Size = UDim2.new(1, -10, 0, 74)
		Theme.Label({ Text = boost.Name, TextSize = 20, FontFace = Theme.FontHeavy, TextColor3 = boost.Color,
			Size = UDim2.new(1, -140, 0, 24) }).Parent = f
		local desc = Theme.Label({ Name = "Description", Text = boost.Description, TextSize = 15, FontFace = Theme.FontMedium,
			TextColor3 = Theme.Colors.TextDim, Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, -140, 0, 22) })
		desc.Parent = f
		local buy = Theme.Button({ Name = "Buy", TextSize = 16, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(124, 40) })
		buy.Parent = f
		buy.Activated:Connect(function()
			if buy.Active and boost.ProductId > 0 then
				MarketplaceService:PromptProductPurchase(player, boost.ProductId)
			end
		end)
		table.insert(refreshers, function()
			local state = StateController.State
			local ends = state and state.Boosts and state.Boosts[boost.Id]
			local left = if type(ends) == "number" then ends - os.time() else 0
			desc.Text = if left > 0 then `{boost.Description}  ({math.ceil(left / 60)} min left)` else boost.Description
			setButton(buy, priceText(key, boost.ProductId), boost.ProductId > 0, Theme.Colors.Good)
		end)
	end
end

local function invoke(name: string, ...: any)
	if busy then
		return
	end
	busy = true
	local ok, success, message = pcall(Remotes.Function(name).InvokeServer, Remotes.Function(name), ...)
	busy = false
	if not ok then
		Toasts:Notify("Something went wrong, try again", "Warn")
	elseif message then
		Toasts:Notify(message, if success then "Good" else "Warn")
	end
end

local SOURCE_LABEL = {
	Default = "Starter",
	Achievement = "Earned",
	Prestige = "Prestige",
	Cash = "Cash",
	Robux = "Premium",
	Pass = "VIP",
}

-- Robux pets: always that exact pet (never random).
local function buildPets(parent: Frame)
	local scroll = page("Pets", parent)
	listLayout(scroll, 8)
	Theme.Label({ Name = "Note", LayoutOrder = 0, Text = "Store pets are yours forever and never random. Eggs at the Pet Nursery use in-game cash.",
		TextSize = 14, FontFace = Theme.FontMedium, TextColor3 = Theme.Colors.TextDim, TextWrapped = true,
		Size = UDim2.new(1, -10, 0, 20) }).Parent = scroll
	local order = 0
	for _, pet in PetsConfig.List do
		if pet.ProductId == nil then
			continue
		end
		order += 1
		local key = "product:" .. pet.Id
		fetchPrice(key, pet.ProductId, Enum.InfoType.Product)
		local f = card(scroll, pet.Id, order, pet.Accent)
		f.Size = UDim2.new(1, -10, 0, 74)
		Theme.Label({ Text = pet.Name, TextSize = 20, FontFace = Theme.FontHeavy, TextColor3 = pet.Accent,
			Size = UDim2.new(1, -140, 0, 24) }).Parent = f
		local owned = Theme.Label({ Name = "Description", Text = "", TextSize = 15, FontFace = Theme.FontMedium,
			TextColor3 = Theme.Colors.TextDim, Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, -140, 0, 22) })
		owned.Parent = f
		local buy = Theme.Button({ Name = "Buy", TextSize = 16, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(124, 40) })
		buy.Parent = f
		buy.Activated:Connect(function()
			if buy.Active and (pet.ProductId or 0) > 0 then
				MarketplaceService:PromptProductPurchase(player, pet.ProductId :: number)
			end
		end)
		table.insert(refreshers, function()
			local state = StateController.State
			local count = state and state.Pets and state.Pets[pet.Id] or 0
			owned.Text = `{pet.Rarity} pet: {PetsConfig.BonusText(pet)}` .. (if count > 0 then `  (you own {count})` else "")
			setButton(buy, priceText(key, pet.ProductId or 0), (pet.ProductId or 0) > 0, Theme.Colors.Good)
		end)
	end
end

local function buildSkins(parent: Frame)
	local scroll = page("Skins", parent)
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(196, 150)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroll
	for order, skin in Skins.List do
		local key = "product:" .. skin.Id
		if skin.Source == "Robux" then
			fetchPrice(key, skin.ProductId or 0, Enum.InfoType.Product)
		end
		local f = card(scroll, skin.Id, order, skin.Trail or skin.HeadColor)
		-- Swatch: head colour + handle colour, glowing skins get a neon head.
		local swatch = Instance.new("Frame")
		swatch.Name = "Swatch"
		swatch.BackgroundColor3 = skin.HandleColor
		swatch.BorderSizePixel = 0
		swatch.Size = UDim2.fromOffset(44, 44)
		Theme.Corner(swatch, 8)
		swatch.Parent = f
		local head = Instance.new("Frame")
		head.BackgroundColor3 = if skin.Id == "Classic" then Color3.fromRGB(120, 110, 100) else skin.HeadColor
		head.BorderSizePixel = 0
		head.Size = UDim2.new(1, 0, 0.5, 0)
		Theme.Corner(head, 8)
		head.Parent = swatch
		if skin.Glow then
			Theme.Stroke(swatch, skin.HeadColor, 2, 0)
		end
		Theme.Label({ Text = skin.Name, TextSize = 16, FontFace = Theme.FontHeavy, TextWrapped = true,
			Position = UDim2.fromOffset(52, 0), Size = UDim2.new(1, -52, 0, 22) }).Parent = f
		Theme.Label({ Text = SOURCE_LABEL[skin.Source] or skin.Source, TextSize = 13, TextColor3 = skin.Trail or skin.HeadColor,
			Position = UDim2.fromOffset(52, 22), Size = UDim2.new(1, -52, 0, 18) }).Parent = f
		local extras = {}
		if skin.Glow then
			table.insert(extras, "glow")
		end
		if skin.Trail then
			table.insert(extras, "trail")
		end
		if skin.Spark then
			table.insert(extras, "sparks")
		end
		local hint = Theme.Label({ Name = "Hint", Text = "", TextSize = 13, FontFace = Theme.FontMedium, TextColor3 = Theme.Colors.TextDim,
			TextWrapped = true, Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 0, 30) })
		hint.Parent = f
		local button = Theme.Button({ Name = "Action", TextSize = 15, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 34) })
		button.Parent = f

		local action: string? = nil
		button.Activated:Connect(function()
			if not button.Active then
				return
			end
			if action == "Equip" then
				invoke("EquipSkin", skin.Id)
			elseif action == "BuyCash" then
				invoke("BuySkin", skin.Id)
			elseif action == "BuyRobux" and (skin.ProductId or 0) > 0 then
				MarketplaceService:PromptProductPurchase(player, skin.ProductId :: number)
			end
		end)
		table.insert(refreshers, function()
			local state = StateController.State
			if not state then
				return
			end
			local hasPass = function(id: string): boolean
				return StateController:HasPass(id)
			end
			local unlocked = Skins.IsUnlocked(skin, state, hasPass)
			local extraText = if #extras > 0 then "With " .. table.concat(extras, ", ") .. "." else "Colours only."
			hint.Text = if unlocked or skin.Source == "Cash" or skin.Source == "Robux" then extraText else Skins.UnlockHint(skin)
			action = nil
			if state.EquippedSkin == skin.Id then
				setButton(button, "EQUIPPED", false)
			elseif unlocked then
				action = "Equip"
				setButton(button, "EQUIP", true)
			elseif skin.Source == "Cash" then
				local price = skin.Price or 0
				action = "BuyCash"
				setButton(button, if state.Cash >= price then `BUY {Format.Cash(price)}` else `{Format.Cash(price)}`, state.Cash >= price)
			elseif skin.Source == "Robux" then
				action = "BuyRobux"
				setButton(button, priceText(key, skin.ProductId or 0), (skin.ProductId or 0) > 0, Theme.Colors.Good)
			else
				setButton(button, "LOCKED", false)
			end
		end)
	end
end

local function refresh()
	for _, fn in refreshers do
		fn()
	end
end

function Store:Select(tab: string)
	for name, scroll in pages do
		scroll.Visible = name == tab
	end
	for name, button in tabButtons do
		local on = name == tab
		button.BackgroundColor3 = if on then Theme.Colors.Accent else Theme.Colors.PanelLight
		button.TextColor3 = if on then Color3.fromRGB(30, 20, 10) else Theme.Colors.Text
	end
end

function Store:Open()
	gui.Enabled = true
	refresh()
	if UserInputService.GamepadEnabled then
		GuiService.SelectedObject = tabButtons.Passes
	end
end

function Store:Close()
	gui.Enabled = false
	GuiService.SelectedObject = nil
end

function Store:Toggle()
	if gui.Enabled then
		Store:Close()
	else
		Store:Open()
	end
end

function Store:Init()
	gui = Theme.Screen("Store", 34)
	gui.Enabled = false
	local window = Theme.Panel({ Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(660, 500), BackgroundTransparency = 0.04 })
	Theme.Padding(window, 18)
	window.Parent = gui
	Theme.Label({ Text = "STORE", TextSize = 30, FontFace = Theme.FontHeavy, Size = UDim2.new(1, -50, 0, 34) }).Parent = window
	Theme.Label({ Text = "Everything here is optional. The whole game can be finished without spending anything.", TextSize = 14,
		FontFace = Theme.FontMedium, TextColor3 = Theme.Colors.TextDim, Position = UDim2.fromOffset(120, 8),
		Size = UDim2.new(1, -170, 0, 20) }).Parent = window
	local close = Theme.Button({ Name = "Close", Text = "X", TextSize = 20, BackgroundColor3 = Theme.Colors.PanelLight,
		TextColor3 = Theme.Colors.Text, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(40, 40) })
	close.Parent = window
	close.Activated:Connect(function()
		Store:Close()
	end)

	local tabBar = Instance.new("Frame")
	tabBar.Name = "Tabs"
	tabBar.BackgroundTransparency = 1
	tabBar.Position = UDim2.fromOffset(0, 46)
	tabBar.Size = UDim2.new(1, 0, 0, 38)
	tabBar.Parent = window
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.Padding = UDim.new(0, 8)
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Parent = tabBar
	for i, name in TABS do
		local b = Theme.Button({ Name = name, Text = string.upper(name), TextSize = 16, LayoutOrder = i, Size = UDim2.fromOffset(130, 38) })
		b.Parent = tabBar
		tabButtons[name] = b
		b.Activated:Connect(function()
			Store:Select(name)
		end)
	end

	buildPasses(window)
	buildBoosts(window)
	buildSkins(window)
	buildPets(window)
	Store:Select("Passes")

	gui.Parent = player:WaitForChild("PlayerGui")

	local hud = player.PlayerGui:WaitForChild("Hud")
	local open = Theme.Button({ Name = "StoreButton", Text = "STORE  (B)", TextSize = 15, BackgroundColor3 = Theme.Colors.Panel,
		TextColor3 = Theme.Colors.Cash, Position = UDim2.fromOffset(216, 122), Size = UDim2.fromOffset(104, 34) })
	Theme.Stroke(open, Theme.Colors.Cash, 1.5, 0.3)
	open.Parent = hud
	open.Activated:Connect(function()
		Store:Toggle()
	end)

	StateController:Observe(function()
		if gui.Enabled then
			refresh()
		end
	end)
	-- Keyboard B / gamepad D-pad up toggles; gamepad B or Escape closes.
	UserInputService.InputBegan:Connect(function(input, processed)
		if gui.Enabled and (input.KeyCode == Enum.KeyCode.ButtonB or (not processed and input.KeyCode == Enum.KeyCode.Escape)) then
			Store:Close()
		elseif not processed and (input.KeyCode == Enum.KeyCode.B or input.KeyCode == Enum.KeyCode.DPadUp) then
			Store:Toggle()
		end
	end)
	player.AttributeChanged:Connect(function(name)
		if gui.Enabled and string.sub(name, 1, 5) == "Pass_" then
			refresh()
		end
	end)
end

return Store
