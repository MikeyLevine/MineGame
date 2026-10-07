--!strict
-- Client entry point.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)
local Resources = require(Shared.Config.Resources)

local Controllers = script.Parent:WaitForChild("Controllers")
local UI = script.Parent:WaitForChild("UI")

local ORDER: { ModuleScript } = {
	Controllers.StateController,
	Controllers.SoundController,
	Controllers.CameraShake,
	UI.Toasts,
	UI.Hud,
	UI.Shop,
	UI.Objectives,
	UI.AbyssHud,
	UI.LiftMenu,
	Controllers.TravelController,
	Controllers.GateController,
	Controllers.AscensionController,
	Controllers.ZoneController,
	Controllers.DarkController,
	Controllers.HazardController,
	Controllers.MiningController,
	Controllers.DrillController,
	Controllers.RelicController,
	Controllers.CreatureController,
	UI.PrestigeDialog,
	UI.Ending,
	UI.Journal,
	Controllers.EventController,
	UI.Settings,
	UI.Store,
	UI.Daily,
	UI.Hints,
}

for _, module in ORDER do
	local ok, err = pcall(function()
		(require(module) :: any):Init()
	end)
	if not ok then
		warn(`[Client] {module.Name} failed to start:`, err)
	end
end

local Toasts = require(UI.Toasts) :: any
local SoundController = require(Controllers.SoundController) :: any

Remotes.Event("Notify").OnClientEvent:Connect(function(text: string, kind: string?)
	Toasts:Notify(text, kind)
end)

Remotes.Event("Sold").OnClientEvent:Connect(function(summary)
	local parts = {}
	for _, id in Resources.Order do
		local n = summary.items[id]
		if n then
			table.insert(parts, `{n} {id}`)
		end
	end
	SoundController:Play("Sell")
	Toasts:Notify(`Sold {table.concat(parts, ", ")} for {Format.Cash(summary.total)}`, "Good")
end)

print("[Deep Mine] Client ready for", Players.LocalPlayer.Name)
