--!strict
-- Robux store. IDs are 0 until the Game Passes / Developer Products are
-- created on the Creator Dashboard (Monetization tab of the experience).
-- Paste each id here; items with id 0 show "Coming soon" and can't be bought.
-- Robux skins live in Config/Skins (each has its own ProductId).

export type Pass = {
	Id: string,
	Name: string,
	Description: string,
	GamePassId: number,
	Color: Color3,
}

export type Boost = {
	Id: string,
	Name: string,
	Description: string,
	ProductId: number,
	Duration: number, -- seconds added per purchase
	Color: Color3,
}

local Store = {}

Store.Passes = {
	{
		Id = "VIP",
		Name = "VIP Miner",
		Description = "+20% sell value forever, a gold VIP badge and the exclusive Golden Royal pickaxe skin.",
		GamePassId = 0,
		Color = Color3.fromRGB(255, 200, 70),
	},
	{
		Id = "RemoteSell",
		Name = "Remote Seller",
		Description = "Sell your backpack from anywhere with the SELL button. No more walking back to camp.",
		GamePassId = 0,
		Color = Color3.fromRGB(120, 210, 120),
	},
	{
		Id = "BigPockets",
		Name = "Big Pockets",
		Description = "+50% capacity on every backpack you own, now and in the future.",
		GamePassId = 0,
		Color = Color3.fromRGB(150, 120, 80),
	},
	{
		Id = "LuckyMiner",
		Name = "Lucky Miner",
		Description = "Double the chance that any rock pays out like a rich vein.",
		GamePassId = 0,
		Color = Color3.fromRGB(120, 220, 255),
	},
} :: { Pass }

Store.Boosts = {
	{
		Id = "MiningFrenzy",
		Name = "Mining Frenzy",
		Description = "x2 mining power for 15 minutes.",
		ProductId = 0,
		Duration = 900,
		Color = Color3.fromRGB(255, 130, 60),
	},
	{
		Id = "LuckyCharm",
		Name = "Lucky Charm",
		Description = "x3 rich vein luck for 15 minutes.",
		ProductId = 0,
		Duration = 900,
		Color = Color3.fromRGB(110, 230, 150),
	},
	{
		Id = "OreBuyerBonus",
		Name = "Ore Buyer Bonus",
		Description = "x1.5 sell value for 15 minutes.",
		ProductId = 0,
		Duration = 900,
		Color = Color3.fromRGB(255, 210, 90),
	},
} :: { Boost }

function Store.GetPass(id: string): Pass?
	for _, p in Store.Passes do
		if p.Id == id then
			return p
		end
	end
	return nil
end

function Store.GetBoost(id: string): Boost?
	for _, b in Store.Boosts do
		if b.Id == id then
			return b
		end
	end
	return nil
end

return Store
