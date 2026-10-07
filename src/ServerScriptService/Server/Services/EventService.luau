--!strict
-- Random world events, one at a time, every few minutes:
--  * Meteorite Strike: meteorite ore crashes down near camp (anyone can mine it)
--  * Rich Seam: ores in a zone the players have reached turn into rich veins
--  * Ore Frenzy: the Ore Buyer pays more for a while
--  * Lucky Hour: rich veins are far more common for a while
-- Timed effects are published as ReplicatedStorage attributes (SellMultiplier,
-- RichMultiplier) plus EventName/EventEnds for the HUD timer.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Mines = require(Shared.Config.Mines)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local OreService = require(script.Parent.OreService)

local EventService = {}

local MIN_GAP, MAX_GAP = 300, 540
local TIMED_DURATION = 180
local CRATER = Vector3.new(50, 0, 26) -- open ground beside camp
local rng = Random.new()
local running = false

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { workspace.Terrain }

local function announce(payload: { [string]: any })
	Remotes.Event("GameEvent"):FireAllClients(payload)
end

local function setTimed(name: string, attribute: string, value: number)
	ReplicatedStorage:SetAttribute(attribute, value)
	ReplicatedStorage:SetAttribute("EventName", name)
	ReplicatedStorage:SetAttribute("EventEnds", workspace:GetServerTimeNow() + TIMED_DURATION)
	task.delay(TIMED_DURATION, function()
		ReplicatedStorage:SetAttribute(attribute, nil)
		ReplicatedStorage:SetAttribute("EventName", nil)
		ReplicatedStorage:SetAttribute("EventEnds", nil)
		running = false
	end)
end

-- Zones that any current player has reached (non-secret, with ore).
local function reachedZones(): { { mine: Mines.Mine, zone: Mines.Zone } }
	local list = {}
	local seen = {}
	for _, player in Players:GetPlayers() do
		local data = DataService:Get(player)
		if data then
			for mineId, state in data.Mines do
				local mine = Mines.ById[mineId]
				for zoneId in (state.Reached or {}) do
					local zone = mine and Mines.GetZone(mineId, zoneId)
					local key = mineId .. "/" .. zoneId
					if zone and zone.MaxOres > 0 and not seen[key] then
						seen[key] = true
						table.insert(list, { mine = mine, zone = zone })
					end
				end
			end
		end
	end
	if #list == 0 then
		local mine = Mines.ById.Mine1
		table.insert(list, { mine = mine, zone = mine.Zones[1] })
	end
	return list
end

local function meteorite()
	local camp = workspace:FindFirstChild("Camp")
	local container = camp and (camp:FindFirstChild("EventOres") or Instance.new("Folder"))
	if not camp or not container then
		running = false
		return
	end
	container.Name = "EventOres"
	container.Parent = camp
	container:ClearAllChildren()
	announce({ id = "Meteorite", name = "Meteorite Strike", description = "Something just fell from the sky near camp!" })

	-- Fireball streaks down, then the impact.
	local fireball = Instance.new("Part")
	fireball.Shape = Enum.PartType.Ball
	fireball.Size = Vector3.new(6, 6, 6)
	fireball.Material = Enum.Material.Neon
	fireball.Color = Color3.fromRGB(255, 140, 60)
	fireball.Anchored = true
	fireball.CanCollide = false
	fireball.CFrame = CFrame.new(CRATER + Vector3.new(-260, 420, 160))
	local fire = Instance.new("Fire")
	fire.Size = 20
	fire.Heat = 0
	fire.Parent = fireball
	local light = Instance.new("PointLight")
	light.Range = 60
	light.Brightness = 4
	light.Color = Color3.fromRGB(255, 160, 80)
	light.Parent = fireball
	fireball.Parent = workspace
	local tween = TweenService:Create(fireball, TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ CFrame = CFrame.new(CRATER + Vector3.new(0, 2, 0)) })
	tween:Play()
	tween.Completed:Wait()
	fireball:Destroy()
	local explosion = Instance.new("Explosion")
	explosion.Position = CRATER + Vector3.new(0, 1, 0)
	explosion.BlastRadius = 0 -- purely visual
	explosion.BlastPressure = 0
	explosion.DestroyJointRadiusPercent = 0
	explosion.Parent = workspace

	-- Scorched crater and meteorite chunks.
	workspace.Terrain:FillBall(CRATER + Vector3.new(0, -3, 0), 9, Enum.Material.Air)
	workspace.Terrain:FillBall(CRATER + Vector3.new(0, -9, 0), 9, Enum.Material.CrackedLava)
	task.wait(0.3)
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2
		local origin = CRATER + Vector3.new(math.cos(a) * 4.5, 20, math.sin(a) * 4.5)
		local hit = workspace:Raycast(origin, Vector3.new(0, -40, 0), terrainOnly)
		local point = Instance.new("Part")
		point.Anchored = true
		point.Transparency = 1
		point.CanCollide = false
		point.CanQuery = false
		point.CFrame = CFrame.new((if hit then hit.Position else CRATER) - Vector3.new(0, 0.6, 0))
		point.Parent = container
		OreService:SpawnSpecial("Meteorite", point, container, i == 1)
	end
	-- Unmined chunks crumble away eventually; the crater gets refilled.
	task.delay(600, function()
		container:ClearAllChildren()
		workspace.Terrain:FillBall(CRATER + Vector3.new(0, -9, 0), 10, Enum.Material.Ground)
		workspace.Terrain:FillBlock(CFrame.new(CRATER + Vector3.new(0, -2, 0)), Vector3.new(20, 4, 20), Enum.Material.Grass)
	end)
	running = false
end

local function richSeam()
	local zones = reachedZones()
	local pick = zones[rng:NextInteger(1, #zones)]
	local converted = OreService:MakeRich(pick.mine.Id, pick.zone.Id, 6)
	announce({ id = "RichSeam", name = "Rich Seam", mine = pick.mine.DisplayName, zone = pick.zone.DisplayName,
		description = `A tremor exposed rich veins in the {pick.zone.DisplayName} ({pick.mine.DisplayName})!` })
	running = false
	return converted
end

local function oreFrenzy()
	setTimed("Ore Frenzy", "SellMultiplier", 1.5)
	announce({ id = "OreFrenzy", name = "Ore Frenzy", description = "The Ore Buyer is paying 1.5x for the next 3 minutes!" })
end

local function luckyHour()
	setTimed("Lucky Hour", "RichMultiplier", 4)
	announce({ id = "LuckyHour", name = "Lucky Hour", description = "Rich veins are 4x as common for the next 3 minutes!" })
end

local EVENTS = {
	Meteorite = meteorite,
	RichSeam = richSeam,
	OreFrenzy = oreFrenzy,
	LuckyHour = luckyHour,
}
local ORDER = { "Meteorite", "RichSeam", "OreFrenzy", "LuckyHour" }

function EventService:Trigger(id: string): boolean
	local fn = EVENTS[id]
	if not fn or running then
		return false
	end
	running = true
	task.spawn(fn)
	return true
end

function EventService:Init()
	task.spawn(function()
		while true do
			task.wait(rng:NextInteger(MIN_GAP, MAX_GAP))
			if #Players:GetPlayers() > 0 then
				self:Trigger(ORDER[rng:NextInteger(1, #ORDER)])
			end
		end
	end)
end

return EventService
