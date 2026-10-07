--!strict
-- Environmental hazards. Map builders place parts tagged "Hazard" with
-- attributes Type (see Config/Hazards), Level and DamagePerSecond. Players
-- inside one take damage unless their suit's protection for that Type is at
-- least Level. The client is told so it can show heat haze / warnings.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Equipment = require(Shared.Config.Equipment)
local Hazards = require(Shared.Config.Hazards)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)

local HazardService = {}

local TICK = 0.5

local function inside(part: BasePart, point: Vector3): boolean
	local p = part.CFrame:PointToObjectSpace(point)
	local h = part.Size / 2
	return math.abs(p.X) <= h.X and math.abs(p.Y) <= h.Y and math.abs(p.Z) <= h.Z
end

function HazardService:Protection(player: Player, hazardType: string): number
	local data = DataService:Get(player)
	local suit = data and data.SuitTier > 0 and Equipment.Suits[data.SuitTier]
	return if suit then suit.Protection[hazardType] or 0 else 0
end

local function check(player: Player, event: RemoteEvent)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	-- Overlapping volumes (lava inside a heat zone): the worst hazard you
	-- aren't protected from wins; otherwise report the one you are shielded from.
	local worst: { type: string, dps: number }? = nil
	local shielded: string? = nil
	for _, volume in CollectionService:GetTagged("Hazard") do
		if not volume:IsA("BasePart") or not inside(volume, root.Position) then
			continue
		end
		local hazardType = volume:GetAttribute("Type")
		if type(hazardType) ~= "string" or not Hazards[hazardType] then
			continue
		end
		local level = (volume:GetAttribute("Level") :: number?) or 1
		if HazardService:Protection(player, hazardType) >= level then
			shielded = hazardType
		else
			local dps = (volume:GetAttribute("DamagePerSecond") :: number?) or 10
			if not worst or dps > worst.dps then
				worst = { type = hazardType, dps = dps }
			end
		end
	end
	if worst then
		humanoid:TakeDamage(worst.dps * TICK)
		event:FireClient(player, { type = worst.type, protected = false })
	elseif shielded then
		event:FireClient(player, { type = shielded, protected = true })
	end
end

function HazardService:Init()
	local event = Remotes.Event("Hazard")
	task.spawn(function()
		while true do
			task.wait(TICK)
			for _, player in Players:GetPlayers() do
				task.spawn(check, player, event)
			end
		end
	end)
end

return HazardService
