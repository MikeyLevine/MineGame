--!strict
-- Hostile creatures of the Unknown Depths. Spawned by CreatureService at
-- parts in Workspace.Mines.<MineId>.CreatureSpawns (attribute Kind).

export type Creature = {
	Name: string,
	Health: number,
	Damage: number, -- per bite
	AttackCooldown: number,
	Speed: number, -- studs/second (players run at 16)
	AggroRange: number,
	LeashRange: number, -- give up beyond this distance from home
	Reward: number,
	Drops: { [string]: number }, -- resource id -> chance of dropping one
	RespawnSeconds: number,
	Scale: number,
	BodyColor: Color3,
	GlowColor: Color3,
}

return {
	Crawler = {
		Name = "Void Crawler",
		Health = 900,
		Damage = 14,
		AttackCooldown = 1.2,
		Speed = 12,
		AggroRange = 38,
		LeashRange = 70,
		Reward = 8000,
		Drops = { Xenocrystal = 0.5 },
		RespawnSeconds = 45,
		Scale = 1,
		BodyColor = Color3.fromRGB(40, 24, 60),
		GlowColor = Color3.fromRGB(80, 255, 190),
	},
	Stalker = {
		Name = "Abyss Stalker",
		Health = 2400,
		Damage = 24,
		AttackCooldown = 1.1,
		Speed = 17,
		AggroRange = 46,
		LeashRange = 80,
		Reward = 25000,
		Drops = { Aetherium = 0.6, SingularityShard = 0.1 },
		RespawnSeconds = 70,
		Scale = 1.6,
		BodyColor = Color3.fromRGB(20, 12, 30),
		GlowColor = Color3.fromRGB(220, 80, 255),
	},
	-- Mine 6: golden constructs guarding the Worldheart.
	Sentinel = {
		Name = "Gilded Sentinel",
		Health = 6000,
		Damage = 30,
		AttackCooldown = 1.0,
		Speed = 15,
		AggroRange = 44,
		LeashRange = 80,
		Reward = 60000,
		Drops = { Starheart = 0.5, Primordium = 0.1 },
		RespawnSeconds = 80,
		Scale = 1.8,
		BodyColor = Color3.fromRGB(96, 74, 34),
		GlowColor = Color3.fromRGB(255, 220, 120),
	},
} :: { [string]: Creature }
