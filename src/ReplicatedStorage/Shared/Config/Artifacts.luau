--!strict
-- Unique collectibles hidden around the mines. Each is a pedestal in the map
-- (tagged "Artifact", attribute ArtifactId) that a player can take once.
-- Taking one pays Reward and adds it to the player's saved collection.

export type Artifact = {
	Id: string,
	Name: string,
	Mine: string,
	Reward: number,
	Color: Color3,
	Shape: string, -- how the builder models it: Lantern | Heart | Crown | Tablet | Mask | Book | Disk
	Lore: string,
	RequiresCompleted: string?, -- only takeable after completing this mine
}

local Artifacts = {}

Artifacts.List = {
	{
		Id = "LuckyLantern",
		Name = "Lucky Lantern",
		Mine = "Mine1",
		Reward = 1500,
		Color = Color3.fromRGB(255, 200, 110),
		Shape = "Lantern",
		Lore = "A battered lantern scratched with the initials J.H. Someone worked these tunnels long before you, and left their light behind.",
	},
	{
		Id = "CrystalHeart",
		Name = "Crystal Heart",
		Mine = "Mine2",
		Reward = 20000,
		Color = Color3.fromRGB(200, 240, 255),
		Shape = "Heart",
		Lore = "It beats, faintly, when you hold it. The crystals of the caverns hum in time with it.",
	},
	{
		Id = "EmberCrown",
		Name = "Ember Crown",
		Mine = "Mine3",
		Reward = 80000,
		Color = Color3.fromRGB(255, 120, 40),
		Shape = "Crown",
		Lore = "Forged in the magma core and never quite cooled. Whoever wore it ruled something down here.",
	},
	{
		Id = "StarMap",
		Name = "Star Map Tablet",
		Mine = "Mine4",
		Reward = 150000,
		Color = Color3.fromRGB(120, 220, 255),
		Shape = "Tablet",
		Lore = "Stars carved into stone, though no sky was ever visible this deep. The map points further down.",
	},
	{
		Id = "GildedMask",
		Name = "Gilded Mask",
		Mine = "Mine4",
		Reward = 200000,
		Color = Color3.fromRGB(255, 210, 90),
		Shape = "Mask",
		Lore = "A burial mask from the catacombs. Its eyes are polished jade, and they seem to follow you.",
	},
	{
		Id = "ScholarsCodex",
		Name = "Scholar's Codex",
		Mine = "Mine4",
		Reward = 180000,
		Color = Color3.fromRGB(110, 200, 150),
		Shape = "Book",
		Lore = "Pages of thin bronze. The last page describes a door that opens to the sun, deep underground.",
	},
	{
		Id = "SunDisk",
		Name = "Sun Disk",
		Mine = "Mine4",
		Reward = 300000,
		Color = Color3.fromRGB(255, 220, 120),
		Shape = "Disk",
		Lore = "The heart of the temple. It is warm, and it glows brighter the deeper you carry it.",
	},
	{
		Id = "VoidEgg",
		Name = "Void Egg",
		Mine = "Mine5",
		Reward = 1000000,
		Color = Color3.fromRGB(170, 80, 255),
		Shape = "Heart",
		Lore = "Warm, and something inside it moves when you aren't looking. The creatures down here seem to want it back.",
	},
	{
		Id = "HeartOfTheDeep",
		Name = "Heart of the Deep",
		Mine = "Mine5",
		Reward = 5000000,
		Color = Color3.fromRGB(255, 240, 200),
		Shape = "Disk",
		Lore = "The bottom of the world. Every mine above was dug by someone looking for this. You found it.",
		RequiresCompleted = "Mine5",
	},
} :: { Artifact }

function Artifacts.Get(id: string): Artifact?
	for _, a in Artifacts.List do
		if a.Id == id then
			return a
		end
	end
	return nil
end

function Artifacts.CountIn(owned: { [string]: boolean }?, mineId: string?): (number, number)
	local have, total = 0, 0
	for _, a in Artifacts.List do
		if not mineId or a.Mine == mineId then
			total += 1
			if owned and owned[a.Id] then
				have += 1
			end
		end
	end
	return have, total
end

return Artifacts
