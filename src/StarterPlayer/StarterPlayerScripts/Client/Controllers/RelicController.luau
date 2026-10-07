--!strict
-- Ancient things the player interacts with, client side:
--  * Artifacts: hidden once collected; collecting one shows a discovery card.
--  * Sun Glyphs: light up once pressed.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Artifacts = require(Shared.Config.Artifacts)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)

local StateController = require(script.Parent.StateController)
local SoundController = require(script.Parent.SoundController)
local EffectsController = require(script.Parent.EffectsController)
local Theme = require(script.Parent.Parent.UI.Theme)

local RelicController = {}

local card: Frame
local cardGui: ScreenGui
local cardTitle: TextLabel
local cardLore: TextLabel
local cardReward: TextLabel
local cardCount: TextLabel
local hideToken = 0

local function setArtifactVisible(model: Instance, visible: boolean)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "Pedestal" and d.Name ~= "PedestalTop" then
			d.LocalTransparencyModifier = if visible then 0 else 1
		elseif d:IsA("Light") or d:IsA("ParticleEmitter") or d:IsA("ProximityPrompt") then
			(d :: any).Enabled = visible
		end
	end
end

local function setGlyphLit(glyph: Instance, lit: boolean)
	local sun = glyph:FindFirstChild("Sun", true)
	if sun and sun:IsA("BasePart") then
		sun.Color = if lit then Color3.fromRGB(255, 210, 90) else Color3.fromRGB(80, 70, 50)
		sun.Material = if lit then Enum.Material.Neon else Enum.Material.Slate
		local light = sun:FindFirstChildOfClass("PointLight")
		if light then
			light.Enabled = lit
		end
	end
	local prompt = glyph:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		prompt.Enabled = not lit
	end
end

local function sync()
	local state = StateController.State
	if not state then
		return
	end
	for _, model in CollectionService:GetTagged("Artifact") do
		local id = model:GetAttribute("ArtifactId")
		setArtifactVisible(model, not (type(id) == "string" and state.Artifacts[id]))
	end
	for _, glyph in CollectionService:GetTagged("Glyph") do
		local id = glyph:GetAttribute("GlyphId")
		local wasLit = glyph:GetAttribute("LocalLit") == true
		local lit = type(id) == "string" and state.Gates[id] == true
		if lit and not wasLit and StateController.State then
			local sun = glyph:FindFirstChild("Sun", true)
			if sun and sun:IsA("BasePart") and glyph:GetAttribute("LocalSeen") then
				SoundController:Play("GlyphPress", sun.Position)
				EffectsController:Break(sun.Position, Color3.fromRGB(255, 210, 90), Enum.Material.Neon, 0.6)
			end
		end
		glyph:SetAttribute("LocalLit", lit)
		glyph:SetAttribute("LocalSeen", true)
		setGlyphLit(glyph, lit)
	end
end

local function showCard(artifactId: string)
	local artifact = Artifacts.Get(artifactId)
	local state = StateController.State
	if not artifact then
		return
	end
	SoundController:Play("ArtifactFound")
	cardTitle.Text = artifact.Name
	cardTitle.TextColor3 = artifact.Color
	cardLore.Text = artifact.Lore
	cardReward.Text = "+" .. Format.Cash(artifact.Reward)
	local found, total = Artifacts.CountIn(state and state.Artifacts)
	-- State may not include this one yet; count it.
	if state and not state.Artifacts[artifactId] then
		found += 1
	end
	cardCount.Text = `Collection {found}/{total}`
	cardGui.Enabled = true
	card.Position = UDim2.fromScale(0.5, 0.42)
	card.GroupTransparency = 1
	TweenService:Create(card, TweenInfo.new(0.45, Enum.EasingStyle.Back), { Position = UDim2.fromScale(0.5, 0.4), GroupTransparency = 0 }):Play()
	hideToken += 1
	local token = hideToken
	task.delay(7, function()
		if token == hideToken then
			TweenService:Create(card, TweenInfo.new(0.5), { GroupTransparency = 1 }):Play()
			task.wait(0.5)
			if token == hideToken then
				cardGui.Enabled = false
			end
		end
	end)
end

local function buildCard()
	cardGui = Theme.Screen("ArtifactCard", 40)
	cardGui.Enabled = false
	card = Instance.new("CanvasGroup")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Size = UDim2.fromOffset(440, 220)
	card.BackgroundColor3 = Theme.Colors.Panel
	card.BackgroundTransparency = 0.05
	card.BorderSizePixel = 0
	Theme.Corner(card, 14)
	Theme.Stroke(card, Color3.fromRGB(150, 220, 210), 2)
	Theme.Padding(card, 18)
	card.Parent = cardGui

	local header = Theme.Label({
		Text = "ARTIFACT DISCOVERED",
		TextSize = 15,
		TextColor3 = Color3.fromRGB(150, 220, 210),
		Size = UDim2.new(1, 0, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	header.Parent = card
	cardTitle = Theme.Label({
		Text = "",
		TextSize = 32,
		FontFace = Theme.FontHeavy,
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.new(1, 0, 0, 38),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	cardTitle.Parent = card
	cardLore = Theme.Label({
		Text = "",
		TextSize = 16,
		FontFace = Theme.FontMedium,
		TextColor3 = Theme.Colors.TextDim,
		TextWrapped = true,
		Position = UDim2.fromOffset(0, 66),
		Size = UDim2.new(1, 0, 0, 72),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	cardLore.Parent = card
	cardReward = Theme.Label({
		Text = "",
		TextSize = 26,
		FontFace = Theme.FontHeavy,
		TextColor3 = Theme.Colors.Cash,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(0.5, 0, 0, 30),
	})
	cardReward.Parent = card
	cardCount = Theme.Label({
		Text = "",
		TextSize = 17,
		TextColor3 = Color3.fromRGB(150, 220, 210),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.new(0.5, 0, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	cardCount.Parent = card
	cardGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

function RelicController:Init()
	buildCard()
	StateController:Observe(sync)
	CollectionService:GetInstanceAddedSignal("Artifact"):Connect(sync)
	CollectionService:GetInstanceAddedSignal("Glyph"):Connect(sync)
	Remotes.Event("ArtifactFound").OnClientEvent:Connect(showCard)
end

return RelicController
