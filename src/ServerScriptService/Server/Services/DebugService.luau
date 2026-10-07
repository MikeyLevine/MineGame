--!strict
-- Studio-only test hook. Creates ServerStorage.DeepMineDebug (BindableFunction)
-- so data can be inspected/modified from the command bar or test tooling.
-- Never created in live servers.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local DataService = require(script.Parent.DataService)

local DebugService = {}

local snapshot: { [string]: any }? = nil

local COMMANDS: { [string]: (Player, ...any) -> any } = {
	Get = function(player)
		return HttpService:JSONEncode({ data = DataService:Get(player), canSave = DataService:CanSave(player) })
	end,
	SetCash = function(player, amount)
		DataService:Update(player, function(d)
			d.Cash = tonumber(amount) or d.Cash
		end)
		return "ok"
	end,
	Reset = function(player)
		DataService:Update(player, function(d)
			d.Cash = 0
			d.PickaxeTier = 1
			d.BackpackTier = 1
			table.clear(d.Backpack)
			table.clear(d.Gates)
			table.clear(d.Mines)
			table.clear(d.Artifacts)
			table.clear(d.Achievements)
		end)
		return "ok"
	end,
	-- SetMined("Iron", 25): set a lifetime mined count (for testing objectives)
	SetMined = function(player, resourceId, amount)
		DataService:Update(player, function(d)
			d.Stats.Mined[resourceId] = tonumber(amount) or 0
		end)
		return "ok"
	end,
	SetTier = function(player, pickaxeTier, backpackTier)
		DataService:Update(player, function(d)
			d.PickaxeTier = tonumber(pickaxeTier) or d.PickaxeTier
			d.BackpackTier = tonumber(backpackTier) or d.BackpackTier
		end)
		return "ok"
	end,
	-- Snapshot()/Restore(): save and put back a player's whole data in memory,
	-- so destructive tests don't eat real progress.
	Snapshot = function(player)
		local data = DataService:Get(player)
		snapshot = data and HttpService:JSONDecode(HttpService:JSONEncode(data))
		return if snapshot then "snapshot taken" else "no data"
	end,
	Restore = function(player)
		if not snapshot then
			return "no snapshot"
		end
		DataService:Update(player, function(d)
			for k in d do
				(d :: any)[k] = nil
			end
			for k, v in snapshot do
				(d :: any)[k] = v
			end
		end)
		return "restored"
	end,
	-- SetEquip("LampTier", 3) etc.
	SetEquip = function(player, field, tier)
		DataService:Update(player, function(d)
			if type((d :: any)[field]) == "number" then
				(d :: any)[field] = tonumber(tier) or 0
			end
		end)
		return "ok"
	end,
	-- Event("Meteorite" | "RichSeam" | "OreFrenzy" | "LuckyHour")
	Event = function(_, id)
		return tostring(require(script.Parent.EventService):Trigger(id))
	end,
	SetStat = function(player, field, amount)
		DataService:Update(player, function(d)
			(d.Stats :: any)[field] = tonumber(amount) or 0
		end)
		return "ok"
	end,
	SetGate = function(player, gateId, open)
		DataService:Update(player, function(d)
			d.Gates[gateId] = if open == false then nil else true
		end)
		return "ok"
	end,
	-- Monetization test paths (no real purchase): GrantPass sets the owned
	-- attribute like PromptGamePassPurchaseFinished does; GrantProduct runs
	-- the same grant code as ProcessReceipt with a fake receipt id.
	GrantPass = function(player, passId, owned)
		player:SetAttribute("Pass_" .. tostring(passId), owned ~= false)
		DataService:Update(player, function() end) -- re-push state
		return "ok"
	end,
	GrantProduct = function(player, itemId, receiptId)
		return tostring(require(script.Parent.StoreService):GrantProduct(player, itemId, receiptId or HttpService:GenerateGUID(false)))
	end,
	-- SetMineDone("Mine5", true): mark a mine completed (or not) for prestige tests.
	SetMineDone = function(player, mineId, done)
		DataService:Update(player, function(d)
			local state = d.Mines[mineId] or {}
			state.Visited = true
			state.Completed = if done == false then nil else true
			d.Mines[mineId] = state
		end)
		return "ok"
	end,
	SetPrestige = function(player, level)
		DataService:Update(player, function(d)
			d.Prestige = tonumber(level) or 0
		end)
		return "ok"
	end,
	OpenGates = function(player)
		DataService:Update(player, function(d)
			d.Gates.CopperGate = true
			d.Gates.IronGate = true
		end)
		return "ok"
	end,
}

function DebugService:Init()
	if not RunService:IsStudio() then
		return
	end
	local fn = Instance.new("BindableFunction")
	fn.Name = "DeepMineDebug"
	fn.OnInvoke = function(command: string, ...)
		local player = Players:GetPlayers()[1]
		local handler = COMMANDS[command]
		if not player or not handler then
			return "no player or unknown command"
		end
		return handler(player, ...)
	end
	fn.Parent = ServerStorage
end

return DebugService
