--!strict
-- Every equipment line the player can upgrade. Index = tier.
--  * Pickaxe / Backpack / Lamp start at tier 1 (owned from the start).
--  * Suit / Drill start at tier 0 (not owned).
-- Hardness gates which resources (and rubble gates) a pickaxe can break, and a
-- lamp's Tier gates which dark areas you can work in, so upgrades open new
-- parts of the world instead of only adding numbers.

export type Pickaxe = {
	Name: string,
	Price: number,
	Power: number, -- damage per swing
	Hardness: number, -- highest resource/gate hardness it can break
	Cooldown: number, -- seconds between swings
	HeadColor: Color3,
	HeadMaterial: Enum.Material,
	Glow: boolean?,
	Blurb: string,
}

export type Backpack = {
	Name: string,
	Price: number,
	Capacity: number,
	Color: Color3,
	Blurb: string,
}

export type Lamp = {
	Name: string,
	Price: number,
	Range: number, -- headlamp spotlight reach
	Brightness: number,
	GlowRange: number, -- light around the player
	GlowBrightness: number,
	Color: Color3,
	HipLantern: boolean, -- show a lantern hanging from the belt
	Blurb: string,
}

-- Unlock rules for items that need more than cash.
export type Requires = {
	PickaxeTier: number?,
	MineVisited: string?,
	Hint: string,
}

export type Suit = {
	Name: string,
	Price: number,
	Protection: { [string]: number }, -- hazard type -> protection level
	Color: Color3,
	Requires: Requires?,
	Blurb: string,
}

export type Drill = {
	Name: string,
	Price: number,
	Power: number, -- damage per tick to the target
	Tick: number, -- seconds between ticks
	Hardness: number,
	SplashRadius: number, -- nearby ore within this many studs of the target also takes damage
	SplashMultiplier: number,
	HeatPerTick: number, -- heat 0..100; at 100 the drill overheats
	CoolPerSecond: number,
	OverheatSeconds: number, -- lockout after overheating
	Requires: Requires?,
	Blurb: string,
}

local Equipment = {}

Equipment.Pickaxes = {
	{
		Name = "Rusty Pickaxe",
		Price = 0,
		Power = 1,
		Hardness = 1,
		Cooldown = 0.4,
		HeadColor = Color3.fromRGB(122, 74, 46),
		HeadMaterial = Enum.Material.CorrodedMetal,
		Blurb = "Found it in the camp. It mostly works.",
	},
	{
		Name = "Stone Pickaxe",
		Price = 75,
		Power = 2,
		Hardness = 2,
		Cooldown = 0.36,
		HeadColor = Color3.fromRGB(128, 126, 120),
		HeadMaterial = Enum.Material.Slate,
		Blurb = "Breaks copper and the rubble below the upper tunnels.",
	},
	{
		Name = "Iron Pickaxe",
		Price = 450,
		Power = 3,
		Hardness = 3,
		Cooldown = 0.32,
		HeadColor = Color3.fromRGB(170, 170, 176),
		HeadMaterial = Enum.Material.Metal,
		Blurb = "Breaks iron and the collapsed shaft to the deep cave.",
	},
	{
		Name = "Steel Pickaxe",
		Price = 2000,
		Power = 5,
		Hardness = 3,
		Cooldown = 0.27,
		HeadColor = Color3.fromRGB(90, 110, 130),
		HeadMaterial = Enum.Material.Metal,
		Blurb = "Much faster on everything you can mine so far.",
	},
	{
		Name = "Reinforced Pickaxe",
		Price = 8000,
		Power = 7,
		Hardness = 4,
		Cooldown = 0.26,
		HeadColor = Color3.fromRGB(196, 150, 60),
		HeadMaterial = Enum.Material.DiamondPlate,
		Blurb = "Breaks gold and the quartz-choked passage to the Sunken Lake.",
	},
	{
		Name = "Crystal Pickaxe",
		Price = 45000,
		Power = 11,
		Hardness = 5,
		Cooldown = 0.24,
		HeadColor = Color3.fromRGB(176, 120, 255),
		HeadMaterial = Enum.Material.Neon,
		Glow = true,
		Blurb = "Cuts amethyst, prism crystal and the crystallized seal.",
	},
	{
		Name = "Obsidian Pickaxe",
		Price = 150000,
		Power = 16,
		Hardness = 6,
		Cooldown = 0.22,
		HeadColor = Color3.fromRGB(30, 22, 36),
		HeadMaterial = Enum.Material.Glass,
		Glow = false,
		Blurb = "Volcanic glass edge. Breaks obsidian, platinum and magma.",
	},
	{
		Name = "Ancient Pickaxe",
		Price = 600000,
		Power = 24,
		Hardness = 7,
		Cooldown = 0.2,
		HeadColor = Color3.fromRGB(220, 176, 80),
		HeadMaterial = Enum.Material.Foil,
		Glow = true,
		Blurb = "Forged by a lost civilization. Opens the Temple Doors.",
	},
	{
		Name = "Void Pickaxe",
		Price = 3000000,
		Power = 40,
		Hardness = 8,
		Cooldown = 0.18,
		HeadColor = Color3.fromRGB(150, 80, 255),
		HeadMaterial = Enum.Material.Neon,
		Glow = true,
		Blurb = "Made of something that shouldn't exist. Cuts through the Unknown Depths.",
	},
} :: { Pickaxe }

Equipment.Backpacks = {
	{ Name = "Small Backpack", Price = 0, Capacity = 15, Color = Color3.fromRGB(120, 92, 64), Blurb = "A sack with straps." },
	{ Name = "Mining Backpack", Price = 120, Capacity = 30, Color = Color3.fromRGB(96, 110, 70), Blurb = "Double the carry." },
	{ Name = "Reinforced Backpack", Price = 500, Capacity = 60, Color = Color3.fromRGB(80, 84, 96), Blurb = "Steel frame, canvas sides." },
	{ Name = "Large Backpack", Price = 2500, Capacity = 120, Color = Color3.fromRGB(140, 60, 50), Blurb = "Fewer trips, more ore." },
	{ Name = "Industrial Backpack", Price = 15000, Capacity = 200, Color = Color3.fromRGB(70, 80, 60), Blurb = "Built for long crystal runs." },
	{ Name = "Advanced Backpack", Price = 60000, Capacity = 320, Color = Color3.fromRGB(60, 70, 110), Blurb = "Compressed storage cells. Barely fits through tunnels." },
	{ Name = "Relic Hauler", Price = 400000, Capacity = 500, Color = Color3.fromRGB(150, 120, 70), Blurb = "Reinforced crates on a frame. Built for temple runs." },
	{ Name = "Void Satchel", Price = 2500000, Capacity = 800, Color = Color3.fromRGB(80, 40, 120), Blurb = "Bigger on the inside. Don't look in too long." },
} :: { Backpack }

Equipment.Lamps = {
	{
		Name = "Headlamp",
		Price = 0,
		Range = 30,
		Brightness = 1.2,
		GlowRange = 12,
		GlowBrightness = 0.4,
		Color = Color3.fromRGB(255, 226, 180),
		HipLantern = false,
		Blurb = "Better than nothing.",
	},
	{
		Name = "Miner's Lantern",
		Price = 600,
		Range = 40,
		Brightness = 1.5,
		GlowRange = 18,
		GlowBrightness = 0.7,
		Color = Color3.fromRGB(255, 214, 160),
		HipLantern = true,
		Blurb = "Bright enough to work the Old Workings.",
	},
	{
		Name = "Carbide Lamp",
		Price = 6000,
		Range = 52,
		Brightness = 1.9,
		GlowRange = 24,
		GlowBrightness = 0.9,
		Color = Color3.fromRGB(240, 240, 255),
		HipLantern = true,
		Blurb = "A hard white flame. Cuts through the Lightless Rift.",
	},
	{
		Name = "Crystal Lamp",
		Price = 30000,
		Range = 66,
		Brightness = 1.8,
		GlowRange = 30,
		GlowBrightness = 0.9,
		Color = Color3.fromRGB(190, 230, 255),
		HipLantern = true,
		Blurb = "A caged prism shard. Lights up whole chambers.",
	},
} :: { Lamp }

Equipment.Suits = {
	{
		Name = "Heat Suit",
		Price = 30000,
		Protection = { Heat = 1 },
		Color = Color3.fromRGB(200, 120, 60),
		Requires = { MineVisited = "Mine3", Hint = "Needed in the Lava Depths" },
		Blurb = "Insulated layers. Survive the heat of the Lava Rivers.",
	},
	{
		Name = "Magma Suit",
		Price = 120000,
		Protection = { Heat = 2 },
		Color = Color3.fromRGB(150, 50, 30),
		Requires = { MineVisited = "Mine3", Hint = "Needed in the Lava Depths" },
		Blurb = "Ceramic plates over the heat layers. Walk the Magma Core.",
	},
	{
		Name = "Void Suit",
		Price = 1000000,
		Protection = { Heat = 2, Void = 1 },
		Color = Color3.fromRGB(90, 50, 150),
		Requires = { MineVisited = "Mine5", Hint = "Needed in the Unknown Depths" },
		Blurb = "Sealed against the corrosive air of the Spore Forest.",
	},
	{
		Name = "Abyss Suit",
		Price = 4000000,
		Protection = { Heat = 2, Void = 2 },
		Color = Color3.fromRGB(40, 20, 70),
		Requires = { MineVisited = "Mine5", Hint = "Needed in the Unknown Depths" },
		Blurb = "Pressure-rated for the Abyss Core.",
	},
} :: { Suit }

Equipment.Drills = {
	{
		Name = "Mining Drill Mk I",
		Price = 60000,
		Power = 6,
		Tick = 0.12,
		Hardness = 5,
		SplashRadius = 7,
		SplashMultiplier = 0.5,
		HeatPerTick = 5,
		CoolPerSecond = 22,
		OverheatSeconds = 2.5,
		Requires = { PickaxeTier = 6, Hint = "Requires the Crystal Pickaxe" },
		Blurb = "Hold to grind through whole clusters. Watch the heat.",
	},
	{
		Name = "Mining Drill Mk II",
		Price = 220000,
		Power = 10,
		Tick = 0.11,
		Hardness = 6,
		SplashRadius = 9,
		SplashMultiplier = 0.5,
		HeatPerTick = 4.5,
		CoolPerSecond = 26,
		OverheatSeconds = 2,
		Requires = { PickaxeTier = 7, Hint = "Requires the Obsidian Pickaxe" },
		Blurb = "Tungsten bit, bigger cooler. Chews through obsidian.",
	},
	{
		Name = "Mining Drill Mk III",
		Price = 900000,
		Power = 15,
		Tick = 0.1,
		Hardness = 7,
		SplashRadius = 10,
		SplashMultiplier = 0.55,
		HeatPerTick = 4,
		CoolPerSecond = 30,
		OverheatSeconds = 1.8,
		Requires = { PickaxeTier = 8, Hint = "Requires the Ancient Pickaxe" },
		Blurb = "Gold-inlaid bit copied from temple carvings.",
	},
	{
		Name = "Void Drill",
		Price = 5000000,
		Power = 26,
		Tick = 0.09,
		Hardness = 8,
		SplashRadius = 12,
		SplashMultiplier = 0.6,
		HeatPerTick = 3.5,
		CoolPerSecond = 34,
		OverheatSeconds = 1.6,
		Requires = { PickaxeTier = 9, Hint = "Requires the Void Pickaxe" },
		Blurb = "Hums at a frequency you can feel in your teeth.",
	},
} :: { Drill }

-- Shop categories, in display order. Field = the data field holding the tier;
-- StartTier = tier everyone owns from the start (0 = nothing).
Equipment.Categories = {
	{ Id = "Pickaxe", Name = "Pickaxe", Field = "PickaxeTier", StartTier = 1 },
	{ Id = "Backpack", Name = "Backpack", Field = "BackpackTier", StartTier = 1 },
	{ Id = "Lamp", Name = "Lamp", Field = "LampTier", StartTier = 1 },
	{ Id = "Suit", Name = "Suit", Field = "SuitTier", StartTier = 0 },
	{ Id = "Drill", Name = "Drill", Field = "DrillTier", StartTier = 0 },
}

function Equipment.List(categoryId: string): { any }
	return (({
		Pickaxe = Equipment.Pickaxes,
		Backpack = Equipment.Backpacks,
		Lamp = Equipment.Lamps,
		Suit = Equipment.Suits,
		Drill = Equipment.Drills,
	}) :: any)[categoryId] or {}
end

function Equipment.Category(categoryId: string)
	for _, c in Equipment.Categories do
		if c.Id == categoryId then
			return c
		end
	end
	return nil
end

-- Whether `data` meets an item's non-cash requirements. Returns (ok, hint).
function Equipment.MeetsRequirements(item: any, data: any): (boolean, string?)
	local req: Requires? = item.Requires
	if not req then
		return true, nil
	end
	if req.PickaxeTier and (data.PickaxeTier or 1) < req.PickaxeTier then
		return false, req.Hint
	end
	if req.MineVisited then
		local mines = data.Mines or {}
		local state = mines[req.MineVisited]
		if not (state and state.Visited) then
			return false, req.Hint
		end
	end
	return true, nil
end

return Equipment
