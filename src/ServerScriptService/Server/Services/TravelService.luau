--!strict
-- Moves players around the world: lifts between camp and unlocked mine
-- levels, and the portal after an ascension. Every move is server-side, with
-- a client screen fade around it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Mines = require(Shared.Config.Mines)
local Progress = require(Shared.Progress)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)

local TravelService = {}

export type Intro = { title: string?, subtitle: string?, tagline: string? }

local FADE_SECONDS = 0.45
local CAMP_LIFT_RANGE = 16

local busy: { [Player]: boolean } = {}
local liftStops: { [string]: Model } = {}
local travelEvent: RemoteEvent

local function arrivalOf(stop: Instance): CFrame?
	local arrival = stop:FindFirstChild("Arrival")
	return if arrival and arrival:IsA("BasePart") then arrival.CFrame else nil
end

-- Fades the player's screen out, moves the character, fades back in.
function TravelService:Teleport(player: Player, target: CFrame, intro: Intro?): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if busy[player] or not character or not root then
		return false
	end
	busy[player] = true
	travelEvent:FireClient(player, { phase = "out" })
	task.wait(FADE_SECONDS)
	if character.Parent then
		root.AssemblyLinearVelocity = Vector3.zero
		character:PivotTo(target)
	end
	task.wait(0.25)
	local payload: { [string]: any } = { phase = "in" }
	if intro then
		payload.title = intro.title
		payload.subtitle = intro.subtitle
		payload.tagline = intro.tagline
	end
	travelEvent:FireClient(player, payload)
	busy[player] = false
	return true
end

function TravelService:ArrivalFor(liftId: string): CFrame?
	local stop = liftStops[liftId]
	return stop and arrivalOf(stop)
end

local function nearCampLift(player: Player): boolean
	local stop = liftStops.Camp
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local promptPart = stop and stop:FindFirstChild("PromptPart") :: BasePart?
	return root ~= nil and promptPart ~= nil and (root.Position - promptPart.Position).Magnitude <= CAMP_LIFT_RANGE
end

local function useLift(player: Player, liftId: any): (boolean, string)
	if type(liftId) ~= "string" then
		return false, "Unknown destination"
	end
	local lift = Mines.GetLift(liftId)
	local data = DataService:Get(player)
	if not lift or not data then
		return false, "Unknown destination"
	end
	if not nearCampLift(player) then
		return false, "Step into the lift first"
	end
	if not Progress.IsLiftUnlocked(data :: any, lift) then
		return false, "You haven't reached that level yet"
	end
	local target = TravelService:ArrivalFor(lift.Id)
	if not target then
		return false, "That lift stop is missing"
	end
	local mine = Mines.ById[lift.MineId]
	task.spawn(function()
		TravelService:Teleport(player, target, {
			title = lift.DisplayName,
			subtitle = if mine then mine.DisplayName else nil,
		})
	end)
	return true, "Going down..."
end

local function bindStop(stop: Instance)
	local liftId = stop:GetAttribute("LiftId")
	if type(liftId) ~= "string" or not stop:IsA("Model") then
		return
	end
	liftStops[liftId] = stop
	local prompt = stop:FindFirstChildWhichIsA("ProximityPrompt", true)
	if not prompt then
		return
	end
	if liftId == "Camp" then
		prompt.Triggered:Connect(function(player)
			Remotes.Event("OpenLift"):FireClient(player)
		end)
	else
		prompt.Triggered:Connect(function(player)
			local target = TravelService:ArrivalFor("Camp")
			if target then
				TravelService:Teleport(player, target, { title = "Camp", subtitle = "Back on the surface" })
			end
		end)
	end
end

function TravelService:Init()
	travelEvent = Remotes.Event("Travel")
	for _, stop in CollectionService:GetTagged("LiftStop") do
		bindStop(stop)
	end
	CollectionService:GetInstanceAddedSignal("LiftStop"):Connect(bindStop)
	Remotes.Function("UseLift").OnServerInvoke = useLift
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
end

return TravelService
