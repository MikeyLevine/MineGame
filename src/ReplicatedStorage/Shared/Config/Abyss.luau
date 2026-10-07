--!strict
-- The Endless Abyss: procedurally generated floors below the five mines.
-- Every floor is built for one player only (AbyssService). Floors come in
-- bands; each band needs better gear (pickaxe hardness via its ores, suit
-- protection via its hazards), and the last band repeats forever.

export type Band = {
	First: number, -- first floor of this band
	Name: string,
	Weights: { [string]: number }, -- resource id -> spawn weight
	Rock: Enum.Material, -- walls/ceiling terrain
	Floor: Enum.Material, -- walkable floor terrain
	Glow: Color3, -- crystals that light the chambers
	Ambient: Color3,
	AtmosphereColor: Color3,
	AtmosphereDecay: Color3,
	Hazard: { Type: string, Level: number, DamagePerSecond: number }?,
	Creatures: { [string]: number }?, -- creature kind -> weight
	CreaturesPerFloor: number?,
	Ambience: string?,
}

export type Data = { Best: number }

local Abyss = {}

Abyss.LiftId = "Abyss"
Abyss.CheckpointEvery = 5 -- entering from camp starts at the last checkpoint reached

Abyss.Bands = {
	{
		First = 1,
		Name = "Collapsed Workings",
		Weights = { Coal = 40, Copper = 32, Iron = 28 },
		Rock = Enum.Material.Slate,
		Floor = Enum.Material.Ground,
		Glow = Color3.fromRGB(255, 190, 110),
		Ambient = Color3.fromRGB(22, 18, 15),
		AtmosphereColor = Color3.fromRGB(30, 24, 20),
		AtmosphereDecay = Color3.fromRGB(12, 9, 7),
	},
	{
		First = 6,
		Name = "Glimmer Shafts",
		Weights = { Quartz = 30, Silver = 30, Gold = 25, Amethyst = 15 },
		Rock = Enum.Material.Rock,
		Floor = Enum.Material.Slate,
		Glow = Color3.fromRGB(130, 150, 255),
		Ambient = Color3.fromRGB(16, 18, 34),
		AtmosphereColor = Color3.fromRGB(20, 24, 50),
		AtmosphereDecay = Color3.fromRGB(6, 8, 20),
	},
	{
		First = 11,
		Name = "Ember Chasm",
		Weights = { Sulfur = 25, Obsidian = 30, Platinum = 25, MagmaCrystal = 20 },
		Rock = Enum.Material.Basalt,
		Floor = Enum.Material.Basalt,
		Glow = Color3.fromRGB(255, 120, 50),
		Ambient = Color3.fromRGB(34, 16, 10),
		AtmosphereColor = Color3.fromRGB(56, 22, 10),
		AtmosphereDecay = Color3.fromRGB(20, 6, 2),
		Hazard = { Type = "Heat", Level = 1, DamagePerSecond = 12 },
		Ambience = "LavaAmbience",
	},
	{
		First = 16,
		Name = "Drowned Vaults",
		Weights = { AncientBronze = 30, Jade = 30, Orichalcum = 25, RelicShard = 15 },
		Rock = Enum.Material.Sandstone,
		Floor = Enum.Material.Slate,
		Glow = Color3.fromRGB(110, 230, 210),
		Ambient = Color3.fromRGB(14, 26, 26),
		AtmosphereColor = Color3.fromRGB(18, 40, 40),
		AtmosphereDecay = Color3.fromRGB(4, 14, 14),
		Hazard = { Type = "Heat", Level = 2, DamagePerSecond = 18 },
		Ambience = "TempleAmbience",
	},
	{
		First = 21,
		Name = "Hollow Dark",
		Weights = { Voidstone = 45, Xenocrystal = 35, Aetherium = 20 },
		Rock = Enum.Material.Slate,
		Floor = Enum.Material.Basalt,
		Glow = Color3.fromRGB(170, 90, 255),
		Ambient = Color3.fromRGB(24, 14, 36),
		AtmosphereColor = Color3.fromRGB(36, 14, 56),
		AtmosphereDecay = Color3.fromRGB(8, 0, 18),
		Hazard = { Type = "Void", Level = 1, DamagePerSecond = 20 },
		Creatures = { Crawler = 1 },
		CreaturesPerFloor = 2,
		Ambience = "AlienAmbience",
	},
	{
		First = 31,
		Name = "The Endless Dark",
		Weights = { Voidstone = 25, Xenocrystal = 30, Aetherium = 30, SingularityShard = 15 },
		Rock = Enum.Material.Basalt,
		Floor = Enum.Material.Slate,
		Glow = Color3.fromRGB(255, 70, 120),
		Ambient = Color3.fromRGB(26, 8, 16),
		AtmosphereColor = Color3.fromRGB(44, 8, 24),
		AtmosphereDecay = Color3.fromRGB(14, 0, 6),
		Hazard = { Type = "Void", Level = 2, DamagePerSecond = 26 },
		Creatures = { Crawler = 2, Stalker = 1 },
		CreaturesPerFloor = 3,
		Ambience = "AlienAmbience",
	},
} :: { Band }

function Abyss.BandFor(floor: number): Band
	local found = Abyss.Bands[1]
	for _, band in Abyss.Bands do
		if floor >= band.First then
			found = band
		end
	end
	return found
end

-- Rocks get tougher with depth...
function Abyss.HealthMultiplier(floor: number): number
	return 1 + 0.06 * (floor - 1)
end

-- ...and each one pays out more units.
function Abyss.Yield(floor: number): number
	return 1 + (floor - 1) // 5
end

function Abyss.RichChance(floor: number): number
	return math.min(0.04 + 0.002 * floor, 0.12)
end

-- Creatures past their band's first floor get beefier.
function Abyss.CreatureHealthMultiplier(floor: number): number
	return 1 + 0.05 * math.max(0, floor - 21)
end

function Abyss.ChamberCount(floor: number): number
	return math.clamp(4 + floor // 6, 4, 8)
end

-- Fraction of a floor's ore that must be mined to open the Descent Shaft.
Abyss.QuotaFraction = 0.6

-- Cash for reaching a floor for the first time.
function Abyss.RecordBonus(floor: number): number
	return math.floor(1000 * floor ^ 1.6 / 100 + 0.5) * 100
end

-- Where a run from camp starts: the last checkpoint at or below the best floor.
function Abyss.StartFloor(best: number): number
	if best < Abyss.CheckpointEvery then
		return 1
	end
	return (best // Abyss.CheckpointEvery) * Abyss.CheckpointEvery
end

-- Unlocked by completing the final mine (or having prestiged, which requires it).
function Abyss.IsUnlocked(data: any): boolean
	if (data.Prestige or 0) > 0 or (data.Abyss and (data.Abyss.Best or 0) > 0) then
		return true
	end
	local final = data.Mines and data.Mines.Mine5
	return final ~= nil and final.Completed == true
end

return Abyss
