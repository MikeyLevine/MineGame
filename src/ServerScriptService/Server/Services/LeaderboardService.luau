--!strict
-- Global leaderboards on the camp board: deepest Endless Abyss floor and
-- most prestiges, across every server. Scores live in OrderedDataStores;
-- they're written when a player beats their own stored score (batched, at
-- most once a minute per player, and when they leave) and the top 10 is
-- re-read every couple of minutes.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local DataService = require(script.Parent.DataService)

local LeaderboardService = {}

local REFRESH_SECONDS = 120
local FLUSH_SECONDS = 60
local TOP = 10
-- Studio shares DataStores with the live game; keep test scores off the real boards.
local STORE_SUFFIX = if RunService:IsStudio() then "_Studio" else ""

type Board = {
	Id: string,
	Title: string,
	Store: string,
	Value: (data: any) -> number,
	Format: (value: number) -> string,
	Color: Color3,
}

local BOARDS: { Board } = {
	{
		Id = "Abyss",
		Title = "DEEPEST ABYSS DIVE",
		Store = "DeepMine_AbyssBest_v1",
		Value = function(data)
			return data.Abyss and data.Abyss.Best or 0
		end,
		Format = function(v)
			return `Floor {v}`
		end,
		Color = Color3.fromRGB(255, 90, 140),
	},
	{
		Id = "Prestige",
		Title = "MOST PRESTIGES",
		Store = "DeepMine_Prestige_v1",
		Value = function(data)
			return data.Prestige or 0
		end,
		Format = function(v)
			return `Prestige {v}`
		end,
		Color = Color3.fromRGB(190, 140, 255),
	},
}

local stores: { [string]: OrderedDataStore } = {}
local written: { [Player]: { [string]: number } } = {} -- last value saved per board
local dirty: { [Player]: boolean } = {}
local names: { [number]: string } = {}
local columns: { [string]: Frame } = {}
local statusLabel: TextLabel?

local function storeFor(board: Board): OrderedDataStore?
	if stores[board.Id] then
		return stores[board.Id]
	end
	local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, board.Store .. STORE_SUFFIX)
	if ok then
		stores[board.Id] = store
		return store
	end
	return nil
end

local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		names[userId] = player.DisplayName
		return player.DisplayName
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	names[userId] = if ok and name then name else "Miner"
	return names[userId]
end

-- Saves any score the player has improved since the last write.
local function flush(player: Player)
	if not dirty[player] then
		return
	end
	dirty[player] = nil
	local data = DataService:Get(player)
	if not data then
		return
	end
	local last = written[player] or {}
	written[player] = last
	for _, board in BOARDS do
		local value = board.Value(data)
		local store = storeFor(board)
		if store and value > (last[board.Id] or 0) then
			local ok = pcall(function()
				store:UpdateAsync(tostring(player.UserId), function(old)
					return math.max(tonumber(old) or 0, value)
				end)
			end)
			if ok then
				last[board.Id] = value
			else
				dirty[player] = true -- try again next round
			end
		end
	end
end

local function label(props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
	l.TextColor3 = Color3.fromRGB(244, 236, 224)
	l.TextXAlignment = Enum.TextXAlignment.Left
	for k, v in props do
		(l :: any)[k] = v
	end
	return l
end

local function buildBoard(gui: SurfaceGui)
	gui:ClearAllChildren()
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 18)
	pad.PaddingRight = UDim.new(0, 18)
	pad.PaddingTop = UDim.new(0, 10)
	pad.Parent = gui
	label({ Name = "Title", Text = "TOP MINERS", TextSize = 38, Size = UDim2.new(1, 0, 0, 42),
		TextColor3 = Color3.fromRGB(255, 208, 92), TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold) }).Parent = gui
	statusLabel = label({ Name = "Status", Text = "", TextSize = 16, Position = UDim2.new(0, 0, 1, -26), Size = UDim2.new(1, 0, 0, 20),
		TextColor3 = Color3.fromRGB(176, 164, 148), TextXAlignment = Enum.TextXAlignment.Center })
	statusLabel.Parent = gui
	for i, board in BOARDS do
		local column = Instance.new("Frame")
		column.Name = board.Id
		column.BackgroundTransparency = 1
		column.Position = UDim2.new((i - 1) * 0.5, if i == 1 then 0 else 10, 0, 50)
		column.Size = UDim2.new(0.5, -10, 1, -80)
		column.Parent = gui
		label({ Name = "Header", Text = board.Title, TextSize = 22, Size = UDim2.new(1, 0, 0, 26), TextColor3 = board.Color }).Parent = column
		columns[board.Id] = column
	end
end

local function renderColumn(board: Board, entries: { { key: string, value: number } })
	local column = columns[board.Id]
	if not column then
		return
	end
	for _, child in column:GetChildren() do
		if child.Name == "Row" then
			child:Destroy()
		end
	end
	for rank, entry in entries do
		local row = Instance.new("Frame")
		row.Name = "Row"
		row.BackgroundTransparency = 1
		row.Position = UDim2.new(0, 0, 0, 28 + (rank - 1) * 26)
		row.Size = UDim2.new(1, 0, 0, 26)
		row.Parent = column
		label({ Text = `{rank}.  {nameOf(tonumber(entry.key) or 0)}`, TextSize = 20, Size = UDim2.new(0.66, 0, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = if rank == 1 then Color3.fromRGB(255, 208, 92) else Color3.fromRGB(244, 236, 224) }).Parent = row
		label({ Text = board.Format(entry.value), TextSize = 20, Position = UDim2.fromScale(0.66, 0), Size = UDim2.new(0.34, 0, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = board.Color }).Parent = row
	end
	if #entries == 0 then
		local row = label({ Name = "Row", Text = "Nobody yet. Be the first!", TextSize = 18, Position = UDim2.fromOffset(0, 30),
			Size = UDim2.new(1, 0, 0, 24), TextColor3 = Color3.fromRGB(176, 164, 148) })
		row.Parent = column
	end
end

local function refresh()
	local online = true
	for _, board in BOARDS do
		local store = storeFor(board)
		local ok, pages = false, nil
		if store then
			ok, pages = pcall(store.GetSortedAsync, store, false, TOP, 1)
		end
		if ok and pages then
			renderColumn(board, (pages :: DataStorePages):GetCurrentPage() :: any)
		else
			online = false
		end
	end
	if statusLabel then
		statusLabel.Text = if online then "Updates every few minutes" else "Leaderboard offline right now"
	end
end

function LeaderboardService:Init()
	local camp = workspace:WaitForChild("Camp")
	local model = camp:WaitForChild("Leaderboard", 10)
	local screen = model and model:FindFirstChild("Screen")
	local gui = screen and screen:FindFirstChild("Board")
	if gui and gui:IsA("SurfaceGui") then
		buildBoard(gui)
	else
		warn("[LeaderboardService] Camp has no Leaderboard board")
	end

	DataService.Changed:Connect(function(player: Player)
		dirty[player] = true
	end)
	DataService:OnLoaded(function(player: Player)
		dirty[player] = true
	end)
	Players.PlayerRemoving:Connect(function(player)
		task.spawn(function()
			flush(player)
			written[player] = nil
			dirty[player] = nil
		end)
	end)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			flush(player)
		end
	end)

	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				task.spawn(flush, player)
			end
			task.wait(FLUSH_SECONDS)
		end
	end)
	task.spawn(function()
		task.wait(5)
		while true do
			refresh()
			task.wait(REFRESH_SECONDS)
		end
	end)
end

return LeaderboardService
