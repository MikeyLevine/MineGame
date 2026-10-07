--!strict
-- Backpack contents. Everything here mutates through DataService:Update so
-- clients get a fresh state snapshot after each change.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Equipment = require(Shared.Config.Equipment)
local Resources = require(Shared.Config.Resources)

local DataService = require(script.Parent.DataService)
local Modifiers = require(Shared.Modifiers)

local InventoryService = {}

function InventoryService:Used(data: DataService.Data): number
	local used = 0
	for _, count in data.Backpack do
		used += count
	end
	return used
end

function InventoryService:Capacity(data: DataService.Data, player: Player?): number
	local backpack = Equipment.Backpacks[data.BackpackTier] or Equipment.Backpacks[1]
	local multiplier = if player then Modifiers.Capacity(Modifiers.PlayerPasses(player)) else 1
	return math.floor(backpack.Capacity * multiplier)
end

function InventoryService:IsFull(player: Player): boolean
	local data = DataService:Get(player)
	if not data then
		return true
	end
	return self:Used(data) >= self:Capacity(data, player)
end

-- Adds up to `amount` of a resource; returns how many actually fit.
function InventoryService:Add(player: Player, resourceId: string, amount: number): number
	if not Resources.Get(resourceId) then
		return 0
	end
	local added = 0
	DataService:Update(player, function(data)
		local free = self:Capacity(data, player) - self:Used(data)
		added = math.clamp(amount, 0, free)
		if added > 0 then
			data.Backpack[resourceId] = (data.Backpack[resourceId] or 0) + added
			data.Stats.TotalMined += added
			data.Stats.Mined[resourceId] = (data.Stats.Mined[resourceId] or 0) + added
			data.RunMined[resourceId] = (data.RunMined[resourceId] or 0) + added
		end
	end)
	return added
end

-- Empties the backpack into cash. Returns (total, { [resourceId] = count }).
function InventoryService:SellAll(player: Player): (number, { [string]: number })
	local total, sold = 0, {}
	-- Prestige, VIP, boosts and random events (Ore Frenzy) raise sell prices.
	local current = DataService:Get(player)
	local multiplier = if current
		then Modifiers.Sell(current, Modifiers.PlayerPasses(player), os.time())
		else 1
	DataService:Update(player, function(data)
		for resourceId, count in data.Backpack do
			local resource = Resources.Get(resourceId)
			if resource and count > 0 then
				total += math.floor(resource.Value * count * multiplier)
				sold[resourceId] = count
			end
		end
		table.clear(data.Backpack)
		data.Cash += total
		data.Stats.TotalEarned += total
		data.Stats.BiggestSale = math.max(data.Stats.BiggestSale or 0, total)
	end)
	return total, sold
end

return InventoryService
