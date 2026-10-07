--!strict
-- Holds the latest server snapshot of this player's progression.
-- Read-only on the client: the server is the only writer.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Equipment = require(Shared.Config.Equipment)
local Modifiers = require(Shared.Modifiers)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Util.Signal)

export type State = {
	Cash: number,
	PickaxeTier: number,
	BackpackTier: number,
	LampTier: number,
	SuitTier: number,
	DrillTier: number,
	Backpack: { [string]: number },
	Gates: { [string]: boolean },
	Mines: { [string]: { Reached: { [string]: boolean }?, Visited: boolean?, Completed: boolean? } },
	Artifacts: { [string]: boolean },
	Achievements: { [string]: number },
	Settings: { Sfx: number, Ambience: number, Shake: boolean, Objectives: boolean, Hints: boolean }?,
	Stats: { TotalMined: number, TotalEarned: number, Mined: { [string]: number }, CreaturesDefeated: number? },
	Prestige: number,
	RunMined: { [string]: number }?,
	Boosts: { [string]: number }, -- boost id -> Unix time it ends
	Skins: { [string]: boolean },
	EquippedSkin: string,
	Saving: boolean,
}

local StateController = {}
StateController.Changed = Signal.new() -- (state, previous?)
StateController.State = nil :: State?

function StateController:Used(): number
	local used = 0
	if self.State then
		for _, n in self.State.Backpack do
			used += n
		end
	end
	return used
end

function StateController:Capacity(): number
	local s = self.State
	if not s then
		return 0
	end
	local backpack = Equipment.Backpacks[s.BackpackTier] or Equipment.Backpacks[#Equipment.Backpacks]
	return math.floor(backpack.Capacity * Modifiers.Capacity(Modifiers.PlayerPasses(Players.LocalPlayer)))
end

-- Whether this player owns a game pass (mirrored by the server as an attribute).
function StateController:HasPass(id: string): boolean
	return Players.LocalPlayer:GetAttribute("Pass_" .. id) == true
end

function StateController:Pickaxe(): Equipment.Pickaxe
	local s = self.State
	return Equipment.Pickaxes[if s then s.PickaxeTier else 1] or Equipment.Pickaxes[#Equipment.Pickaxes]
end

-- Calls fn(state) now (if loaded) and on every change.
function StateController:Observe(fn: (State, State?) -> ())
	if self.State then
		task.spawn(fn, self.State, nil)
	end
	self.Changed:Connect(fn)
end

function StateController:Init()
	Remotes.Event("State").OnClientEvent:Connect(function(state: State)
		local previous = self.State
		self.State = state
		self.Changed:Fire(state, previous)
	end)
end

return StateController
