--!strict
-- Saves the player's client settings (volumes, camera shake, UI toggles).
-- Only known keys with the right types are accepted; numbers are clamped.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)

local SettingsService = {}

local SCHEMA: { [string]: string } = {
	Sfx = "number",
	Ambience = "number",
	Shake = "boolean",
	Objectives = "boolean",
	Hints = "boolean",
}

local lastSave: { [Player]: number } = {}

local function save(player: Player, incoming: any): boolean
	if type(incoming) ~= "table" then
		return false
	end
	local now = os.clock()
	if now - (lastSave[player] or 0) < 0.3 then
		return false
	end
	lastSave[player] = now
	return DataService:Update(player, function(d)
		for key, kind in SCHEMA do
			local value = incoming[key]
			if type(value) == kind and value == value then -- value == value rejects NaN
				(d.Settings :: any)[key] = if kind == "number" then math.clamp(value, 0, 1) else value
			end
		end
	end)
end

function SettingsService:Init()
	Remotes.Function("SaveSettings").OnServerInvoke = save
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastSave[player] = nil
	end)
end

return SettingsService
