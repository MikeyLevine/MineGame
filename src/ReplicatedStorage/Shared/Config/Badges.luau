--!strict
-- Roblox badges (they show on players' profiles). Each one mirrors an
-- in-game achievement, or `Welcome` for simply joining. BadgeId is 0 until
-- the badge is created on the Creator Dashboard (Engagement > Badges);
-- badges with id 0 are skipped.

export type Badge = {
	Id: string,
	Name: string,
	Description: string,
	Achievement: string?, -- Config/Achievements id that earns it (nil = on join)
	BadgeId: number,
}

return {
	{ Id = "Welcome", Name = "Welcome to Deep Mine", Description = "Joined Deep Mine for the first time.", BadgeId = 0 },
	{ Id = "Mine1", Name = "Out of the Dark", Description = "Ascended from the Abandoned Coal Mine.", Achievement = "Mine1", BadgeId = 0 },
	{ Id = "Mine2", Name = "Crystal Clear", Description = "Completed the Crystal Caverns.", Achievement = "Mine2", BadgeId = 0 },
	{ Id = "Mine3", Name = "Walked Through Fire", Description = "Completed the Lava Depths.", Achievement = "Mine3", BadgeId = 0 },
	{ Id = "Mine4", Name = "Tomb Raider", Description = "Completed the Ancient Depths.", Achievement = "Mine4", BadgeId = 0 },
	{ Id = "Mine5", Name = "Bottom of the World", Description = "Completed the Unknown Depths.", Achievement = "Mine5", BadgeId = 0 },
	{ Id = "Prestige1", Name = "Born Again", Description = "Collapsed the mines and started over stronger.", Achievement = "Prestige1", BadgeId = 0 },
	{ Id = "Abyss10", Name = "Deep Diver", Description = "Reached floor 10 of the Endless Abyss.", Achievement = "Abyss10", BadgeId = 0 },
	{ Id = "Abyss25", Name = "Abyss Walker", Description = "Reached floor 25 of the Endless Abyss.", Achievement = "Abyss25", BadgeId = 0 },
	{ Id = "Curator", Name = "Curator", Description = "Found every artifact in the deep.", Achievement = "ArtifactAll", BadgeId = 0 },
} :: { Badge }
