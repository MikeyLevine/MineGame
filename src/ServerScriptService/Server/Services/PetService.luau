--!strict
-- Pets (Config/Pets): hatching eggs at the camp Pet Nursery, equipping up to
-- Pets.EquipSlots, releasing duplicates. Owned pets are counts per pet id in
-- data.Pets; data.EquippedPets is a list of pet ids (duplicates allowed up to
-- the owned count). The equipped list is mirrored as the player attribute
-- "EquippedPets" (comma-separated) so every client can draw everyone's pets.
-- Bonuses are applied through Shared/Modifiers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Util.Format)
local Pets = require(Shared.Config.Pets)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)

local PetService = {}

local NURSERY_RANGE = 24
local hatchLimit = RateLimit.new(0.8)
local actionLimit = RateLimit.new(0.2)
local rng = Random.new()
local nurseryPart: BasePart?

local function nearNursery(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and nurseryPart ~= nil and (root.Position - nurseryPart.Position).Magnitude <= NURSERY_RANGE
end

local function equippedCount(data: any, petId: string): number
	local n = 0
	for _, id in data.EquippedPets do
		if id == petId then
			n += 1
		end
	end
	return n
end

local function publish(player: Player, data: any)
	player:SetAttribute("EquippedPets", table.concat(data.EquippedPets, ","))
end

local function hatch(player: Player, eggId: any): (boolean, string?)
	if not hatchLimit(player) then
		return false, "Slow down"
	end
	local egg = type(eggId) == "string" and Pets.GetEgg(eggId)
	local data = DataService:Get(player)
	if not egg or not data then
		return false, "Unknown egg"
	end
	if not nearNursery(player) then
		return false, "Visit the Pet Nursery at camp to hatch eggs"
	end
	local ok, hint = Pets.CanHatch(egg, data)
	if not ok then
		return false, hint
	end
	if Pets.CountOwned(data) >= Pets.MaxOwned then
		return false, `Your pet storage is full ({Pets.MaxOwned}). Release a few first.`
	end
	if data.Cash < egg.Price then
		return false, `Need {Format.Cash(egg.Price - data.Cash)} more`
	end
	local pool = Pets.InEgg(egg.Id)
	local total = 0
	for _, p in pool do
		total += p.Weight or 0
	end
	local roll = rng:NextNumber() * total
	local picked = pool[#pool]
	for _, p in pool do
		roll -= p.Weight or 0
		if roll <= 0 then
			picked = p
			break
		end
	end
	local isNew = (data.Pets[picked.Id] or 0) == 0
	DataService:Update(player, function(d)
		d.Cash -= egg.Price
		d.Pets[picked.Id] = (d.Pets[picked.Id] or 0) + 1
		d.Stats.Hatched = (d.Stats.Hatched or 0) + 1
		-- Fill an empty slot automatically so a first pet is useful right away.
		if #d.EquippedPets < Pets.EquipSlots then
			table.insert(d.EquippedPets, picked.Id)
		end
	end)
	publish(player, data)
	return true, picked.Id .. (if isNew then ":new" else "")
end

local function equip(player: Player, petId: any): (boolean, string)
	if not actionLimit(player) then
		return false, "Slow down"
	end
	local data = DataService:Get(player)
	local p = type(petId) == "string" and Pets.Get(petId)
	if not data or not p then
		return false, "Unknown pet"
	end
	if equippedCount(data, p.Id) >= (data.Pets[p.Id] or 0) then
		return false, "You don't have another one of those"
	end
	if #data.EquippedPets >= Pets.EquipSlots then
		return false, `You can equip up to {Pets.EquipSlots} pets`
	end
	DataService:Update(player, function(d)
		table.insert(d.EquippedPets, p.Id)
	end)
	publish(player, data)
	return true, `{p.Name} is following you`
end

local function unequip(player: Player, petId: any): (boolean, string)
	if not actionLimit(player) then
		return false, "Slow down"
	end
	local data = DataService:Get(player)
	local index = data and type(petId) == "string" and table.find(data.EquippedPets, petId)
	if not data or not index then
		return false, "That pet isn't equipped"
	end
	DataService:Update(player, function(d)
		table.remove(d.EquippedPets, index :: number)
	end)
	publish(player, data)
	return true, ""
end

local function release(player: Player, petId: any): (boolean, string)
	if not actionLimit(player) then
		return false, "Slow down"
	end
	local data = DataService:Get(player)
	local p = type(petId) == "string" and Pets.Get(petId)
	if not data or not p or (data.Pets[p.Id] or 0) <= 0 then
		return false, "You don't have that pet"
	end
	if not p.Egg then
		return false, "Store pets can't be released"
	end
	local egg = Pets.GetEgg(p.Egg)
	local refund = math.floor((egg and egg.Price or 0) * Pets.ReleaseFraction)
	DataService:Update(player, function(d)
		d.Pets[p.Id] -= 1
		if d.Pets[p.Id] <= 0 then
			d.Pets[p.Id] = nil
		end
		-- Don't leave more copies equipped than are owned.
		if equippedCount(d, p.Id) > (d.Pets[p.Id] or 0) then
			local index = table.find(d.EquippedPets, p.Id)
			if index then
				table.remove(d.EquippedPets, index)
			end
		end
		d.Cash += refund
	end)
	publish(player, data)
	return true, `Released {p.Name} (+{Format.Cash(refund)})`
end

-- Robux pets (called from StoreService's receipt handling, inside its update).
function PetService:GrantInto(d: any, petId: string)
	d.Pets[petId] = (d.Pets[petId] or 0) + 1
	if #d.EquippedPets < Pets.EquipSlots then
		table.insert(d.EquippedPets, petId)
	end
end

function PetService:Publish(player: Player)
	local data = DataService:Get(player)
	if data then
		publish(player, data)
	end
end

function PetService:Init()
	Remotes.Function("HatchEgg").OnServerInvoke = hatch
	Remotes.Function("EquipPet").OnServerInvoke = equip
	Remotes.Function("UnequipPet").OnServerInvoke = unequip
	Remotes.Function("ReleasePet").OnServerInvoke = release

	DataService:OnLoaded(function(player: Player, data)
		-- Drop equipped entries that point at pets no longer owned (e.g. removed ids).
		local valid = {}
		local seen: { [string]: number } = {}
		for _, id in data.EquippedPets do
			seen[id] = (seen[id] or 0) + 1
			if Pets.Get(id) and seen[id] <= (data.Pets[id] or 0) and #valid < Pets.EquipSlots then
				table.insert(valid, id)
			end
		end
		data.EquippedPets = valid
		publish(player, data)
	end)

	local camp = workspace:WaitForChild("Camp")
	local nursery = camp:WaitForChild("PetNursery", 10)
	local prompt = nursery and nursery:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt and prompt.Parent and prompt.Parent:IsA("BasePart") then
		nurseryPart = prompt.Parent :: BasePart
		prompt.Triggered:Connect(function(player)
			Remotes.Event("OpenPets"):FireClient(player, "Eggs")
		end)
	else
		warn("[PetService] Camp has no PetNursery")
	end
end

return PetService
