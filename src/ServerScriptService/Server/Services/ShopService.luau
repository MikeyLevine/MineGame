--!strict
-- Selling at the camp ore cart and buying equipment at the upgrade bench.
-- Both stations live in Workspace.Camp and carry their own ProximityPrompts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Equipment = require(Shared.Config.Equipment)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local Modifiers = require(Shared.Modifiers)
local InventoryService = require(script.Parent.InventoryService)

local RateLimit = require(script.Parent.Parent.Util.RateLimit)

local ShopService = {}
local purchaseLimit = RateLimit.new(0.2)

local STATION_RANGE = 24
local upgradeStation: BasePart?

local function nearStation(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or not upgradeStation then
		return false
	end
	return (root.Position - upgradeStation.Position).Magnitude <= STATION_RANGE
end

local function sell(player: Player)
	local data = DataService:Get(player)
	if not data then
		return
	end
	if InventoryService:Used(data) == 0 then
		Remotes.Event("Notify"):FireClient(player, "Your backpack is empty. Go mine something!", "Info")
		return
	end
	local total, items = InventoryService:SellAll(player)
	Remotes.Event("Sold"):FireClient(player, { total = total, items = items })
end

local function purchase(player: Player, kind: any): (boolean, string)
	if not purchaseLimit(player) then
		return false, "Slow down"
	end
	local category = type(kind) == "string" and Equipment.Category(kind)
	if not category then
		return false, "Unknown item"
	end
	local data = DataService:Get(player)
	if not data then
		return false, "Still loading"
	end
	if not nearStation(player) then
		return false, "Walk back to the upgrade bench"
	end

	local field = category.Field
	local currentTier = (data :: any)[field] or category.StartTier
	local nextItem = Equipment.List(category.Id)[currentTier + 1]
	if not nextItem then
		return false, "Already the best available"
	end
	local ok, hint = Equipment.MeetsRequirements(nextItem, data)
	if not ok then
		return false, hint or "Locked"
	end
	local price = Modifiers.Price(nextItem.Price, data)
	if data.Cash < price then
		return false, `Need {Format.Cash(price - data.Cash)} more`
	end

	DataService:Update(player, function(d)
		local record: any = d
		record.Cash -= price
		record[field] = currentTier + 1
	end)
	return true, `Bought {nextItem.Name}!`
end

-- Exposed for the Remote Seller game pass.
function ShopService:Sell(player: Player)
	sell(player)
end

function ShopService:Init()
	local camp = workspace:WaitForChild("Camp")
	local sellStation = camp:WaitForChild("SellStation")
	local upgradeBench = camp:WaitForChild("UpgradeStation")
	upgradeStation = upgradeBench:FindFirstChild("PromptPart") :: BasePart?

	local sellPrompt = sellStation:FindFirstChildWhichIsA("ProximityPrompt", true)
	local shopPrompt = upgradeBench:FindFirstChildWhichIsA("ProximityPrompt", true)
	assert(sellPrompt and shopPrompt, "[ShopService] Camp stations are missing their ProximityPrompts")

	sellPrompt.Triggered:Connect(sell)
	shopPrompt.Triggered:Connect(function(player)
		Remotes.Event("OpenShop"):FireClient(player)
	end)
	Remotes.Function("Purchase").OnServerInvoke = purchase
end

return ShopService
