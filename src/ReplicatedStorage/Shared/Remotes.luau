--!strict
-- Single source of truth for network endpoints. The server creates them;
-- clients wait for them. All client->server payloads are untrusted.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EVENTS = {
	"MineRequest", -- C->S (target: Instance)
	"DrillRequest", -- C->S (target: Instance) one drill tick
	"Hazard", -- S->C ({ type, protected }) while standing in a hazard volume
	"MineFeedback", -- S->C ({ target, damage, health, maxHealth, broken, resourceId?, amount?, reason? })
	"State", -- S->C (full player state snapshot)
	"Notify", -- S->C (text, kind)
	"OpenShop", -- S->C ()
	"Sold", -- S->C ({ total, items })
	"Ascended", -- S->C (mineId) play the wall-breaking sequence
	"Travel", -- S->C ({ phase = "out" | "in", title?, subtitle?, tagline? }) screen fade around teleports
	"OpenLift", -- S->C () show the lift destination picker
	"ObjectivesPulse", -- S->C () draw attention to the objectives panel
	"OpenPrestige", -- S->C () show the prestige dialog
	"OpenDaily", -- S->C () a daily reward is waiting
	"OpenPets", -- S->C (tab) open the pets window (Pet Nursery prompt)
	"ArtifactFound", -- S->C (artifactId) show the discovery card
	"Creature", -- S->C ({ event = "alert" | "bite" | "death", position }) creature sounds/effects
	"Ending", -- S->C () the player completed the final mine
	"Achievement", -- S->C (achievementId) show the unlock pop-up
	"GameEvent", -- S->C ({ id, name, description, mine?, zone? }) a random event started
}

local FUNCTIONS = {
	"Purchase", -- C->S (kind: "Pickaxe" | "Backpack") -> (ok, message)
	"UseLift", -- C->S (liftId) -> (ok, message)
	"SaveSettings", -- C->S (settings table) -> ok
	"BuySkin", -- C->S (skinId) -> (ok, message) cash skins
	"EquipSkin", -- C->S (skinId) -> (ok, message)
	"RemoteSell", -- C->S () -> (ok, message) Remote Seller pass
	"Prestige", -- C->S () -> (ok, message)
	"ClaimDaily", -- C->S () -> (ok, message)
	"HatchEgg", -- C->S (eggId) -> (ok, "petId" or "petId:new" | message)
	"EquipPet", -- C->S (petId) -> (ok, message)
	"UnequipPet", -- C->S (petId) -> (ok, message)
	"ReleasePet", -- C->S (petId) -> (ok, message)
}

local Remotes = {}

local folder: Folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes") :: Folder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in EVENTS do
		if not folder:FindFirstChild(name) then
			local e = Instance.new("RemoteEvent")
			e.Name = name
			e.Parent = folder
		end
	end
	for _, name in FUNCTIONS do
		if not folder:FindFirstChild(name) then
			local f = Instance.new("RemoteFunction")
			f.Name = name
			f.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Remotes.Event(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

function Remotes.Function(name: string): RemoteFunction
	return folder:WaitForChild(name) :: RemoteFunction
end

return Remotes
