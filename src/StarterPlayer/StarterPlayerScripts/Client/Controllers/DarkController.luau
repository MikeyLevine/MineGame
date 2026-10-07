--!strict
-- Dark areas: ore inside a zone marked Dark stays invisible to players whose
-- lamp tier is too low (purely visual; the server also refuses to let them
-- mine it). Upgrading the lamp reveals it immediately.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Mines = require(Shared.Config.Mines)

local StateController = require(script.Parent.StateController)

local DarkController = {}

local function zoneOf(ore: Instance): Mines.Zone?
	local zoneId = ore:GetAttribute("Zone")
	-- Ores live in Workspace.Mines.<MineId>.ActiveOres
	local mine = ore.Parent and ore.Parent.Parent
	if type(zoneId) ~= "string" or not mine then
		return nil
	end
	return Mines.GetZone(mine.Name, zoneId)
end

local function setHidden(ore: Instance, hidden: boolean)
	for _, d in ore:GetDescendants() do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = if hidden then 1 else 0
		elseif d:IsA("Light") or d:IsA("ParticleEmitter") then
			(d :: any).Enabled = not hidden
		end
	end
end

local function apply(ore: Instance)
	local zone = zoneOf(ore)
	if not zone or not zone.Dark then
		return
	end
	local state = StateController.State
	local lamp = if state then state.LampTier else 1
	setHidden(ore, lamp < zone.Dark)
end

local function applyAll()
	for _, ore in CollectionService:GetTagged("Ore") do
		apply(ore)
	end
end

function DarkController:LampFor(zone: Mines.Zone): boolean
	local state = StateController.State
	return zone.Dark == nil or (state ~= nil and state.LampTier >= zone.Dark)
end

function DarkController:Init()
	CollectionService:GetInstanceAddedSignal("Ore"):Connect(function(ore)
		-- Attributes/parent are set before the tag replicates, but defer to be safe.
		task.defer(apply, ore)
	end)
	StateController:Observe(function(state, previous)
		if not previous or previous.LampTier ~= state.LampTier then
			applyAll()
		end
	end)
end

return DarkController
