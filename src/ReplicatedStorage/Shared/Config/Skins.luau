--!strict
-- Pickaxe skins: purely visual (head/handle colours, glow, swing trail and
-- hit sparks). How each is unlocked:
--   Default      everyone has it
--   Achievement  earned by unlocking an achievement (Requires = achievement id)
--   Prestige     earned at a prestige level (Requires = level)
--   Pass         comes with a game pass (Requires = pass id from Config/Store)
--   Cash         bought with in-game money (Price)
--   Robux        bought with Robux (ProductId, 0 until created on the dashboard)

export type Skin = {
	Id: string,
	Name: string,
	Source: string,
	Requires: (string | number)?,
	Price: number?,
	ProductId: number?,
	HeadColor: Color3,
	HeadMaterial: Enum.Material,
	HandleColor: Color3,
	Glow: boolean?,
	Trail: Color3?,
	Spark: Color3?,
}

local Skins = {}

Skins.List = {
	-- Free
	{ Id = "Classic", Name = "Miner's Classic", Source = "Default", HeadColor = Color3.fromRGB(0, 0, 0),
		HeadMaterial = Enum.Material.Metal, HandleColor = Color3.fromRGB(110, 76, 48) }, -- uses the tier's own look
	{ Id = "FallenStar", Name = "Fallen Star", Source = "Achievement", Requires = "Meteor",
		HeadColor = Color3.fromRGB(255, 150, 70), HeadMaterial = Enum.Material.CrackedLava, HandleColor = Color3.fromRGB(46, 36, 34),
		Spark = Color3.fromRGB(255, 160, 80) },
	{ Id = "Curator", Name = "Curator's Pick", Source = "Achievement", Requires = "ArtifactAll",
		HeadColor = Color3.fromRGB(150, 220, 210), HeadMaterial = Enum.Material.Glass, HandleColor = Color3.fromRGB(60, 50, 40),
		Glow = true, Spark = Color3.fromRGB(150, 220, 210) },
	{ Id = "Reborn", Name = "Reborn", Source = "Prestige", Requires = 1,
		HeadColor = Color3.fromRGB(200, 200, 220), HeadMaterial = Enum.Material.Marble, HandleColor = Color3.fromRGB(70, 70, 90) },
	{ Id = "Deepforged", Name = "Deepforged", Source = "Prestige", Requires = 3,
		HeadColor = Color3.fromRGB(90, 60, 160), HeadMaterial = Enum.Material.Metal, HandleColor = Color3.fromRGB(30, 24, 40),
		Glow = true, Spark = Color3.fromRGB(150, 100, 255) },
	{ Id = "Abyssal", Name = "Abyssal", Source = "Prestige", Requires = 5,
		HeadColor = Color3.fromRGB(20, 10, 30), HeadMaterial = Enum.Material.Neon, HandleColor = Color3.fromRGB(10, 6, 16),
		Glow = true, Trail = Color3.fromRGB(120, 40, 200), Spark = Color3.fromRGB(180, 80, 255) },
	{ Id = "Eternal", Name = "Eternal Miner", Source = "Prestige", Requires = 10,
		HeadColor = Color3.fromRGB(255, 250, 230), HeadMaterial = Enum.Material.Neon, HandleColor = Color3.fromRGB(230, 200, 120),
		Glow = true, Trail = Color3.fromRGB(255, 240, 200), Spark = Color3.fromRGB(255, 250, 220) },

	-- In-game cash (decent looks, a cash sink)
	{ Id = "CopperShine", Name = "Copper Shine", Source = "Cash", Price = 25000,
		HeadColor = Color3.fromRGB(210, 120, 60), HeadMaterial = Enum.Material.Foil, HandleColor = Color3.fromRGB(90, 60, 40) },
	{ Id = "Jade", Name = "Jade Edge", Source = "Cash", Price = 250000,
		HeadColor = Color3.fromRGB(70, 190, 120), HeadMaterial = Enum.Material.Marble, HandleColor = Color3.fromRGB(60, 44, 30) },
	{ Id = "CrystalGlass", Name = "Crystal Glass", Source = "Cash", Price = 1000000,
		HeadColor = Color3.fromRGB(200, 240, 255), HeadMaterial = Enum.Material.Glass, HandleColor = Color3.fromRGB(80, 90, 110),
		Spark = Color3.fromRGB(200, 240, 255) },
	{ Id = "Ember", Name = "Ember", Source = "Cash", Price = 5000000,
		HeadColor = Color3.fromRGB(255, 100, 40), HeadMaterial = Enum.Material.CrackedLava, HandleColor = Color3.fromRGB(40, 30, 28),
		Glow = true, Spark = Color3.fromRGB(255, 120, 50) },

	-- Robux (the best ones: glow + trail + coloured sparks)
	{ Id = "VoidReaper", Name = "Void Reaper", Source = "Robux", ProductId = 3717115600,
		HeadColor = Color3.fromRGB(140, 60, 255), HeadMaterial = Enum.Material.Neon, HandleColor = Color3.fromRGB(20, 10, 30),
		Glow = true, Trail = Color3.fromRGB(160, 80, 255), Spark = Color3.fromRGB(190, 120, 255) },
	{ Id = "Aurora", Name = "Aurora", Source = "Robux", ProductId = 3717115637,
		HeadColor = Color3.fromRGB(90, 255, 200), HeadMaterial = Enum.Material.Neon, HandleColor = Color3.fromRGB(30, 50, 70),
		Glow = true, Trail = Color3.fromRGB(120, 200, 255), Spark = Color3.fromRGB(140, 255, 220) },
	{ Id = "MoltenCore", Name = "Molten Core", Source = "Robux", ProductId = 3717115677,
		HeadColor = Color3.fromRGB(255, 120, 30), HeadMaterial = Enum.Material.Neon, HandleColor = Color3.fromRGB(60, 20, 10),
		Glow = true, Trail = Color3.fromRGB(255, 90, 20), Spark = Color3.fromRGB(255, 180, 60) },
	{ Id = "GoldenRoyal", Name = "Golden Royal", Source = "Pass", Requires = "VIP",
		HeadColor = Color3.fromRGB(255, 205, 70), HeadMaterial = Enum.Material.Foil, HandleColor = Color3.fromRGB(120, 30, 40),
		Glow = true, Trail = Color3.fromRGB(255, 220, 120), Spark = Color3.fromRGB(255, 230, 140) },
} :: { Skin }

function Skins.Get(id: string): Skin?
	for _, s in Skins.List do
		if s.Id == id then
			return s
		end
	end
	return nil
end

-- Whether `data` owns or has earned a skin. `hasPass(id)` reports game pass ownership.
function Skins.IsUnlocked(skin: Skin, data: any, hasPass: (string) -> boolean): boolean
	if skin.Source == "Default" then
		return true
	elseif skin.Source == "Achievement" then
		return data.Achievements ~= nil and data.Achievements[skin.Requires :: string] ~= nil
	elseif skin.Source == "Prestige" then
		return (data.Prestige or 0) >= (skin.Requires :: number)
	elseif skin.Source == "Pass" then
		return hasPass(skin.Requires :: string)
	end
	return data.Skins ~= nil and data.Skins[skin.Id] == true
end

function Skins.UnlockHint(skin: Skin): string
	if skin.Source == "Achievement" then
		return `Achievement reward`
	elseif skin.Source == "Prestige" then
		return `Reach Prestige {skin.Requires}`
	elseif skin.Source == "Pass" then
		return "Comes with VIP Miner"
	end
	return ""
end

return Skins
