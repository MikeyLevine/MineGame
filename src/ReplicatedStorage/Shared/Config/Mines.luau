--!strict
-- Per-mine data: zones (what spawns where), rubble gates, completion
-- requirements, the next mine, lighting, and lift destinations.
-- The physical map lives in Workspace.Mines.<MineId> and is matched by name.

export type Zone = {
	Id: string,
	DisplayName: string,
	RequiredGate: string?, -- gate the player must have broken to mine here
	MaxOres: number, -- ore nodes alive at once (0 = no ore, e.g. a landmark area)
	RespawnSeconds: number,
	Weights: { [string]: number }, -- resource id -> spawn weight
	RichChance: number?, -- chance a node spawns as a sparkling rich vein (3x yield)
	Dark: number?, -- pitch-black area: lamp tier needed to see and mine its ore
}

export type Gate = {
	Id: string,
	DisplayName: string,
	Hardness: number,
	Health: number,
	RequiredPickaxeName: string,
	Hidden: boolean?, -- looks like plain rock; breaking it reveals a secret chamber
	Mechanism: boolean?, -- can't be mined; opened by pressing all its glyphs (see Mechanisms)
}

-- One completion objective. Types:
--   PickaxeTier: own pickaxe tier >= Tier
--   Mined:       lifetime mined count of Resource >= Amount
--   Reach:       have entered zone ZoneId of this mine
--   Gate:        broken at least Amount of the gates in GateIds
--   Equip:       equipment Field (e.g. "SuitTier") >= Tier
--   Artifacts:   found at least Amount artifacts from mine MineId
--   Stat:        data.Stats[Field] >= Amount (e.g. CreaturesDefeated)
export type Requirement = {
	Id: string,
	Type: string,
	Label: string,
	Tier: number?,
	Resource: string?,
	Amount: number?,
	ZoneId: string?,
	GateIds: { string }?,
	Field: string?,
	MineId: string?,
}

export type MineLighting = {
	Ambient: Color3,
	AtmosphereColor: Color3,
	AtmosphereDecay: Color3,
}

export type Mine = {
	Id: string,
	Order: number,
	DisplayName: string,
	Tagline: string,
	WallName: string,
	Zones: { Zone },
	Gates: { [string]: Gate },
	Requirements: { Requirement },
	NextMine: string?,
	Lighting: MineLighting,
	Ambience: string?, -- Sounds key for the cave ambience loop (default CaveAmbience)
	Ending: boolean?, -- completing this mine finishes the game (no next mine)
}

-- Lift destinations offered at the camp lift. Unlock is either a broken gate
-- or a reached mine.
export type Lift = {
	Id: string,
	MineId: string,
	DisplayName: string,
	Description: string,
	UnlockGate: string?,
	UnlockMine: string?,
	Abyss: boolean?, -- the Endless Abyss (AbyssService builds the floor; see Config/Abyss)
}

local Mines = {}

Mines.ById = {
	Mine1 = {
		Id = "Mine1",
		Order = 1,
		DisplayName = "Abandoned Coal Mine",
		Tagline = "Where it all starts.",
		WallName = "The Sealed Wall",
		Zones = {
			{
				Id = "Upper",
				DisplayName = "Upper Tunnels",
				MaxOres = 22,
				RespawnSeconds = 6,
				Weights = { Stone = 55, Coal = 45 },
				RichChance = 0.03,
			},
			{
				Id = "Copper",
				DisplayName = "Copper Seam",
				RequiredGate = "CopperGate",
				MaxOres = 22,
				RespawnSeconds = 8,
				Weights = { Stone = 30, Coal = 30, Copper = 40 },
				RichChance = 0.04,
			},
			{
				Id = "Iron",
				DisplayName = "Iron Hollow",
				RequiredGate = "IronGate",
				MaxOres = 24,
				RespawnSeconds = 10,
				Weights = { Stone = 20, Coal = 15, Copper = 30, Iron = 35 },
				RichChance = 0.04,
			},
			{
				Id = "Workings",
				DisplayName = "The Old Workings",
				RequiredGate = "CopperGate",
				MaxOres = 14,
				RespawnSeconds = 14,
				Weights = { Copper = 40, Iron = 40, Coal = 20 },
				RichChance = 0.15,
				Dark = 2,
			},
			{
				Id = "Final",
				DisplayName = "The Sealed Wall",
				RequiredGate = "IronGate",
				MaxOres = 0,
				RespawnSeconds = 10,
				Weights = {},
			},
		},
		Gates = {
			CopperGate = {
				Id = "CopperGate",
				DisplayName = "Collapsed Rubble",
				Hardness = 2,
				Health = 30,
				RequiredPickaxeName = "Stone Pickaxe",
			},
			IronGate = {
				Id = "IronGate",
				DisplayName = "Caved-in Shaft",
				Hardness = 3,
				Health = 48,
				RequiredPickaxeName = "Iron Pickaxe",
			},
		},
		Requirements = {
			{ Id = "IronPickaxe", Type = "PickaxeTier", Tier = 3, Label = "Own the Iron Pickaxe" },
			{ Id = "Copper", Type = "Mined", Resource = "Copper", Amount = 40, Label = "Mine Copper" },
			{ Id = "Iron", Type = "Mined", Resource = "Iron", Amount = 25, Label = "Mine Iron" },
			{ Id = "Wall", Type = "Reach", ZoneId = "Final", Label = "Find the Sealed Wall" },
		},
		NextMine = "Mine2",
		Lighting = {
			Ambient = Color3.fromRGB(14, 12, 11),
			AtmosphereColor = Color3.fromRGB(26, 22, 20),
			AtmosphereDecay = Color3.fromRGB(12, 10, 9),
		},
	},
	Mine2 = {
		Id = "Mine2",
		Order = 2,
		DisplayName = "Crystal Caverns",
		Tagline = "Something down here is glowing.",
		WallName = "The Crystal Seal",
		Zones = {
			{
				Id = "Grotto",
				DisplayName = "Glimmering Grotto",
				MaxOres = 20,
				RespawnSeconds = 10,
				Weights = { Quartz = 45, Silver = 35, Iron = 20 },
				RichChance = 0.05,
			},
			{
				Id = "Lake",
				DisplayName = "Sunken Lake",
				RequiredGate = "LakeGate",
				MaxOres = 26,
				RespawnSeconds = 12,
				Weights = { Silver = 35, Gold = 40, Quartz = 25 },
				RichChance = 0.06,
			},
			{
				Id = "Geode",
				DisplayName = "Amethyst Geode",
				RequiredGate = "GeodeGate",
				MaxOres = 22,
				RespawnSeconds = 14,
				Weights = { Gold = 30, Amethyst = 45, Silver = 20, PrismCrystal = 5 },
				RichChance = 0.07,
			},
			{
				Id = "Rift",
				DisplayName = "The Lightless Rift",
				RequiredGate = "LakeGate",
				MaxOres = 14,
				RespawnSeconds = 18,
				Weights = { Gold = 35, Amethyst = 35, PrismCrystal = 15, Silver = 15 },
				RichChance = 0.12,
				Dark = 3,
			},
			{
				Id = "HiddenPocket",
				DisplayName = "Forgotten Pocket",
				RequiredGate = "HiddenPocket",
				MaxOres = 6,
				RespawnSeconds = 30,
				Weights = { Gold = 50, Silver = 30, Amethyst = 20 },
				RichChance = 0.35,
			},
			{
				Id = "HiddenVault",
				DisplayName = "Prism Vault",
				RequiredGate = "HiddenVault",
				MaxOres = 6,
				RespawnSeconds = 40,
				Weights = { Amethyst = 50, PrismCrystal = 30, Gold = 20 },
				RichChance = 0.3,
			},
			{
				Id = "Final",
				DisplayName = "The Crystal Seal",
				RequiredGate = "GeodeGate",
				MaxOres = 0,
				RespawnSeconds = 10,
				Weights = {},
			},
		},
		Gates = {
			LakeGate = {
				Id = "LakeGate",
				DisplayName = "Quartz-Choked Passage",
				Hardness = 4,
				Health = 140,
				RequiredPickaxeName = "Reinforced Pickaxe",
			},
			GeodeGate = {
				Id = "GeodeGate",
				DisplayName = "Crystallized Seal",
				Hardness = 5,
				Health = 260,
				RequiredPickaxeName = "Crystal Pickaxe",
			},
			HiddenPocket = {
				Id = "HiddenPocket",
				DisplayName = "Cracked Wall",
				Hardness = 3,
				Health = 40,
				RequiredPickaxeName = "Iron Pickaxe",
				Hidden = true,
			},
			HiddenVault = {
				Id = "HiddenVault",
				DisplayName = "Cracked Wall",
				Hardness = 4,
				Health = 60,
				RequiredPickaxeName = "Reinforced Pickaxe",
				Hidden = true,
			},
		},
		Requirements = {
			{ Id = "CrystalPickaxe", Type = "PickaxeTier", Tier = 6, Label = "Own the Crystal Pickaxe" },
			{ Id = "Gold", Type = "Mined", Resource = "Gold", Amount = 40, Label = "Mine Gold" },
			{ Id = "Amethyst", Type = "Mined", Resource = "Amethyst", Amount = 15, Label = "Mine Amethyst" },
			{ Id = "Hidden", Type = "Gate", GateIds = { "HiddenPocket", "HiddenVault" }, Amount = 1,
				Label = "Discover a hidden chamber" },
			{ Id = "Seal", Type = "Reach", ZoneId = "Final", Label = "Find the Crystal Seal" },
		},
		NextMine = "Mine3",
		Lighting = {
			Ambient = Color3.fromRGB(30, 30, 54),
			AtmosphereColor = Color3.fromRGB(34, 28, 66),
			AtmosphereDecay = Color3.fromRGB(10, 8, 26),
		},
	},
	Mine3 = {
		Id = "Mine3",
		Order = 3,
		DisplayName = "Lava Depths",
		Tagline = "The air itself is burning.",
		WallName = "The Molten Seal",
		Zones = {
			{
				Id = "Scorched",
				DisplayName = "Scorched Antechamber",
				MaxOres = 20,
				RespawnSeconds = 12,
				Weights = { Sulfur = 50, Gold = 25, Amethyst = 15, Obsidian = 10 },
				RichChance = 0.05,
			},
			{
				Id = "Rivers",
				DisplayName = "Lava Rivers",
				RequiredGate = "ObsidianFlow",
				MaxOres = 28,
				RespawnSeconds = 14,
				Weights = { Obsidian = 40, Platinum = 30, Sulfur = 30 },
				RichChance = 0.06,
			},
			{
				Id = "EmberVault",
				DisplayName = "Ember Vault",
				RequiredGate = "EmberVault",
				MaxOres = 6,
				RespawnSeconds = 40,
				Weights = { MagmaCrystal = 45, Platinum = 35, Obsidian = 20 },
				RichChance = 0.3,
			},
			{
				Id = "Core",
				DisplayName = "Magma Core",
				RequiredGate = "MagmaPlug",
				MaxOres = 22,
				RespawnSeconds = 16,
				Weights = { MagmaCrystal = 35, Platinum = 35, Obsidian = 30 },
				RichChance = 0.07,
			},
			{
				Id = "Final",
				DisplayName = "The Molten Seal",
				RequiredGate = "MagmaPlug",
				MaxOres = 0,
				RespawnSeconds = 10,
				Weights = {},
			},
		},
		Gates = {
			ObsidianFlow = {
				Id = "ObsidianFlow",
				DisplayName = "Cooled Obsidian Flow",
				Hardness = 6,
				Health = 320,
				RequiredPickaxeName = "Obsidian Pickaxe",
			},
			MagmaPlug = {
				Id = "MagmaPlug",
				DisplayName = "Magma Plug",
				Hardness = 6,
				Health = 520,
				RequiredPickaxeName = "Obsidian Pickaxe",
			},
			EmberVault = {
				Id = "EmberVault",
				DisplayName = "Cracked Wall",
				Hardness = 6,
				Health = 160,
				RequiredPickaxeName = "Obsidian Pickaxe",
				Hidden = true,
			},
		},
		Requirements = {
			{ Id = "ObsidianPickaxe", Type = "PickaxeTier", Tier = 7, Label = "Own the Obsidian Pickaxe" },
			{ Id = "MagmaSuit", Type = "Equip", Field = "SuitTier", Tier = 2, Label = "Own the Magma Suit" },
			{ Id = "Platinum", Type = "Mined", Resource = "Platinum", Amount = 30, Label = "Mine Platinum" },
			{ Id = "Magma", Type = "Mined", Resource = "MagmaCrystal", Amount = 12, Label = "Mine Magma Crystal" },
			{ Id = "Seal", Type = "Reach", ZoneId = "Final", Label = "Find the Molten Seal" },
		},
		NextMine = "Mine4",
		Lighting = {
			Ambient = Color3.fromRGB(64, 30, 18),
			AtmosphereColor = Color3.fromRGB(90, 34, 12),
			AtmosphereDecay = Color3.fromRGB(40, 10, 2),
		},
		Ambience = "LavaAmbience",
	},
	Mine4 = {
		Id = "Mine4",
		Order = 4,
		DisplayName = "Ancient Depths",
		Tagline = "Someone lived down here. A long, long time ago.",
		WallName = "The Ancient Seal",
		Zones = {
			{
				Id = "Halls",
				DisplayName = "Forgotten Halls",
				MaxOres = 20,
				RespawnSeconds = 14,
				Weights = { Obsidian = 25, Platinum = 25, AncientBronze = 35, Jade = 15 },
				RichChance = 0.05,
			},
			{
				Id = "Library",
				DisplayName = "Lost Library",
				RequiredGate = "LibraryWall",
				MaxOres = 6,
				RespawnSeconds = 40,
				Weights = { Jade = 60, RelicShard = 40 },
				RichChance = 0.3,
			},
			{
				Id = "Temple",
				DisplayName = "Sunken Temple",
				RequiredGate = "TempleDoors",
				MaxOres = 28,
				RespawnSeconds = 16,
				Weights = { AncientBronze = 30, Jade = 25, Orichalcum = 35, RelicShard = 10 },
				RichChance = 0.06,
			},
			{
				Id = "Catacombs",
				DisplayName = "The Catacombs",
				RequiredGate = "TempleDoors",
				MaxOres = 10,
				RespawnSeconds = 24,
				Weights = { RelicShard = 45, Orichalcum = 35, Jade = 20 },
				RichChance = 0.15,
				Dark = 4,
			},
			{
				Id = "SunVault",
				DisplayName = "Sun Vault",
				RequiredGate = "SunDoor",
				MaxOres = 6,
				RespawnSeconds = 40,
				Weights = { Orichalcum = 50, RelicShard = 50 },
				RichChance = 0.4,
			},
			{
				Id = "Final",
				DisplayName = "The Ancient Seal",
				RequiredGate = "TempleDoors",
				MaxOres = 0,
				RespawnSeconds = 10,
				Weights = {},
			},
		},
		Gates = {
			TempleDoors = {
				Id = "TempleDoors",
				DisplayName = "Temple Doors",
				Hardness = 7,
				Health = 700,
				RequiredPickaxeName = "Ancient Pickaxe",
			},
			LibraryWall = {
				Id = "LibraryWall",
				DisplayName = "Cracked Wall",
				Hardness = 6,
				Health = 260,
				RequiredPickaxeName = "Obsidian Pickaxe",
				Hidden = true,
			},
			SunDoor = {
				Id = "SunDoor",
				DisplayName = "Sun Door",
				Hardness = 99,
				Health = 1,
				RequiredPickaxeName = "the three Sun Glyphs",
				Mechanism = true,
			},
		},
		Requirements = {
			{ Id = "AncientPickaxe", Type = "PickaxeTier", Tier = 8, Label = "Own the Ancient Pickaxe" },
			{ Id = "Orichalcum", Type = "Mined", Resource = "Orichalcum", Amount = 30, Label = "Mine Orichalcum" },
			{ Id = "Relics", Type = "Mined", Resource = "RelicShard", Amount = 10, Label = "Mine Relic Shards" },
			{ Id = "Artifacts", Type = "Artifacts", MineId = "Mine4", Amount = 3, Label = "Find temple artifacts" },
			{ Id = "Seal", Type = "Reach", ZoneId = "Final", Label = "Find the Ancient Seal" },
		},
		NextMine = "Mine5",
		Lighting = {
			Ambient = Color3.fromRGB(30, 27, 20),
			AtmosphereColor = Color3.fromRGB(46, 52, 40),
			AtmosphereDecay = Color3.fromRGB(16, 14, 8),
		},
		Ambience = "TempleAmbience",
	},
	Mine5 = {
		Id = "Mine5",
		Order = 5,
		DisplayName = "Unknown Depths",
		Tagline = "Nothing down here was made for you.",
		WallName = "The Last Seal",
		Zones = {
			{
				Id = "Expanse",
				DisplayName = "Shimmering Expanse",
				MaxOres = 22,
				RespawnSeconds = 16,
				Weights = { Voidstone = 45, Orichalcum = 20, RelicShard = 20, Xenocrystal = 15 },
				RichChance = 0.05,
			},
			{
				Id = "Forest",
				DisplayName = "Spore Forest",
				RequiredGate = "Membrane",
				MaxOres = 28,
				RespawnSeconds = 18,
				Weights = { Voidstone = 30, Xenocrystal = 40, Aetherium = 30 },
				RichChance = 0.06,
			},
			{
				Id = "Hollow",
				DisplayName = "The Hollow",
				RequiredGate = "HollowWall",
				MaxOres = 6,
				RespawnSeconds = 45,
				Weights = { Aetherium = 60, SingularityShard = 40 },
				RichChance = 0.3,
			},
			{
				Id = "Core",
				DisplayName = "Abyss Core",
				RequiredGate = "Rift",
				MaxOres = 24,
				RespawnSeconds = 20,
				Weights = { Xenocrystal = 30, Aetherium = 45, SingularityShard = 25 },
				RichChance = 0.07,
			},
			{
				Id = "Final",
				DisplayName = "The Last Seal",
				RequiredGate = "Rift",
				MaxOres = 0,
				RespawnSeconds = 10,
				Weights = {},
			},
			{
				Id = "Heart",
				DisplayName = "Heart of the Deep",
				RequiredGate = "Rift",
				MaxOres = 0,
				RespawnSeconds = 10,
				Weights = {},
			},
		},
		Gates = {
			Membrane = {
				Id = "Membrane",
				DisplayName = "Living Membrane",
				Hardness = 8,
				Health = 1100,
				RequiredPickaxeName = "Void Pickaxe",
			},
			Rift = {
				Id = "Rift",
				DisplayName = "Gravity Rift",
				Hardness = 8,
				Health = 1800,
				RequiredPickaxeName = "Void Pickaxe",
			},
			HollowWall = {
				Id = "HollowWall",
				DisplayName = "Cracked Wall",
				Hardness = 8,
				Health = 600,
				RequiredPickaxeName = "Void Pickaxe",
				Hidden = true,
			},
		},
		Requirements = {
			{ Id = "VoidPickaxe", Type = "PickaxeTier", Tier = 9, Label = "Own the Void Pickaxe" },
			{ Id = "AbyssSuit", Type = "Equip", Field = "SuitTier", Tier = 4, Label = "Own the Abyss Suit" },
			{ Id = "Aetherium", Type = "Mined", Resource = "Aetherium", Amount = 25, Label = "Mine Aetherium" },
			{ Id = "Singularity", Type = "Mined", Resource = "SingularityShard", Amount = 6, Label = "Mine Singularity Shards" },
			{ Id = "Creatures", Type = "Stat", Field = "CreaturesDefeated", Amount = 15, Label = "Defeat creatures" },
			{ Id = "Seal", Type = "Reach", ZoneId = "Final", Label = "Find the Last Seal" },
		},
		Lighting = {
			Ambient = Color3.fromRGB(30, 18, 44),
			AtmosphereColor = Color3.fromRGB(40, 16, 62),
			AtmosphereDecay = Color3.fromRGB(10, 0, 22),
		},
		Ambience = "AlienAmbience",
		Ending = true,
	},
} :: { [string]: Mine }

Mines.Lifts = {
	{
		Id = "IronHollow",
		MineId = "Mine1",
		DisplayName = "Iron Hollow",
		Description = "Mine 1, deep level",
		UnlockGate = "IronGate",
	},
	{
		Id = "CrystalCaverns",
		MineId = "Mine2",
		DisplayName = "Crystal Caverns",
		Description = "Mine 2, Glimmering Grotto",
		UnlockMine = "Mine2",
	},
	{
		Id = "SunkenLake",
		MineId = "Mine2",
		DisplayName = "Sunken Lake",
		Description = "Mine 2, lake level",
		UnlockGate = "LakeGate",
	},
	{
		Id = "LavaDepths",
		MineId = "Mine3",
		DisplayName = "Lava Depths",
		Description = "Mine 3, Scorched Antechamber",
		UnlockMine = "Mine3",
	},
	{
		Id = "LavaRivers",
		MineId = "Mine3",
		DisplayName = "Lava Rivers",
		Description = "Mine 3, river level (bring a Heat Suit!)",
		UnlockGate = "ObsidianFlow",
	},
	{
		Id = "AncientDepths",
		MineId = "Mine4",
		DisplayName = "Ancient Depths",
		Description = "Mine 4, Forgotten Halls",
		UnlockMine = "Mine4",
	},
	{
		Id = "SunkenTemple",
		MineId = "Mine4",
		DisplayName = "Sunken Temple",
		Description = "Mine 4, temple level",
		UnlockGate = "TempleDoors",
	},
	{
		Id = "UnknownDepths",
		MineId = "Mine5",
		DisplayName = "Unknown Depths",
		Description = "Mine 5, Shimmering Expanse",
		UnlockMine = "Mine5",
	},
	{
		Id = "SporeForest",
		MineId = "Mine5",
		DisplayName = "Spore Forest",
		Description = "Mine 5, forest level (bring a Void Suit!)",
		UnlockGate = "Membrane",
	},
	{
		Id = "Abyss",
		MineId = "Abyss",
		DisplayName = "The Endless Abyss",
		Description = "Generated floors that never end",
		Abyss = true,
	},
} :: { Lift }

function Mines.GetZone(mineId: string, zoneId: string): Zone?
	local mine = Mines.ById[mineId]
	if not mine then
		return nil
	end
	for _, zone in mine.Zones do
		if zone.Id == zoneId then
			return zone
		end
	end
	return nil
end

-- Mechanism doors and the glyphs that open them (per player, saved as gates).
Mines.Mechanisms = {
	SunDoor = { "SunGlyph1", "SunGlyph2", "SunGlyph3" },
}

function Mines.GetGate(gateId: string): Gate?
	for _, mine in Mines.ById do
		local gate = mine.Gates[gateId]
		if gate then
			return gate
		end
	end
	return nil
end

function Mines.GetLift(liftId: string): Lift?
	for _, lift in Mines.Lifts do
		if lift.Id == liftId then
			return lift
		end
	end
	return nil
end

return Mines
