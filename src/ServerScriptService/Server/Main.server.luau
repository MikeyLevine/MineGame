--!strict
-- Server entry point. Services are plain modules with an Init(); order matters
-- only where one service listens to another's signals before players load.

local Services = script.Parent:WaitForChild("Services")

local ORDER = {
	"StateService", -- listens to DataService signals, so init before data loads
	"ToolService",
	"GateService",
	"OreService",
	"CreatureService",
	"MiningService",
	"ShopService",
	"DrillService",
	"HazardService",
	"ProgressService",
	"TravelService",
	"AscensionService",
	"ArtifactService",
	"MechanismService",
	"AchievementService",
	"EventService",
	"SettingsService",
	"StoreService",
	"PrestigeService",
	"DebugService", -- Studio only
	"DataService", -- last: starts loading players
}

for _, name in ORDER do
	local ok, err = pcall(function()
		require(Services:WaitForChild(name) :: ModuleScript):Init()
	end)
	if not ok then
		warn(`[Main] {name} failed to start:`, err)
	end
end

print("[Deep Mine] Server ready")
