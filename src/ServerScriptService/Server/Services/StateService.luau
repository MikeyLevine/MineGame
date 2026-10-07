--!strict
-- Pushes a snapshot of a player's progression to their client whenever it
-- changes. The client never writes state; it only renders this.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)

local StateService = {}

local stateEvent: RemoteEvent

local function push(player: Player, data: DataService.Data)
	stateEvent:FireClient(player, {
		Cash = data.Cash,
		PickaxeTier = data.PickaxeTier,
		BackpackTier = data.BackpackTier,
		LampTier = data.LampTier,
		SuitTier = data.SuitTier,
		DrillTier = data.DrillTier,
		Backpack = data.Backpack,
		Gates = data.Gates,
		Mines = data.Mines,
		Artifacts = data.Artifacts,
		Achievements = data.Achievements,
		Settings = data.Settings,
		Prestige = data.Prestige,
		Boosts = data.Boosts,
		Skins = data.Skins,
		EquippedSkin = data.EquippedSkin,
		Stats = data.Stats,
		RunMined = data.RunMined,
		Saving = DataService:CanSave(player),
	})
end

function StateService:Init()
	stateEvent = Remotes.Event("State")
	DataService:OnLoaded(push)
	DataService.Changed:Connect(push)
end

return StateService
