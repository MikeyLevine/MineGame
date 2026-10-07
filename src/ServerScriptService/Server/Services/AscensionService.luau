--!strict
-- Mine completion. The Sealed Wall at the end of a mine checks the mine's
-- requirements; when met, the mine is marked completed (saved) and the
-- client plays the wall-breaking sequence. Walking into the portal behind the
-- wall then takes the player to the next mine.
--
-- Like rubble gates, walls are per-player: other players still see it sealed.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Mines = require(Shared.Config.Mines)
local Progress = require(Shared.Progress)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local ProgressService = require(script.Parent.ProgressService)
local TravelService = require(script.Parent.TravelService)

local AscensionService = {}

local WALL_RANGE = 20
local portalDebounce: { [Player]: boolean } = {}

local function near(player: Player, part: BasePart, range: number): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and (root.Position - part.Position).Magnitude <= range
end

local function tryAscend(player: Player, mineId: string, promptPart: BasePart)
	local data = DataService:Get(player)
	local mine = Mines.ById[mineId]
	if not data or not mine or not near(player, promptPart, WALL_RANGE) then
		return
	end
	if Progress.IsCompleted(data :: any, mineId) then
		Remotes.Event("Notify"):FireClient(player, "The way is already open.", "Info")
		return
	end
	local items, ready = Progress.Evaluate(data :: any, mineId)
	if not ready then
		local missing = 0
		for _, item in items do
			if not item.Done then
				missing += 1
			end
		end
		Remotes.Event("Notify"):FireClient(player,
			`The wall won't budge. {missing} objective{if missing == 1 then "" else "s"} left in this mine.`, "Warn")
		Remotes.Event("ObjectivesPulse"):FireClient(player)
		return
	end
	if mine.Ending then
		-- The final mine: break the seal, then the ending plays on the client.
		DataService:Update(player, function(d)
			local st = d.Mines[mineId] or {}
			d.Mines[mineId] = st
			st.Completed = true
		end)
		Remotes.Event("Ascended"):FireClient(player, mineId)
		task.delay(9, function()
			if player.Parent then
				Remotes.Event("Ending"):FireClient(player)
			end
		end)
		return
	end
	if not mine.NextMine or not Mines.ById[mine.NextMine] then
		-- Everything done, but the next mine isn't built yet. Don't mark it
		-- completed so the ascension still plays once the next mine exists.
		Remotes.Event("Notify"):FireClient(player,
			`You've mastered the {mine.DisplayName}! The way deeper opens in a future update.`, "Good")
		return
	end
	DataService:Update(player, function(d)
		local s = d.Mines[mineId] or {}
		d.Mines[mineId] = s
		s.Completed = true
	end)
	Remotes.Event("Ascended"):FireClient(player, mineId)
end

local function onPortalTouched(trigger: BasePart, hit: BasePart)
	local character = hit:FindFirstAncestorOfClass("Model")
	local player = character and Players:GetPlayerFromCharacter(character)
	if not player or portalDebounce[player] then
		return
	end
	local fromMine = trigger:GetAttribute("FromMine")
	local toMine = trigger:GetAttribute("ToMine")
	local data = DataService:Get(player)
	if type(fromMine) ~= "string" or type(toMine) ~= "string" or not data then
		return
	end
	if not Progress.IsCompleted(data :: any, fromMine) then
		return -- wall is still sealed for this player
	end
	local destination = workspace.Mines:FindFirstChild(toMine)
	local arrival = destination and destination:FindFirstChild("Arrival")
	local mine = Mines.ById[toMine]
	if not arrival or not arrival:IsA("BasePart") or not mine then
		warn(`[AscensionService] {toMine} has no Arrival point`)
		return
	end
	portalDebounce[player] = true
	local firstVisit = not Progress.MineState(data :: any, toMine).Visited
	ProgressService:MarkVisited(player, toMine)
	TravelService:Teleport(player, arrival.CFrame, {
		title = mine.DisplayName,
		subtitle = `MINE {mine.Order}`,
		tagline = if firstVisit then mine.Tagline else nil,
	})
	task.delay(2, function()
		portalDebounce[player] = nil
	end)
end

local function bindWall(wall: Instance)
	local mineId = wall:GetAttribute("MineId")
	local prompt = wall:FindFirstChildWhichIsA("ProximityPrompt", true)
	local promptPart = prompt and prompt.Parent
	if type(mineId) ~= "string" or not prompt or not promptPart or not promptPart:IsA("BasePart") then
		warn("[AscensionService] Malformed AscensionWall", wall:GetFullName())
		return
	end
	prompt.Triggered:Connect(function(player)
		tryAscend(player, mineId, promptPart)
	end)
end

function AscensionService:Init()
	for _, wall in CollectionService:GetTagged("AscensionWall") do
		bindWall(wall)
	end
	for _, mine in workspace:WaitForChild("Mines"):GetChildren() do
		local portal = mine:FindFirstChild("Portal")
		local trigger = portal and portal:FindFirstChild("PortalTrigger")
		if trigger and trigger:IsA("BasePart") then
			trigger.Touched:Connect(function(hit)
				onPortalTouched(trigger, hit)
			end)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		portalDebounce[player] = nil
	end)
end

return AscensionService
