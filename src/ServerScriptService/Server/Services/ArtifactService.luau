--!strict
-- Artifacts: unique pedestals (tagged "Artifact", attribute ArtifactId) that
-- each player can take once. Taking one is saved, pays its reward and shows
-- the discovery card on the client.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Artifacts = require(Shared.Config.Artifacts)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local GateService = require(script.Parent.GateService)

local ArtifactService = {}

local RANGE = 14

local function take(player: Player, model: Instance, promptPart: BasePart)
	local id = model:GetAttribute("ArtifactId")
	local artifact = type(id) == "string" and Artifacts.Get(id)
	local data = DataService:Get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not artifact or not data or not root then
		return
	end
	if (root.Position - promptPart.Position).Magnitude > RANGE or not GateService:CanAccess(player, promptPart.Position) then
		return
	end
	if data.Artifacts[artifact.Id] then
		return
	end
	local needed = artifact.RequiresCompleted
	if needed and not (data.Mines[needed] and data.Mines[needed].Completed) then
		return
	end
	DataService:Update(player, function(d)
		d.Artifacts[artifact.Id] = true
		d.Cash += artifact.Reward
		d.Stats.TotalEarned += artifact.Reward
	end)
	Remotes.Event("ArtifactFound"):FireClient(player, artifact.Id)
end

local function bind(model: Instance)
	local prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true)
	local promptPart = prompt and prompt.Parent
	if not prompt or not promptPart or not promptPart:IsA("BasePart") then
		warn("[ArtifactService] Artifact without a prompt:", model:GetFullName())
		return
	end
	prompt.Triggered:Connect(function(player)
		take(player, model, promptPart)
	end)
end

function ArtifactService:Init()
	for _, model in CollectionService:GetTagged("Artifact") do
		bind(model)
	end
	CollectionService:GetInstanceAddedSignal("Artifact"):Connect(bind)
end

return ArtifactService
