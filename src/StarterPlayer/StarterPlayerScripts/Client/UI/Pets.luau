--!strict
-- Pets window: "My Pets" (equip / unequip / release, total bonuses) and
-- "Eggs" (prices, hatch chances, hatch button), plus the hatch reveal.
-- Opened with P, the HUD button, or the Pet Nursery prompt (server fires
-- OpenPets). The server validates every action.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Util.Format)
local PetsConfig = require(Shared.Config.Pets)
local Remotes = require(Shared.Remotes)

local Theme = require(script.Parent.Theme)
local Toasts = require(script.Parent.Toasts)
local StateController = require(script.Parent.Parent.Controllers.StateController)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)
local PetController = require(script.Parent.Parent.Controllers.PetController)

local PetsUI = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local window: Frame
local pages: { [string]: ScrollingFrame } = {}
local tabButtons: { [string]: TextButton } = {}
local summary: TextLabel
local selected = "MyPets"
local busy = false
local confirmRelease: string? = nil

-- A small 3D preview of a pet.
local function viewport(pet: PetsConfig.Pet, size: number): ViewportFrame
	local vp = Instance.new("ViewportFrame")
	vp.Name = "Preview"
	vp.BackgroundTransparency = 1
	vp.Size = UDim2.fromOffset(size, size)
	vp.LightColor = Color3.new(1, 1, 1)
	vp.Ambient = Color3.fromRGB(170, 160, 150)
	local model = PetController.Build(pet)
	model:PivotTo(CFrame.Angles(0, math.rad(200), 0))
	model.Parent = vp
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 0.6, -4.6), Vector3.zero)
	camera.Parent = vp
	vp.CurrentCamera = camera
	return vp
end

local function page(name: string): ScrollingFrame
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = name
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.fromOffset(0, 120)
	scroll.Size = UDim2.new(1, 0, 1, -120)
	scroll.ScrollBarThickness = 6
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Visible = false
	scroll.Parent = window
	pages[name] = scroll
	return scroll
end

local function setButton(button: TextButton, text: string, enabled: boolean, color: Color3?)
	button.Text = text
	button.Active = enabled
	button.AutoButtonColor = enabled
	button.BackgroundColor3 = if enabled then (color or Theme.Colors.Accent) else Theme.Colors.Stroke
	button.TextColor3 = if enabled then Color3.fromRGB(30, 20, 10) else Theme.Colors.TextDim
end

local function invoke(name: string, arg: string): (boolean, string?)
	if busy then
		return false, nil
	end
	busy = true
	local ok, success, message = pcall(function()
		return Remotes.Function(name):InvokeServer(arg)
	end)
	busy = false
	if not ok then
		return false, "Something went wrong, try again"
	end
	return success, message
end

----------------------------------------------------------------------------
-- Hatch reveal
----------------------------------------------------------------------------

local overlay: Frame

local function reveal(egg: PetsConfig.Egg, pet: PetsConfig.Pet, isNew: boolean)
	overlay:ClearAllChildren()
	overlay.Visible = true
	overlay.BackgroundTransparency = 0.35
	local eggFrame = Instance.new("Frame")
	eggFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	eggFrame.Position = UDim2.fromScale(0.5, 0.45)
	eggFrame.Size = UDim2.fromOffset(150, 190)
	eggFrame.BackgroundColor3 = egg.Color
	eggFrame.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = eggFrame
	Theme.Stroke(eggFrame, egg.Color:Lerp(Color3.new(1, 1, 1), 0.5), 4, 0)
	eggFrame.Parent = overlay
	SoundController:Play("Purchase")
	-- Wobble, faster and faster.
	for i = 1, 8 do
		local angle = (if i % 2 == 0 then 1 else -1) * (6 + i * 2)
		TweenService:Create(eggFrame, TweenInfo.new(0.16 - i * 0.012), { Rotation = angle }):Play()
		task.wait(0.16 - i * 0.012)
	end
	eggFrame:Destroy()
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BorderSizePixel = 0
	flash.Parent = overlay
	TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	SoundController:Play("MineComplete")

	local rarityColor = PetsConfig.Rarities[pet.Rarity] or Theme.Colors.Text
	local vp = viewport(pet, 220)
	vp.AnchorPoint = Vector2.new(0.5, 0.5)
	vp.Position = UDim2.fromScale(0.5, 0.42)
	vp.Parent = overlay
	Theme.Label({ Text = pet.Rarity:upper() .. (if isNew then "  ·  NEW!" else ""), TextSize = 20, FontFace = Theme.FontHeavy,
		TextColor3 = rarityColor, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.42, 120), Size = UDim2.fromOffset(400, 24),
		TextXAlignment = Enum.TextXAlignment.Center }).Parent = overlay
	local name = Theme.Label({ Text = pet.Name, TextSize = 40, FontFace = Theme.FontHeavy, AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.42, 146), Size = UDim2.fromOffset(500, 44), TextXAlignment = Enum.TextXAlignment.Center })
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = rarityColor
	stroke.Parent = name
	name.Parent = overlay
	Theme.Label({ Text = PetsConfig.BonusText(pet), TextSize = 18, TextColor3 = Theme.Colors.Good, AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.42, 194), Size = UDim2.fromOffset(400, 22), TextXAlignment = Enum.TextXAlignment.Center }).Parent = overlay
	task.wait(2.6)
	overlay.Visible = false
	overlay:ClearAllChildren()
end

----------------------------------------------------------------------------
-- Pages
----------------------------------------------------------------------------

local function renderMyPets()
	local scroll = pages.MyPets
	for _, child in scroll:GetChildren() do
		if child:IsA("Frame") or child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local state = StateController.State
	if not state then
		return
	end
	local owned = state.Pets or {}
	local equipped = state.EquippedPets or {}

	-- Totals line.
	local parts = {}
	for _, bonusType in { "Sell", "Power", "Luck", "Capacity" } do
		local sum = PetsConfig.Bonus(state, bonusType)
		if sum > 0 then
			table.insert(parts, `+{math.floor(sum * 100 + 0.5)}% {PetsConfig.BonusLabels[bonusType]}`)
		end
	end
	summary.Text = `Equipped {#equipped}/{PetsConfig.EquipSlots}   ·   Owned {PetsConfig.CountOwned(state)}/{PetsConfig.MaxOwned}`
		.. (if #parts > 0 then "\n" .. table.concat(parts, "   ") else "\nEquip pets to get their bonuses")

	local any = false
	for order, pet in PetsConfig.List do
		local count = owned[pet.Id] or 0
		if count <= 0 then
			continue
		end
		any = true
		local nEquipped = 0
		for _, id in equipped do
			if id == pet.Id then
				nEquipped += 1
			end
		end
		local cardFrame = Instance.new("Frame")
		cardFrame.Name = pet.Id
		cardFrame.LayoutOrder = order
		cardFrame.BackgroundColor3 = if nEquipped > 0 then Theme.Colors.AccentDark else Theme.Colors.PanelLight
		cardFrame.BorderSizePixel = 0
		Theme.Corner(cardFrame, 8)
		Theme.Stroke(cardFrame, PetsConfig.Rarities[pet.Rarity], if pet.Rarity == "Legendary" then 2 else 1, 0.2)
		cardFrame.Parent = scroll
		local vp = viewport(pet, 76)
		vp.AnchorPoint = Vector2.new(0.5, 0)
		vp.Position = UDim2.new(0.5, 0, 0, 2)
		vp.Parent = cardFrame
		Theme.Label({ Text = if count > 1 then `{pet.Name} x{count}` else pet.Name, TextSize = 15, FontFace = Theme.FontHeavy,
			TextColor3 = PetsConfig.Rarities[pet.Rarity], Position = UDim2.fromOffset(6, 78), Size = UDim2.new(1, -12, 0, 18),
			TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd }).Parent = cardFrame
		Theme.Label({ Text = PetsConfig.BonusText(pet), TextSize = 13, FontFace = Theme.FontMedium, TextColor3 = Theme.Colors.Good,
			Position = UDim2.fromOffset(6, 96), Size = UDim2.new(1, -12, 0, 16), TextXAlignment = Enum.TextXAlignment.Center }).Parent = cardFrame
		local action = Theme.Button({ Name = "Equip", TextSize = 14, Position = UDim2.new(0, 6, 1, -36), Size = UDim2.new(1, -46, 0, 30) })
		action.Parent = cardFrame
		local canEquip = nEquipped < count and #equipped < PetsConfig.EquipSlots
		if nEquipped > 0 and not canEquip then
			setButton(action, "UNEQUIP", true, Theme.Colors.Stroke:Lerp(Theme.Colors.Text, 0.4))
		else
			setButton(action, if nEquipped > 0 then `EQUIP +1` else "EQUIP", canEquip)
		end
		action.Activated:Connect(function()
			if not action.Active then
				return
			end
			local ok, message = invoke(if nEquipped > 0 and not canEquip then "UnequipPet" else "EquipPet", pet.Id)
			if not ok and message then
				Toasts:Notify(message, "Warn")
			end
		end)
		local releaseButton = Theme.Button({ Name = "Release", Text = "X", TextSize = 14, AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 1, -36), Size = UDim2.fromOffset(32, 30), BackgroundColor3 = Theme.Colors.Panel,
			TextColor3 = Theme.Colors.Bad, Visible = pet.Egg ~= nil })
		releaseButton.Parent = cardFrame
		if confirmRelease == pet.Id then
			releaseButton.Text = "?"
			releaseButton.BackgroundColor3 = Theme.Colors.Bad
			releaseButton.TextColor3 = Theme.Colors.Text
		end
		releaseButton.Activated:Connect(function()
			if confirmRelease ~= pet.Id then
				-- First click asks for confirmation.
				confirmRelease = pet.Id
				local egg = pet.Egg and PetsConfig.GetEgg(pet.Egg)
				Toasts:Notify(`Click again to release {pet.Name} for {Format.Cash(math.floor((egg and egg.Price or 0) * PetsConfig.ReleaseFraction))}`, "Info")
				renderMyPets()
				task.delay(3, function()
					if confirmRelease == pet.Id then
						confirmRelease = nil
						if gui.Enabled then
							renderMyPets()
						end
					end
				end)
				return
			end
			confirmRelease = nil
			local ok, message = invoke("ReleasePet", pet.Id)
			if message and message ~= "" then
				Toasts:Notify(message, if ok then "Good" else "Warn")
			end
		end)
	end
	if not any then
		Theme.Label({ Name = "Empty", Text = "No pets yet. Hatch an egg at the Pet Nursery at camp!", TextSize = 18,
			TextColor3 = Theme.Colors.TextDim, Size = UDim2.new(1, 0, 0, 40), TextXAlignment = Enum.TextXAlignment.Center }).Parent = scroll
	end
end

local function renderEggs()
	local scroll = pages.Eggs
	for _, child in scroll:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local state = StateController.State
	if not state then
		return
	end
	for order, egg in PetsConfig.Eggs do
		local unlocked = PetsConfig.CanHatch(egg, state)
		local row = Instance.new("Frame")
		row.Name = egg.Id
		row.LayoutOrder = order
		row.BackgroundColor3 = Theme.Colors.PanelLight
		row.BorderSizePixel = 0
		row.Size = UDim2.new(1, -10, 0, 84)
		Theme.Corner(row, 8)
		Theme.Padding(row, 10)
		row.Parent = scroll
		local eggIcon = Instance.new("Frame")
		eggIcon.Size = UDim2.fromOffset(48, 62)
		eggIcon.BackgroundColor3 = if unlocked then egg.Color else Theme.Colors.Stroke
		eggIcon.BorderSizePixel = 0
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = eggIcon
		eggIcon.Parent = row
		Theme.Label({ Text = egg.Name, TextSize = 19, FontFace = Theme.FontHeavy, Position = UDim2.fromOffset(60, 0),
			Size = UDim2.new(1, -200, 0, 22), TextColor3 = if unlocked then egg.Color:Lerp(Color3.new(1, 1, 1), 0.3) else Theme.Colors.TextDim }).Parent = row
		local chances = {}
		for _, p in PetsConfig.InEgg(egg.Id) do
			local hex = (PetsConfig.Rarities[p.Rarity] or Color3.new(1, 1, 1)):ToHex()
			table.insert(chances, `<font color="#{hex}">{p.Name}</font> {math.floor(PetsConfig.Chance(p) * 100 + 0.5)}%`)
		end
		Theme.Label({ Text = table.concat(chances, "  ·  "), RichText = true, TextSize = 13, FontFace = Theme.FontMedium,
			TextColor3 = Theme.Colors.TextDim, TextWrapped = true, Position = UDim2.fromOffset(60, 24), Size = UDim2.new(1, -200, 0, 38),
			TextYAlignment = Enum.TextYAlignment.Top }).Parent = row
		local hatchButton = Theme.Button({ Name = "Hatch", TextSize = 15, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(128, 44) })
		hatchButton.Parent = row
		if not unlocked then
			setButton(hatchButton, "LOCKED", false)
		else
			setButton(hatchButton, `HATCH {Format.Cash(egg.Price)}`, state.Cash >= egg.Price)
		end
		hatchButton.Activated:Connect(function()
			if not hatchButton.Active then
				return
			end
			local ok, result = invoke("HatchEgg", egg.Id)
			if ok and result then
				local parts = string.split(result, ":")
				local pet = PetsConfig.Get(parts[1])
				if pet then
					task.spawn(reveal, egg, pet, parts[2] == "new")
				end
			elseif result then
				Toasts:Notify(result, "Warn")
			end
		end)
	end
end

local function render()
	if not gui.Enabled then
		return
	end
	if selected == "MyPets" then
		renderMyPets()
	else
		renderEggs()
	end
end

function PetsUI:Select(tab: string)
	selected = tab
	for name, scroll in pages do
		scroll.Visible = name == tab
	end
	for name, button in tabButtons do
		local on = name == tab
		button.BackgroundColor3 = if on then Theme.Colors.Accent else Theme.Colors.PanelLight
		button.TextColor3 = if on then Color3.fromRGB(30, 20, 10) else Theme.Colors.Text
	end
	summary.Visible = tab == "MyPets"
	render()
end

function PetsUI:Open(tab: string?)
	gui.Enabled = true
	self:Select(tab or selected)
	if UserInputService.GamepadEnabled then
		GuiService.SelectedObject = tabButtons[selected]
	end
end

function PetsUI:Close()
	gui.Enabled = false
	GuiService.SelectedObject = nil
end

function PetsUI:Init()
	gui = Theme.Screen("Pets", 35)
	gui.Enabled = false
	window = Theme.Panel({ Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(680, 500), BackgroundTransparency = 0.04 })
	Theme.Padding(window, 18)
	window.Parent = gui
	Theme.Label({ Text = "PETS", TextSize = 30, FontFace = Theme.FontHeavy, Size = UDim2.new(1, -50, 0, 34) }).Parent = window
	local close = Theme.Button({ Name = "Close", Text = "X", TextSize = 20, BackgroundColor3 = Theme.Colors.PanelLight,
		TextColor3 = Theme.Colors.Text, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(40, 40) })
	close.Parent = window
	close.Activated:Connect(function()
		PetsUI:Close()
	end)

	local tabBar = Instance.new("Frame")
	tabBar.Name = "Tabs"
	tabBar.BackgroundTransparency = 1
	tabBar.Position = UDim2.fromOffset(0, 44)
	tabBar.Size = UDim2.new(1, 0, 0, 36)
	tabBar.Parent = window
	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.Padding = UDim.new(0, 8)
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Parent = tabBar
	for i, entry in { { "MyPets", "MY PETS" }, { "Eggs", "EGGS" } } do
		local b = Theme.Button({ Name = entry[1], Text = entry[2], TextSize = 16, LayoutOrder = i, Size = UDim2.fromOffset(140, 36) })
		b.Parent = tabBar
		tabButtons[entry[1]] = b
		b.Activated:Connect(function()
			PetsUI:Select(entry[1])
		end)
	end
	summary = Theme.Label({ Name = "Summary", Text = "", TextSize = 15, FontFace = Theme.FontMedium, TextColor3 = Theme.Colors.TextDim,
		Position = UDim2.fromOffset(0, 84), Size = UDim2.new(1, 0, 0, 34), TextYAlignment = Enum.TextYAlignment.Top })
	summary.Parent = window

	local mine = page("MyPets")
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(150, 150)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = mine
	local eggs = page("Eggs")
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = eggs
	-- The eggs page has no summary line, so it can use that space.
	eggs.Position = UDim2.fromOffset(0, 88)
	eggs.Size = UDim2.new(1, 0, 1, -88)

	-- Full-screen hatch reveal in its own ScreenGui so nothing can cover it.
	local revealGui = Theme.Screen("PetReveal", 92)
	revealGui.IgnoreGuiInset = true
	overlay = Instance.new("Frame")
	overlay.Name = "Hatch"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BorderSizePixel = 0
	overlay.Visible = false
	overlay.Parent = revealGui
	revealGui.Parent = player:WaitForChild("PlayerGui")

	gui.Parent = player:WaitForChild("PlayerGui")

	local hud = player.PlayerGui:WaitForChild("Hud")
	local open = Theme.Button({ Name = "PetsButton", Text = "PETS (P)", TextSize = 15, BackgroundColor3 = Theme.Colors.Panel,
		TextColor3 = Theme.Colors.Text, Position = UDim2.fromOffset(406, 122), Size = UDim2.fromOffset(92, 34) })
	Theme.Stroke(open, nil, 1.5, 0.2)
	open.Parent = hud
	open.Activated:Connect(function()
		if gui.Enabled then
			PetsUI:Close()
		else
			PetsUI:Open()
		end
	end)

	Remotes.Event("OpenPets").OnClientEvent:Connect(function(tab)
		PetsUI:Open(if type(tab) == "string" then tab else nil)
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if gui.Enabled and (input.KeyCode == Enum.KeyCode.ButtonB or (not processed and input.KeyCode == Enum.KeyCode.Escape)) then
			PetsUI:Close()
		elseif not processed and input.KeyCode == Enum.KeyCode.P then
			if gui.Enabled then
				PetsUI:Close()
			else
				PetsUI:Open()
			end
		end
	end)
	StateController:Observe(function()
		render()
	end)
end

return PetsUI
