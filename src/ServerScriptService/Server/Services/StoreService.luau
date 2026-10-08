--!strict
-- Robux store (MarketplaceService) and cosmetic skins.
--
-- Game passes: ownership is checked on join and after a purchase prompt
-- finishes, then mirrored as player attributes ("Pass_<Id>") so the server
-- and client read it the same way (see Shared/Modifiers.PlayerPasses).
--
-- Developer Products: ProcessReceipt is idempotent. Each receipt id is
-- recorded in data.Purchases in the same update that grants the item, and
-- PurchaseGranted is only returned after that update (and a save attempt).
-- If the player's data isn't loaded we return NotProcessedYet and Roblox
-- retries later.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Util.Format)
local Modifiers = require(Shared.Modifiers)
local Remotes = require(Shared.Remotes)
local Skins = require(Shared.Config.Skins)
local Store = require(Shared.Config.Store)
local Pets = require(Shared.Config.Pets)

local DataService = require(script.Parent.DataService)
local ShopService = require(script.Parent.ShopService)

local RateLimit = require(script.Parent.Parent.Util.RateLimit)

local StoreService = {}
local skinLimit = RateLimit.new(0.3)
local sellLimit = RateLimit.new(0.5)

local MAX_RECEIPTS = 300 -- keep the receipt log bounded

local function setPass(player: Player, passId: string, owned: boolean)
	player:SetAttribute("Pass_" .. passId, owned)
end

local function refreshPasses(player: Player)
	for _, pass in Store.Passes do
		if pass.GamePassId > 0 then
			local ok, owned = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.GamePassId)
			if ok and owned then
				setPass(player, pass.Id, true)
			end
		end
	end
end

function StoreService:HasPass(player: Player, passId: string): boolean
	return player:GetAttribute("Pass_" .. passId) == true
end

-- Which boost, Robux skin or Robux pet a Developer Product id (or item id)
-- refers to. Ids of 0 mean "not created yet" and never match a real receipt.
local function resolvePet(key: number | string): Pets.Pet?
	for _, p in Pets.List do
		if p.ProductId ~= nil and (p.Id == key or (p.ProductId > 0 and p.ProductId == key)) then
			return p
		end
	end
	return nil
end

local function resolve(key: number | string): (Store.Boost?, Skins.Skin?)
	for _, b in Store.Boosts do
		if b.Id == key or (b.ProductId > 0 and b.ProductId == key) then
			return b, nil
		end
	end
	for _, s in Skins.List do
		if s.Source == "Robux" and (s.Id == key or ((s.ProductId or 0) > 0 and s.ProductId == key)) then
			return nil, s
		end
	end
	return nil, nil
end

-- Grants a Developer Product's contents. `key` is the product id from a
-- receipt, or a boost/skin id (Studio debug command). Returns true if
-- granted (or already granted for this receipt id).
function StoreService:GrantProduct(player: Player, key: number | string, receiptId: string): boolean
	local data = DataService:Get(player)
	if not data then
		return false
	end
	if data.Purchases[receiptId] then
		return true -- already granted on an earlier attempt
	end
	local boost, skin = resolve(key)
	local pet = if boost or skin then nil else resolvePet(key)
	if not boost and not skin and not pet then
		warn("[StoreService] Unknown product", key)
		return false
	end
	local updated = DataService:Update(player, function(d)
		d.Purchases[receiptId] = true
		-- Trim the receipt log (oldest entries are not ordered; any are fine to drop).
		local count = 0
		for _ in d.Purchases do
			count += 1
		end
		if count > MAX_RECEIPTS then
			for id in d.Purchases do
				if id ~= receiptId then
					d.Purchases[id] = nil
					break
				end
			end
		end
		if boost then
			local now = os.time()
			d.Boosts[boost.Id] = math.max(d.Boosts[boost.Id] or 0, now) + boost.Duration
		elseif skin then
			d.Skins[skin.Id] = true
			d.EquippedSkin = skin.Id
		elseif pet then
			require(script.Parent.PetService):GrantInto(d, pet.Id)
		end
	end)
	if not updated then
		return false
	end
	-- Only report success once the purchase is on disk. If the save fails,
	-- Roblox retries the receipt later; Purchases[receiptId] (in memory, and on
	-- disk with any later save) stops it from being granted twice.
	if not DataService:SaveNow(player) then
		return false
	end
	local notify = Remotes.Event("Notify")
	if pet then
		require(script.Parent.PetService):Publish(player)
		notify:FireClient(player, `{pet.Name} joined you! Thanks for your support.`, "Good")
	elseif boost then
		notify:FireClient(player, `{boost.Name} activated! Thanks for your support.`, "Good")
	else
		notify:FireClient(player, `Unlocked the {(skin :: Skins.Skin).Name} skin! Thanks for your support.`, "Good")
	end
	return true
end

local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player or not DataService:Get(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok, granted = pcall(StoreService.GrantProduct, StoreService, player, receipt.ProductId, receipt.PurchaseId)
	if ok and granted then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

local function buySkin(player: Player, skinId: any): (boolean, string)
	if not skinLimit(player) then
		return false, "Slow down"
	end
	local skin = type(skinId) == "string" and Skins.Get(skinId)
	local data = DataService:Get(player)
	if not skin or not data or skin.Source ~= "Cash" or not skin.Price then
		return false, "Can't buy that"
	end
	if data.Skins[skin.Id] then
		return false, "Already owned"
	end
	local price = skin.Price :: number
	if data.Cash < price then
		return false, `Need {Format.Cash(price - data.Cash)} more`
	end
	DataService:Update(player, function(d)
		d.Cash -= price
		d.Skins[skin.Id] = true
		d.EquippedSkin = skin.Id
	end)
	return true, `Bought the {skin.Name} skin!`
end

local function equipSkin(player: Player, skinId: any): (boolean, string)
	if not skinLimit(player) then
		return false, "Slow down"
	end
	local skin = type(skinId) == "string" and Skins.Get(skinId)
	local data = DataService:Get(player)
	if not skin or not data then
		return false, "Unknown skin"
	end
	if not Skins.IsUnlocked(skin, data, Modifiers.PlayerPasses(player)) then
		return false, "You don't own that skin yet"
	end
	DataService:Update(player, function(d)
		d.EquippedSkin = skin.Id
	end)
	return true, `Equipped {skin.Name}`
end

local function remoteSell(player: Player): (boolean, string)
	if not sellLimit(player) then
		return false, ""
	end
	if not StoreService:HasPass(player, "RemoteSell") then
		return false, "Requires the Remote Seller pass"
	end
	ShopService:Sell(player)
	return true, ""
end

function StoreService:Init()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, purchased)
		if not purchased then
			return
		end
		for _, pass in Store.Passes do
			if pass.GamePassId == gamePassId then
				setPass(player, pass.Id, true)
				Remotes.Event("Notify"):FireClient(player, `{pass.Name} unlocked! Thanks for your support.`, "Good")
				-- Re-push state so pass-dependent UI (capacity, skins) refreshes.
				DataService:Update(player, function() end)
			end
		end
	end)
	Players.PlayerAdded:Connect(refreshPasses)
	for _, player in Players:GetPlayers() do
		task.spawn(refreshPasses, player)
	end
	Remotes.Function("BuySkin").OnServerInvoke = buySkin
	Remotes.Function("EquipSkin").OnServerInvoke = equipSkin
	Remotes.Function("RemoteSell").OnServerInvoke = remoteSell
end

return StoreService
