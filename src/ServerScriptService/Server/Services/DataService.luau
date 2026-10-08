--!strict
-- Loads, holds and saves player progression.
--
-- Records are stored as { Data = <player data>, Lock = { JobId, Time }? }.
-- The lock stops two servers from writing the same player at once (e.g. a fast
-- rejoin before the old server finished saving). Autosave refreshes the lock;
-- a lock older than SessionLockStaleSeconds is assumed abandoned by a crash.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Signal = require(Shared.Util.Signal)

export type Data = {
	Version: number,
	Cash: number,
	PickaxeTier: number,
	BackpackTier: number,
	LampTier: number,
	SuitTier: number,
	DrillTier: number,
	Backpack: { [string]: number },
	Gates: { [string]: boolean },
	-- Per mine: zones reached, visited (arrived at least once), completed (ascended).
	Mines: { [string]: { Reached: { [string]: boolean }?, Visited: boolean?, Completed: boolean? } },
	Artifacts: { [string]: boolean },
	Achievements: { [string]: number }, -- id -> os.time() earned
	Settings: { Sfx: number, Ambience: number, Shake: boolean, Objectives: boolean, Hints: boolean },
	Prestige: number,
	Boosts: { [string]: number },
	Skins: { [string]: boolean },
	EquippedSkin: string,
	Purchases: { [string]: boolean },
	RunMined: { [string]: number }, -- ore mined since the last prestige (mine requirements)
	Abyss: { Best: number }, -- deepest Endless Abyss floor reached (kept through prestige)
	Daily: { Streak: number, LastDay: number, Best: number }, -- daily rewards (LastDay = UTC day number)
	Badges: { [string]: boolean }, -- Roblox badges already awarded (Config/Badges ids)
	GroupRewardClaimed: boolean,
	Pets: { [string]: number }, -- pet id -> how many owned (Config/Pets)
	EquippedPets: { string }, -- equipped pet ids (duplicates allowed up to the owned count)
	Stats: {
		TotalMined: number,
		TotalEarned: number,
		Mined: { [string]: number },
		CreaturesDefeated: number,
		RichVeins: number,
		BiggestSale: number,
		Hatched: number?,
	},
}

type Profile = {
	Data: Data,
	CanSave: boolean,
	Saving: boolean,
}

local DataService = {}
DataService.Loaded = Signal.new() -- (player, data)
DataService.Changed = Signal.new() -- (player, data)

local profiles: { [Player]: Profile } = {}
local store: DataStore? = nil
local storeUnavailable = false

local LOAD_ATTEMPTS = 6
local LOCK_RETRY_SECONDS = 5

local function template(): Data
	return {
		Version = GameConfig.DataVersion,
		Cash = GameConfig.StartingCash,
		PickaxeTier = 1,
		BackpackTier = 1,
		LampTier = 1,
		SuitTier = 0,
		DrillTier = 0,
		Backpack = {},
		Gates = {},
		Mines = {},
		Artifacts = {},
		Stats = { TotalMined = 0, TotalEarned = 0, Mined = {}, CreaturesDefeated = 0, RichVeins = 0, BiggestSale = 0, Hatched = 0 },
		Achievements = {},
		Settings = { Sfx = 1, Ambience = 1, Shake = true, Objectives = true, Hints = true },
		Prestige = 0,
		Boosts = {}, -- boost id -> Unix time it ends
		Skins = {}, -- bought skin ids (earned ones are derived, see Config/Skins)
		EquippedSkin = "Classic",
		Purchases = {}, -- processed Developer Product receipt ids (idempotency)
		RunMined = {},
		Abyss = { Best = 0 },
		Daily = { Streak = 0, LastDay = -1, Best = 0 },
		Badges = {},
		GroupRewardClaimed = false,
		Pets = {},
		EquippedPets = {},
	}
end

-- Fill in fields added since the data was first saved.
local function reconcile(target: { [any]: any }, defaults: { [any]: any })
	for key, value in defaults do
		if target[key] == nil then
			target[key] = if type(value) == "table" then table.clone(value) else value
		elseif type(value) == "table" and type(target[key]) == "table" then
			reconcile(target[key], value)
		end
	end
end

local function keyFor(player: Player): string
	return "Player_" .. player.UserId
end

local function isAccessError(err: any): boolean
	local msg = tostring(err)
	return msg:find("StudioAccessToApisNotAllowed") ~= nil
		or msg:find("403") ~= nil
		or msg:find("not allowed") ~= nil
end

local function getStore(): DataStore?
	if store or storeUnavailable then
		return store
	end
	local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, GameConfig.DataStoreName)
	if ok then
		store = result
	else
		storeUnavailable = true
		warn("[DataService] DataStore unavailable:", result)
	end
	return store
end

-- Returns (status, data) where status is "ok" | "locked" | "error" | "noaccess".
local function attemptLoad(key: string, force: boolean): (string, any)
	local ds = getStore()
	if not ds then
		return "noaccess", nil
	end
	local status, data = "ok", nil
	local ok, err = pcall(function()
		ds:UpdateAsync(key, function(record)
			record = record or {}
			local lock = record.Lock
			if not force and lock and lock.JobId ~= game.JobId
				and os.time() - (lock.Time or 0) < GameConfig.SessionLockStaleSeconds then
				status = "locked"
				return nil -- cancel the write
			end
			status = "ok"
			data = record.Data
			record.Lock = { JobId = game.JobId, Time = os.time() }
			return record
		end)
	end)
	if not ok then
		return if isAccessError(err) then "noaccess" else "error", err
	end
	return status, data
end

local function loadProfile(player: Player): Profile?
	local key = keyFor(player)
	for attempt = 1, LOAD_ATTEMPTS do
		if not player.Parent then
			return nil
		end
		local force = attempt == LOAD_ATTEMPTS -- last resort: take over a stuck lock
		local status, result = attemptLoad(key, force)
		if status == "ok" then
			local data = if type(result) == "table" then result else template()
			reconcile(data, template() :: any)
			return { Data = data, CanSave = true, Saving = false }
		elseif status == "noaccess" then
			warn("[DataService] No DataStore access (enable Studio API access). Progress will NOT be saved.", result)
			return { Data = template(), CanSave = false, Saving = false }
		elseif status == "locked" then
			warn(`[DataService] {player.Name}'s data is locked by another server, retrying ({attempt}/{LOAD_ATTEMPTS})`)
			task.wait(LOCK_RETRY_SECONDS)
		else
			warn(`[DataService] Load failed for {player.Name} ({attempt}/{LOAD_ATTEMPTS}):`, result)
			task.wait(math.min(2 ^ attempt, 10))
		end
	end
	return nil
end

local function saveProfile(player: Player, profile: Profile, release: boolean): boolean
	if not profile.CanSave then
		return true
	end
	local ds = getStore()
	if not ds then
		return false
	end
	while profile.Saving do
		task.wait()
	end
	profile.Saving = true
	local key = keyFor(player)
	local saved = false
	for attempt = 1, 3 do
		local lostLock = false
		local ok, err = pcall(function()
			ds:UpdateAsync(key, function(record)
				record = record or {}
				if record.Lock and record.Lock.JobId ~= game.JobId then
					lostLock = true
					return nil
				end
				record.Data = profile.Data
				record.Lock = if release then nil else { JobId = game.JobId, Time = os.time() }
				return record
			end)
		end)
		if ok then
			if lostLock then
				-- Another server took the session over (e.g. this one stalled past the
				-- stale-lock timeout). Anything played here can't be saved any more,
				-- so stop the player rather than let them lose progress silently.
				warn(`[DataService] Not saving {player.Name}: another server owns the session`)
				profile.CanSave = false
				if player.Parent then
					player:Kick("Your save was opened on another server. Please rejoin.")
				end
			end
			saved = not lostLock
			break
		end
		warn(`[DataService] Save failed for {player.Name} ({attempt}/3):`, err)
		task.wait(attempt * 2)
	end
	profile.Saving = false
	return saved
end

function DataService:Get(player: Player): Data?
	local profile = profiles[player]
	return profile and profile.Data
end

-- Mutate a player's data and broadcast the change. Returns false if not loaded.
function DataService:Update(player: Player, mutate: (Data) -> ()): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	mutate(profile.Data)
	DataService.Changed:Fire(player, profile.Data)
	return true
end

-- Saves right away (used after Robux purchases). Returns true on success,
-- or when saving is unavailable (Studio without API access) so purchases
-- aren't stuck retrying forever there.
function DataService:SaveNow(player: Player): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	return saveProfile(player, profile, false)
end

function DataService:CanSave(player: Player): boolean
	local profile = profiles[player]
	return profile ~= nil and profile.CanSave
end

-- Calls fn(player, data) for every loaded player now and in the future.
function DataService:OnLoaded(fn: (Player, Data) -> ())
	for player, profile in profiles do
		task.spawn(fn, player, profile.Data)
	end
	DataService.Loaded:Connect(fn)
end

local function onPlayerAdded(player: Player)
	local profile = loadProfile(player)
	if not player.Parent then
		if profile then
			saveProfile(player, profile, true)
		end
		return
	end
	if not profile then
		player:Kick("Deep Mine couldn't load your save right now. Please rejoin in a minute.")
		return
	end
	profiles[player] = profile
	DataService.Loaded:Fire(player, profile.Data)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	saveProfile(player, profile, true)
	profiles[player] = nil
end

function DataService:Init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	task.spawn(function()
		while true do
			task.wait(GameConfig.AutosaveSeconds)
			for player, profile in profiles do
				task.spawn(saveProfile, player, profile, false)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player, profile in profiles do
			pending += 1
			task.spawn(function()
				saveProfile(player, profile, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + (if RunService:IsStudio() then 5 else 25)
		while pending > 0 and os.clock() < deadline do
			task.wait()
		end
	end)
end

return DataService
