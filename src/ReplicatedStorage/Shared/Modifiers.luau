--!strict
-- Per-player multipliers from prestige, game passes, timed boosts and random
-- events, in one place so the server (authority) and the client (displays)
-- always agree. `hasPass(id)` reports game pass ownership; `now` is Unix time.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pets = require(script.Parent.Config.Pets)

local Modifiers = {}

Modifiers.PRESTIGE_SELL = 1.25
Modifiers.PRESTIGE_POWER = 1.1
Modifiers.PRESTIGE_PRICE = 1.4

local function boostActive(data: any, id: string, now: number): boolean
	local ends = data.Boosts and data.Boosts[id]
	return type(ends) == "number" and ends > now
end

function Modifiers.Sell(data: any, hasPass: (string) -> boolean, now: number): number
	local m = Modifiers.PRESTIGE_SELL ^ (data.Prestige or 0)
	if hasPass("VIP") then
		m *= 1.2
	end
	if boostActive(data, "OreBuyerBonus", now) then
		m *= 1.5
	end
	m *= 1 + Pets.Bonus(data, "Sell")
	return m * ((ReplicatedStorage:GetAttribute("SellMultiplier") :: number?) or 1)
end

function Modifiers.Power(data: any, _hasPass: (string) -> boolean, now: number): number
	local m = Modifiers.PRESTIGE_POWER ^ (data.Prestige or 0)
	if boostActive(data, "MiningFrenzy", now) then
		m *= 2
	end
	return m * (1 + Pets.Bonus(data, "Power"))
end

-- Multiplier on the zone's rich-vein chance, applied per player when they
-- break a rock (the world-wide event multiplier applies at spawn instead).
function Modifiers.Luck(data: any, hasPass: (string) -> boolean, now: number): number
	local m = 1
	if hasPass("LuckyMiner") then
		m *= 2
	end
	if boostActive(data, "LuckyCharm", now) then
		m *= 3
	end
	return m * (1 + Pets.Bonus(data, "Luck"))
end

function Modifiers.Capacity(hasPass: (string) -> boolean, data: any?): number
	local m = if hasPass("BigPockets") then 1.5 else 1
	return m * (1 + (if data then Pets.Bonus(data, "Capacity") else 0))
end

-- Equipment prices rise with each prestige level.
function Modifiers.Price(basePrice: number, data: any): number
	return math.floor(basePrice * Modifiers.PRESTIGE_PRICE ^ (data.Prestige or 0))
end

-- Client helper: game pass ownership is mirrored as player attributes.
function Modifiers.PlayerPasses(player: Player): (string) -> boolean
	return function(id: string): boolean
		return player:GetAttribute("Pass_" .. id) == true
	end
end

return Modifiers
