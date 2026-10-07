--!strict
-- Global tuning values that don't belong to a specific resource or mine.

return {
	DataStoreName = "DeepMine_PlayerData_v1",
	DataVersion = 1,
	AutosaveSeconds = 60,
	-- A save lock older than this is treated as left behind by a crashed server.
	SessionLockStaleSeconds = 600,

	-- Server-side reach check (studs from HumanoidRootPart to target surface).
	MineRange = 13,
	-- Swings arriving faster than Cooldown * this are dropped (allows for network jitter).
	CooldownTolerance = 0.8,

	StartingCash = 0,
}
