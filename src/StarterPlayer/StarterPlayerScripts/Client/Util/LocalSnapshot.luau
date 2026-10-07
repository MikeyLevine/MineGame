--!strict
-- Remembers the original look of a model's parts before the client changes
-- them locally (hiding broken gates, opening seal walls), so they can be put
-- back exactly when progress resets (prestige).

local LocalSnapshot = {}

type Saved = { [Instance]: { [string]: any } }
local saved: { [Instance]: Saved } = {}

local PROPS = {
	BasePart = { "CFrame", "Transparency", "CanCollide", "CanQuery", "LocalTransparencyModifier", "Color" },
	Decal = { "Transparency" },
	Texture = { "Transparency" },
	ProximityPrompt = { "Enabled" },
	LayerCollector = { "Enabled" },
	Light = { "Enabled", "Brightness", "Range" },
}

function LocalSnapshot.Save(model: Instance)
	if saved[model] then
		return
	end
	local record: Saved = {}
	for _, d in model:GetDescendants() do
		for class, props in PROPS do
			if d:IsA(class) then
				local values = {}
				for _, prop in props do
					values[prop] = (d :: any)[prop]
				end
				record[d] = values
				break
			end
		end
	end
	saved[model] = record
end

function LocalSnapshot.Restore(model: Instance)
	local record = saved[model]
	if not record then
		return
	end
	for inst, values in record do
		if inst.Parent then
			for prop, value in values do
				(inst :: any)[prop] = value
			end
		end
	end
	saved[model] = nil
end

return LocalSnapshot
