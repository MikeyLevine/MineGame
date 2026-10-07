--!strict
-- Resolves any part of a mineable thing to its root model and kind.
-- Ore nodes are tagged "Ore", rubble gates "Gate", hostile creatures "Creature".

local CollectionService = game:GetService("CollectionService")

local Targets = {}

function Targets.Resolve(inst: Instance?): (Instance?, string?)
	local node = inst
	while node and node ~= workspace do
		if CollectionService:HasTag(node, "Ore") then
			return node, "Ore"
		elseif CollectionService:HasTag(node, "Gate") then
			return node, "Gate"
		elseif CollectionService:HasTag(node, "Creature") then
			return node, "Creature"
		end
		node = node.Parent
	end
	return nil, nil
end

-- Distance from a point to the surface of a model's bounding box (0 if inside).
function Targets.DistanceTo(target: Instance, point: Vector3): number
	local cf: CFrame, size: Vector3
	if target:IsA("Model") then
		cf, size = target:GetBoundingBox()
	elseif target:IsA("BasePart") then
		cf, size = target.CFrame, target.Size
	else
		return math.huge
	end
	local localPoint = cf:PointToObjectSpace(point)
	local half = size / 2
	local clamped = Vector3.new(
		math.clamp(localPoint.X, -half.X, half.X),
		math.clamp(localPoint.Y, -half.Y, half.Y),
		math.clamp(localPoint.Z, -half.Z, half.Z)
	)
	return (localPoint - clamped).Magnitude
end

return Targets
