--!strict
-- Ancient mechanisms: glyph plates (tagged "Glyph", attributes GlyphId and
-- Door) that a player presses. When every glyph of a door is pressed, the
-- door (a gate with Mechanism = true) opens for that player. Progress is
-- saved in data.Gates like any other gate.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Mines = require(Shared.Config.Mines)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local GateService = require(script.Parent.GateService)

local MechanismService = {}

local RANGE = 14

local function press(player: Player, glyph: Instance, promptPart: BasePart)
	local glyphId = glyph:GetAttribute("GlyphId")
	local doorId = glyph:GetAttribute("Door")
	local glyphs = type(doorId) == "string" and Mines.Mechanisms[doorId]
	local data = DataService:Get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if type(glyphId) ~= "string" or not glyphs or not table.find(glyphs, glyphId) or not data or not root then
		return
	end
	if (root.Position - promptPart.Position).Magnitude > RANGE or not GateService:CanAccess(player, promptPart.Position) then
		return
	end
	if data.Gates[glyphId] then
		return
	end
	local lit, opened = 0, false
	DataService:Update(player, function(d)
		d.Gates[glyphId] = true
		for _, id in glyphs do
			if d.Gates[id] then
				lit += 1
			end
		end
		if lit == #glyphs and not d.Gates[doorId :: string] then
			d.Gates[doorId :: string] = true
			opened = true
		end
	end)
	local notify = Remotes.Event("Notify")
	if opened then
		notify:FireClient(player, "Somewhere in the temple, a great door grinds open...", "Good")
	else
		notify:FireClient(player, `A Sun Glyph flares to life. ({lit}/{#glyphs})`, "Info")
	end
end

local function bind(glyph: Instance)
	local prompt = glyph:FindFirstChildWhichIsA("ProximityPrompt", true)
	local promptPart = prompt and prompt.Parent
	if not prompt or not promptPart or not promptPart:IsA("BasePart") then
		return
	end
	prompt.Triggered:Connect(function(player)
		press(player, glyph, promptPart)
	end)
end

function MechanismService:Init()
	for _, glyph in CollectionService:GetTagged("Glyph") do
		bind(glyph)
	end
	CollectionService:GetInstanceAddedSignal("Glyph"):Connect(bind)
end

return MechanismService
