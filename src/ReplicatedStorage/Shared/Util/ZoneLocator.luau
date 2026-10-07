--!strict
-- Finds which mine/zone a world position is in, from the invisible boxes in
-- Workspace.Mines.<MineId>.ZoneVolumes. Where boxes overlap, the one with the
-- highest "Priority" attribute wins.

local ZoneLocator = {}

local function inside(part: BasePart, point: Vector3): boolean
	local p = part.CFrame:PointToObjectSpace(point)
	local h = part.Size / 2
	return math.abs(p.X) <= h.X and math.abs(p.Y) <= h.Y and math.abs(p.Z) <= h.Z
end

-- Abyss floors (Workspace.Abyss.<floor>.ZoneVolumes) report mine "Abyss"
-- and zone "F<floor number>".
function ZoneLocator.Locate(point: Vector3): (string?, string?)
	local bestMine, bestZone, bestPriority = nil, nil, -math.huge
	local function scan(parent: Instance?, mineIdOverride: string?)
		if not parent then
			return
		end
		for _, mine in parent:GetChildren() do
			local volumes = mine:FindFirstChild("ZoneVolumes")
			if not volumes then
				continue
			end
			for _, v in volumes:GetChildren() do
				if v:IsA("BasePart") and inside(v, point) then
					local priority = (v:GetAttribute("Priority") :: number?) or 0
					if priority > bestPriority then
						bestMine, bestZone, bestPriority = mineIdOverride or mine.Name, v:GetAttribute("ZoneId") :: string?, priority
					end
				end
			end
		end
	end
	scan(workspace:FindFirstChild("Mines"), nil)
	scan(workspace:FindFirstChild("Abyss"), "Abyss")
	return bestMine, bestZone
end

return ZoneLocator
