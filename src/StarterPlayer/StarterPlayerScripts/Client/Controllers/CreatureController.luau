--!strict
-- Creature feedback: a screech and warning when something starts hunting
-- you, a red flash and growl on each bite, a death sound. Also scuttles
-- creature legs while they move (visual only; the server owns positions).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local SoundController = require(script.Parent.SoundController)
local TravelController = require(script.Parent.TravelController)
local CameraShake = require(script.Parent.CameraShake)
local Toasts = require(script.Parent.Parent.UI.Toasts)

local CreatureController = {}

type Rig = { Body: BasePart, Legs: { { Part: BasePart, Offset: CFrame, Phase: number } }, LastPos: Vector3, Speed: number }
local rigs: { [Instance]: Rig } = {}

local function rig(creature: Instance)
	local body = creature:FindFirstChild("Body")
	if not body or not body:IsA("BasePart") then
		return
	end
	local legs = {}
	for i, part in creature:GetChildren() do
		if part.Name == "Leg" and part:IsA("BasePart") then
			-- Alternate phases so legs move in a tripod gait.
			table.insert(legs, { Part = part, Offset = body.CFrame:ToObjectSpace(part.CFrame), Phase = (#legs % 2) * math.pi })
		end
	end
	rigs[creature] = { Body = body, Legs = legs, LastPos = body.Position, Speed = 0 }
	-- A faint glowing outline keeps dark creatures readable in dark caves.
	local eye = creature:FindFirstChild("Eye")
	if not creature:FindFirstChildOfClass("Highlight") then
		local h = Instance.new("Highlight")
		h.FillTransparency = 1
		h.OutlineTransparency = 0.35
		h.OutlineColor = if eye and eye:IsA("BasePart") then eye.Color else Color3.fromRGB(150, 80, 255)
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Parent = creature
	end
end

function CreatureController:Init()
	Remotes.Event("Creature").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		if payload.event == "alert" then
			SoundController:Play("CreatureAlert", payload.position)
			Toasts:Notify(`A {payload.name or "creature"} is hunting you!`, "Warn")
		elseif payload.event == "bite" then
			SoundController:Play("CreatureAttack", payload.position, 0.1)
			TravelController:Flash(Color3.fromRGB(200, 30, 40), 0.35)
			CameraShake:Shake(0.6, 0.25)
		elseif payload.event == "death" then
			SoundController:Play("CreatureDeath", payload.position)
		end
	end)

	for _, c in CollectionService:GetTagged("Creature") do
		task.defer(rig, c)
	end
	CollectionService:GetInstanceAddedSignal("Creature"):Connect(function(c)
		task.defer(rig, c)
	end)
	CollectionService:GetInstanceRemovedSignal("Creature"):Connect(function(c)
		rigs[c] = nil
	end)

	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		for creature, r in rigs do
			if not r.Body.Parent then
				rigs[creature] = nil
				continue
			end
			local pos = r.Body.Position
			local moved = (pos - r.LastPos).Magnitude / math.max(dt, 1 / 240)
			r.LastPos = pos
			-- Smooth the measured speed: server updates arrive in steps.
			r.Speed += (moved - r.Speed) * math.min(1, dt * 6)
			local amount = math.clamp(r.Speed / 12, 0, 1) * 0.5
			for _, leg in r.Legs do
				leg.Part.CFrame = r.Body.CFrame * leg.Offset * CFrame.Angles(math.sin(t * 16 + leg.Phase) * amount, 0, 0)
			end
		end
	end)

end

return CreatureController
