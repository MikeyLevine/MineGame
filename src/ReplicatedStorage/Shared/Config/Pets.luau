--!strict
-- Pets: small companions that float behind the player and each give one
-- bonus. Hatched from eggs at the camp Pet Nursery with in-game cash (one
-- egg per mine, unlocked by reaching that mine), or bought directly with
-- Robux (never random: a Robux purchase always gives that exact pet).
--
-- Bonus types feed Shared/Modifiers:
--   Sell      +X% sell value
--   Power     +X% mining power
--   Luck      +X% rich-vein luck
--   Capacity  +X% backpack capacity

export type Pet = {
	Id: string,
	Name: string,
	Rarity: string, -- Common | Rare | Epic | Legendary
	Egg: string?, -- egg id (nil for Robux pets)
	Weight: number?, -- hatch weight inside its egg
	ProductId: number?, -- Robux pets: Developer Product id (0 = not created yet)
	Bonus: { Type: string, Amount: number }, -- Amount is a fraction (0.05 = +5%)
	Body: Color3,
	Accent: Color3,
	Shape: string, -- Blob | Bat | Crystal | Golem | Wisp | Bug
	Glow: boolean?,
}

export type Egg = {
	Id: string,
	Name: string,
	Price: number,
	MineVisited: string?, -- must have reached this mine to hatch it
	Color: Color3,
}

local Pets = {}

Pets.EquipSlots = 3
Pets.MaxOwned = 60
Pets.ReleaseFraction = 0.25 -- releasing a pet refunds this share of its egg's price

Pets.Rarities = {
	Common = Color3.fromRGB(200, 200, 200),
	Rare = Color3.fromRGB(90, 160, 255),
	Epic = Color3.fromRGB(190, 110, 255),
	Legendary = Color3.fromRGB(255, 190, 60),
}

Pets.Eggs = {
	{ Id = "CaveEgg", Name = "Cave Egg", Price = 5000, Color = Color3.fromRGB(150, 120, 90) },
	{ Id = "CrystalEgg", Name = "Crystal Egg", Price = 80000, MineVisited = "Mine2", Color = Color3.fromRGB(140, 170, 255) },
	{ Id = "EmberEgg", Name = "Ember Egg", Price = 600000, MineVisited = "Mine3", Color = Color3.fromRGB(255, 120, 50) },
	{ Id = "RelicEgg", Name = "Relic Egg", Price = 4000000, MineVisited = "Mine4", Color = Color3.fromRGB(110, 220, 200) },
	{ Id = "AbyssalEgg", Name = "Abyssal Egg", Price = 20000000, MineVisited = "Mine5", Color = Color3.fromRGB(160, 80, 255) },
	{ Id = "GildedEgg", Name = "Gilded Egg", Price = 80000000, MineVisited = "Mine6", Color = Color3.fromRGB(255, 200, 90) },
} :: { Egg }

local function pet(id, name, rarity, egg, weight, bonusType, amount, body, accent, shape, glow): Pet
	return {
		Id = id, Name = name, Rarity = rarity, Egg = egg, Weight = weight,
		Bonus = { Type = bonusType, Amount = amount }, Body = body, Accent = accent, Shape = shape, Glow = glow,
	}
end

Pets.List = {
	-- Cave Egg
	pet("Pebble", "Pebble", "Common", "CaveEgg", 60, "Sell", 0.03, Color3.fromRGB(130, 120, 110), Color3.fromRGB(90, 80, 70), "Blob"),
	pet("Mole", "Mole", "Common", "CaveEgg", 30, "Power", 0.03, Color3.fromRGB(90, 70, 60), Color3.fromRGB(240, 170, 170), "Blob"),
	pet("Glowworm", "Glowworm", "Rare", "CaveEgg", 8, "Luck", 0.08, Color3.fromRGB(120, 200, 90), Color3.fromRGB(220, 255, 140), "Bug", true),
	pet("LanternBug", "Lantern Bug", "Epic", "CaveEgg", 2, "Capacity", 0.10, Color3.fromRGB(80, 60, 40), Color3.fromRGB(255, 200, 110), "Bug", true),
	-- Crystal Egg
	pet("Shardling", "Shardling", "Common", "CrystalEgg", 60, "Sell", 0.05, Color3.fromRGB(150, 170, 230), Color3.fromRGB(220, 230, 255), "Crystal"),
	pet("GeodeCrab", "Geode Crab", "Common", "CrystalEgg", 30, "Capacity", 0.06, Color3.fromRGB(110, 100, 120), Color3.fromRGB(190, 120, 255), "Golem"),
	pet("PrismBat", "Prism Bat", "Rare", "CrystalEgg", 8, "Luck", 0.12, Color3.fromRGB(60, 60, 110), Color3.fromRGB(140, 220, 255), "Bat", true),
	pet("CrystalDrake", "Crystal Drake", "Epic", "CrystalEgg", 2, "Power", 0.12, Color3.fromRGB(120, 140, 255), Color3.fromRGB(230, 240, 255), "Bat", true),
	-- Ember Egg
	pet("Cinder", "Cinder", "Common", "EmberEgg", 60, "Power", 0.06, Color3.fromRGB(60, 40, 36), Color3.fromRGB(255, 120, 40), "Blob", true),
	pet("MagmaSlug", "Magma Slug", "Common", "EmberEgg", 30, "Sell", 0.07, Color3.fromRGB(120, 50, 30), Color3.fromRGB(255, 160, 60), "Blob"),
	pet("FlareMoth", "Flare Moth", "Rare", "EmberEgg", 8, "Luck", 0.16, Color3.fromRGB(90, 40, 30), Color3.fromRGB(255, 200, 80), "Bug", true),
	pet("EmberPhoenix", "Ember Phoenix", "Legendary", "EmberEgg", 2, "Sell", 0.25, Color3.fromRGB(255, 100, 40), Color3.fromRGB(255, 220, 120), "Bat", true),
	-- Relic Egg
	pet("Scarab", "Scarab", "Common", "RelicEgg", 60, "Sell", 0.09, Color3.fromRGB(40, 90, 80), Color3.fromRGB(255, 200, 80), "Bug"),
	pet("StoneIdol", "Stone Idol", "Rare", "RelicEgg", 30, "Capacity", 0.15, Color3.fromRGB(150, 140, 110), Color3.fromRGB(110, 230, 210), "Golem", true),
	pet("SunCat", "Sun Cat", "Epic", "RelicEgg", 8, "Power", 0.18, Color3.fromRGB(230, 190, 110), Color3.fromRGB(255, 240, 180), "Blob", true),
	pet("PharaohOwl", "Pharaoh Owl", "Legendary", "RelicEgg", 2, "Luck", 0.40, Color3.fromRGB(60, 50, 90), Color3.fromRGB(255, 205, 80), "Bat", true),
	-- Abyssal Egg
	pet("Voidling", "Voidling", "Common", "AbyssalEgg", 60, "Power", 0.10, Color3.fromRGB(40, 24, 60), Color3.fromRGB(170, 90, 255), "Wisp", true),
	pet("SporePuff", "Spore Puff", "Rare", "AbyssalEgg", 30, "Sell", 0.15, Color3.fromRGB(110, 50, 140), Color3.fromRGB(255, 120, 220), "Blob", true),
	pet("RiftEel", "Rift Eel", "Epic", "AbyssalEgg", 8, "Capacity", 0.25, Color3.fromRGB(20, 20, 40), Color3.fromRGB(80, 255, 190), "Wisp", true),
	pet("StarEater", "Star Eater", "Legendary", "AbyssalEgg", 2, "Power", 0.30, Color3.fromRGB(15, 10, 25), Color3.fromRGB(255, 255, 255), "Bat", true),
	-- Gilded Egg
	pet("SunSprite", "Sun Sprite", "Rare", "GildedEgg", 60, "Sell", 0.18, Color3.fromRGB(255, 220, 140), Color3.fromRGB(255, 250, 220), "Wisp", true),
	pet("GoldGolem", "Gold Golem", "Epic", "GildedEgg", 30, "Capacity", 0.30, Color3.fromRGB(200, 150, 60), Color3.fromRGB(255, 230, 150), "Golem", true),
	pet("CoreWyrm", "Core Wyrm", "Legendary", "GildedEgg", 8, "Sell", 0.35, Color3.fromRGB(255, 140, 50), Color3.fromRGB(255, 240, 200), "Bat", true),
	pet("OriginSpirit", "Origin Spirit", "Legendary", "GildedEgg", 2, "Luck", 0.60, Color3.fromRGB(120, 255, 230), Color3.fromRGB(255, 255, 255), "Wisp", true),
	-- Robux (direct purchase, never random)
	{ Id = "NebulaFox", Name = "Nebula Fox", Rarity = "Legendary", ProductId = 0, Bonus = { Type = "Sell", Amount = 0.25 },
		Body = Color3.fromRGB(60, 40, 120), Accent = Color3.fromRGB(255, 120, 230), Shape = "Blob", Glow = true },
	{ Id = "AuroraWhale", Name = "Aurora Whale", Rarity = "Legendary", ProductId = 0, Bonus = { Type = "Power", Amount = 0.25 },
		Body = Color3.fromRGB(40, 90, 120), Accent = Color3.fromRGB(120, 255, 220), Shape = "Wisp", Glow = true },
} :: { Pet }

Pets.BonusLabels = {
	Sell = "sell value",
	Power = "mining power",
	Luck = "rich-vein luck",
	Capacity = "backpack space",
}

local byId: { [string]: Pet } = {}
for _, p in Pets.List do
	byId[p.Id] = p
end

function Pets.Get(id: string): Pet?
	return byId[id]
end

function Pets.GetEgg(id: string): Egg?
	for _, e in Pets.Eggs do
		if e.Id == id then
			return e
		end
	end
	return nil
end

function Pets.InEgg(eggId: string): { Pet }
	local list = {}
	for _, p in Pets.List do
		if p.Egg == eggId then
			table.insert(list, p)
		end
	end
	return list
end

-- Hatch chance (0..1) of each pet in an egg.
function Pets.Chance(p: Pet): number
	if not p.Egg or not p.Weight then
		return 0
	end
	local total = 0
	for _, other in Pets.InEgg(p.Egg) do
		total += other.Weight or 0
	end
	return if total > 0 then p.Weight / total else 0
end

function Pets.BonusText(p: Pet): string
	return `+{math.floor(p.Bonus.Amount * 100 + 0.5)}% {Pets.BonusLabels[p.Bonus.Type] or p.Bonus.Type}`
end

-- Summed bonus fraction of one type from the equipped pets.
function Pets.Bonus(data: any, bonusType: string): number
	local sum = 0
	for _, id in data.EquippedPets or {} do
		local p = byId[id]
		if p and p.Bonus.Type == bonusType then
			sum += p.Bonus.Amount
		end
	end
	return sum
end

function Pets.CountOwned(data: any): number
	local n = 0
	for _, count in data.Pets or {} do
		n += count
	end
	return n
end

function Pets.CanHatch(egg: Egg, data: any): (boolean, string?)
	if egg.MineVisited then
		local state = data.Mines and data.Mines[egg.MineVisited]
		if not (state and state.Visited) then
			return false, "Reach a deeper mine to unlock this egg"
		end
	end
	return true, nil
end

return Pets
