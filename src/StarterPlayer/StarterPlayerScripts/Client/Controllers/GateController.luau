--!strict
-- Hides rubble gates this player has already broken. Gates are per-player
-- progression, so this is done locally: each player sees their own mine.

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local StateController = require(script.Parent.StateController)
local SoundController = require(script.Parent.SoundController)
local LocalSnapshot = require(script.Parent.Parent.Util.LocalSnapshot)

local GateController = {}

local hidden: { [Instance]: boolean } = {}

local function hide(gate: Instance, animate: boolean)
	if hidden[gate] then
		return
	end
	hidden[gate] = true
	LocalSnapshot.Save(gate)
	-- Mechanism doors grind down into the floor instead of crumbling.
	if animate and gate:GetAttribute("Mechanism") then
		local pivot = (gate :: Model):GetPivot()
		SoundController:Play("StoneDoor", pivot.Position)
		for _, part in gate:GetDescendants() do
			if part:IsA("BasePart") then
				part.CanCollide = false
				part.CanQuery = false
				TweenService:Create(part, TweenInfo.new(3.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
					CFrame = part.CFrame - Vector3.new(0, 24, 0),
				}):Play()
			elseif part:IsA("ProximityPrompt") or part:IsA("LayerCollector") or part:IsA("Light") then
				(part :: any).Enabled = false
			end
		end
		return
	end
	for _, part in gate:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanQuery = false
			if animate then
				local drop = part.CFrame * CFrame.new(0, -math.random(2, 5), 0)
					* CFrame.Angles(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
				TweenService:Create(part, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					CFrame = drop,
					Transparency = 1,
				}):Play()
			else
				part.Transparency = 1
			end
		elseif part:IsA("Decal") or part:IsA("Texture") then
			part.Transparency = 1
		elseif part:IsA("ProximityPrompt") or part:IsA("LayerCollector") or part:IsA("Light") then
			(part :: any).Enabled = false
		end
	end
end

local function sync(animate: boolean)
	local state = StateController.State
	if not state then
		return
	end
	for _, gate in CollectionService:GetTagged("Gate") do
		local id = gate:GetAttribute("GateId")
		if type(id) == "string" and state.Gates[id] then
			hide(gate, animate)
		elseif hidden[gate] then
			-- Progress was reset (prestige): put the gate back.
			hidden[gate] = nil
			LocalSnapshot.Restore(gate)
		end
	end
end

function GateController:Init()
	StateController:Observe(function(_, previous)
		sync(previous ~= nil)
	end)
	-- Gates may stream in after the first state arrives.
	CollectionService:GetInstanceAddedSignal("Gate"):Connect(function()
		sync(false)
	end)
end

return GateController
