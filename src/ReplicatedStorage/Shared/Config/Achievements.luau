--!strict
-- Achievements. Each has a Progress(data) -> (current, target) function that
-- both the server (to award) and the journal (to show progress) use.
-- Earned ids are saved in data.Achievements (id -> time earned).

local Mines = require(script.Parent.Mines)
local Artifacts = require(script.Parent.Artifacts)
local Equipment = require(script.Parent.Equipment)

export type Achievement = {
	Id: string,
	Name: string,
	Description: string,
	Reward: number,
	Category: string,
	Progress: (data: any) -> (number, number),
}

local function stat(field: string, target: number)
	return function(data): (number, number)
		return math.min(data.Stats[field] or 0, target), target
	end
end

local function mined(resourceId: string, target: number)
	return function(data): (number, number)
		return math.min(data.Stats.Mined[resourceId] or 0, target), target
	end
end

local function completed(mineId: string)
	return function(data): (number, number)
		local state = data.Mines[mineId]
		return if state and state.Completed then 1 else 0, 1
	end
end

local function abyss(target: number)
	return function(data): (number, number)
		return math.min(data.Abyss and data.Abyss.Best or 0, target), target
	end
end

local function prestige(target: number)
	return function(data): (number, number)
		return math.min(data.Prestige or 0, target), target
	end
end

local function tier(field: string, list: { any })
	return function(data): (number, number)
		return math.min(data[field] or 0, #list), #list
	end
end

-- All hidden chambers across every mine.
local hiddenGates = {}
for _, mine in Mines.ById do
	for id, gate in mine.Gates do
		if gate.Hidden then
			table.insert(hiddenGates, id)
		end
	end
end
table.sort(hiddenGates)

local function hiddenFound(target: number?)
	return function(data): (number, number)
		local found = 0
		for _, id in hiddenGates do
			if data.Gates[id] then
				found += 1
			end
		end
		local t = target or #hiddenGates
		return math.min(found, t), t
	end
end

local function artifactsFound(target: number?)
	return function(data): (number, number)
		local found, total = Artifacts.CountIn(data.Artifacts)
		local t = target or total
		return math.min(found, t), t
	end
end

local Achievements = {}

Achievements.HiddenGates = hiddenGates

Achievements.List = {
	-- Mining
	{ Id = "FirstOre", Name = "First Swing", Description = "Mine your first ore.", Reward = 50, Category = "Mining", Progress = stat("TotalMined", 1) },
	{ Id = "Mined500", Name = "Getting the Hang of It", Description = "Mine 500 ore.", Reward = 2000, Category = "Mining", Progress = stat("TotalMined", 500) },
	{ Id = "Mined5000", Name = "Rock Breaker", Description = "Mine 5,000 ore.", Reward = 50000, Category = "Mining", Progress = stat("TotalMined", 5000) },
	{ Id = "Mined25000", Name = "Living Legend", Description = "Mine 25,000 ore.", Reward = 500000, Category = "Mining", Progress = stat("TotalMined", 25000) },
	{ Id = "Coal1000", Name = "Coal Miner", Description = "Mine 1,000 coal.", Reward = 10000, Category = "Mining", Progress = mined("Coal", 1000) },
	{ Id = "Rich1", Name = "Lucky Strike", Description = "Break a rich vein.", Reward = 500, Category = "Mining", Progress = stat("RichVeins", 1) },
	{ Id = "Rich50", Name = "Vein Whisperer", Description = "Break 50 rich veins.", Reward = 75000, Category = "Mining", Progress = stat("RichVeins", 50) },
	{ Id = "Meteor", Name = "Fallen Star", Description = "Mine a meteorite.", Reward = 5000, Category = "Mining", Progress = mined("Meteorite", 1) },

	-- Money
	{ Id = "Earn10k", Name = "Getting Paid", Description = "Earn $10,000 in total.", Reward = 1000, Category = "Money", Progress = stat("TotalEarned", 10000) },
	{ Id = "Earn1M", Name = "Millionaire", Description = "Earn $1,000,000 in total.", Reward = 50000, Category = "Money", Progress = stat("TotalEarned", 1000000) },
	{ Id = "Earn100M", Name = "Mining Tycoon", Description = "Earn $100,000,000 in total.", Reward = 2000000, Category = "Money", Progress = stat("TotalEarned", 100000000) },
	{ Id = "BigSale", Name = "Big Haul", Description = "Sell $100,000 worth of ore in one go.", Reward = 20000, Category = "Money", Progress = stat("BiggestSale", 100000) },

	-- Exploration
	{ Id = "Mine1", Name = "Out of the Dark", Description = "Complete the Abandoned Coal Mine.", Reward = 2500, Category = "Exploration", Progress = completed("Mine1") },
	{ Id = "Mine2", Name = "Crystal Clear", Description = "Complete the Crystal Caverns.", Reward = 50000, Category = "Exploration", Progress = completed("Mine2") },
	{ Id = "Mine3", Name = "Walked Through Fire", Description = "Complete the Lava Depths.", Reward = 250000, Category = "Exploration", Progress = completed("Mine3") },
	{ Id = "Mine4", Name = "Tomb Raider", Description = "Complete the Ancient Depths.", Reward = 1000000, Category = "Exploration", Progress = completed("Mine4") },
	{ Id = "Mine5", Name = "Bottom of the World", Description = "Complete the Unknown Depths.", Reward = 5000000, Category = "Exploration", Progress = completed("Mine5") },
	{ Id = "Hidden1", Name = "Secret Keeper", Description = "Find a hidden chamber.", Reward = 2000, Category = "Exploration", Progress = hiddenFound(1) },
	{ Id = "HiddenAll", Name = "Nothing Stays Hidden", Description = "Find every hidden chamber.", Reward = 500000, Category = "Exploration", Progress = hiddenFound() },
	{ Id = "Artifact1", Name = "Collector", Description = "Find an artifact.", Reward = 2000, Category = "Exploration", Progress = artifactsFound(1) },
	{ Id = "ArtifactAll", Name = "Curator", Description = "Find every artifact.", Reward = 2500000, Category = "Exploration", Progress = artifactsFound() },

	-- Combat & gear
	{ Id = "Creature1", Name = "Monster Hunter", Description = "Defeat a creature.", Reward = 10000, Category = "Gear", Progress = stat("CreaturesDefeated", 1) },
	{ Id = "Creature100", Name = "Exterminator", Description = "Defeat 100 creatures.", Reward = 1000000, Category = "Gear", Progress = stat("CreaturesDefeated", 100) },
	{ Id = "BestPickaxe", Name = "Void Wielder", Description = "Own the best pickaxe.", Reward = 1000000, Category = "Gear", Progress = tier("PickaxeTier", Equipment.Pickaxes) },
	{ Id = "BestBackpack", Name = "Bottomless Bag", Description = "Own the biggest backpack.", Reward = 500000, Category = "Gear", Progress = tier("BackpackTier", Equipment.Backpacks) },
	{ Id = "BestLamp", Name = "Light Bringer", Description = "Own the brightest lamp.", Reward = 20000, Category = "Gear", Progress = tier("LampTier", Equipment.Lamps) },
	{ Id = "Drill", Name = "Power Tools", Description = "Buy a mining drill.", Reward = 20000, Category = "Gear", Progress = function(data)
		return math.min(data.DrillTier or 0, 1), 1
	end },

	-- The Endless Abyss
	{ Id = "Abyss5", Name = "Into the Abyss", Description = "Reach floor 5 of the Endless Abyss.", Reward = 50000, Category = "Abyss", Progress = abyss(5) },
	{ Id = "Abyss10", Name = "Deep Diver", Description = "Reach floor 10 of the Endless Abyss.", Reward = 200000, Category = "Abyss", Progress = abyss(10) },
	{ Id = "Abyss25", Name = "Abyss Walker", Description = "Reach floor 25 of the Endless Abyss.", Reward = 2000000, Category = "Abyss", Progress = abyss(25) },
	{ Id = "Abyss50", Name = "Bottomless", Description = "Reach floor 50 of the Endless Abyss.", Reward = 10000000, Category = "Abyss", Progress = abyss(50) },

	-- Daily streaks
	{ Id = "Daily7", Name = "Creature of Habit", Description = "Claim daily rewards 7 days in a row.", Reward = 25000, Category = "Daily", Progress = function(data)
		return math.min(data.Daily and data.Daily.Best or 0, 7), 7
	end },
	{ Id = "Daily30", Name = "Lifer", Description = "Claim daily rewards 30 days in a row.", Reward = 500000, Category = "Daily", Progress = function(data)
		return math.min(data.Daily and data.Daily.Best or 0, 30), 30
	end },

	-- Prestige (rewards land right after the reset, as a head start)
	{ Id = "Prestige1", Name = "Born Again", Description = "Collapse the mines once.", Reward = 5000, Category = "Prestige", Progress = prestige(1) },
	{ Id = "Prestige3", Name = "Deep Habit", Description = "Reach Prestige 3.", Reward = 25000, Category = "Prestige", Progress = prestige(3) },
	{ Id = "Prestige5", Name = "Endless Descent", Description = "Reach Prestige 5.", Reward = 100000, Category = "Prestige", Progress = prestige(5) },
	{ Id = "Prestige10", Name = "The Deep Remembers", Description = "Reach Prestige 10.", Reward = 500000, Category = "Prestige", Progress = prestige(10) },
} :: { Achievement }

function Achievements.Get(id: string): Achievement?
	for _, a in Achievements.List do
		if a.Id == id then
			return a
		end
	end
	return nil
end

return Achievements
