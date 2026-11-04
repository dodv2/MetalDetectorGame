--[[
	LeaderboardService
	* leaderstats (player list): Level, Cash, Found
	* Global leaderboards (OrderedDataStores) shown on the boards in the hub:
	  Workspace > Map > Hub > Leaderboards > Level / Luck / Found / ShopValue
	  If DataStores aren't available (e.g. Studio without API access) the boards show this server only.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local GameMath = require(Shared.GameMath)
local Format = require(Shared.Format)

local LeaderboardService = {}

local services
local nameCache: { [number]: string } = {}

type BoardDef = {
	Key: string,
	StoreKey: string?,
	Title: string,
	Get: (data: any, player: Player) -> number,
	Show: (value: number) -> string,
	Store: OrderedDataStore?,
	Board: BasePart?,
}

local BOARDS: { BoardDef } = {
	{
		Key = "Level",
		Title = "🏅 Highest Level",
		Get = function(data)
			return data.Level
		end,
		Show = function(value)
			return "Lv " .. value
		end,
	},
	{
		Key = "Luck",
		StoreKey = "LuckPoints", -- additive Luck (new board; the old multiplier board is retired)
		Title = "🍀 Luckiest Hunters",
		Get = function(data)
			-- permanent luck only (no temporary boosts/events), stored in tenths of a Luck point
			return math.floor(GameMath.ComputeLuck(data, 0, 0).Permanent * 1000 + 0.5)
		end,
		Show = function(value)
			return Format.Luck(value / 1000)
		end,
	},
	{
		Key = "Found",
		Title = "⛏ Treasures Found",
		Get = function(data)
			return data.Stats.Found
		end,
		Show = function(value)
			return Format.Commas(value)
		end,
	},
	{
		Key = "ShopValue",
		Title = "💎 Shop Value",
		Get = function(data)
			return math.floor(GameMath.ShopValue(data.Shop.Displays))
		end,
		Show = function(value)
			return Format.Cash(value)
		end,
	},
}

local function getName(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		nameCache[userId] = player.DisplayName
		return player.DisplayName
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local result = if ok and name then name else ("Player " .. userId)
	nameCache[userId] = result
	return result
end

function LeaderboardService:UpdateLeaderstats(player: Player)
	local data = services.DataService:Get(player)
	local folder = player:FindFirstChild("leaderstats")
	if not data or not folder then
		return
	end
	local level = folder:FindFirstChild("Level") :: IntValue?
	local cash = folder:FindFirstChild("Cash") :: StringValue?
	local found = folder:FindFirstChild("Found") :: IntValue?
	if level then
		level.Value = data.Level
	end
	if cash then
		cash.Value = Format.Cash(data.Cash)
	end
	if found then
		found.Value = data.Stats.Found
	end
end

local function createLeaderstats(player: Player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Parent = folder
	local cash = Instance.new("StringValue")
	cash.Name = "Cash"
	cash.Parent = folder
	local found = Instance.new("IntValue")
	found.Name = "Found"
	found.Parent = folder
	folder.Parent = player
	LeaderboardService:UpdateLeaderstats(player)
end

local function buildBoardGui(board: BoardDef)
	local part = board.Board
	if not part then
		return nil
	end
	local gui = part:FindFirstChild("BoardGui") :: SurfaceGui?
	if gui then
		return gui
	end
	local surface = Instance.new("SurfaceGui")
	surface.Name = "BoardGui"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	surface.LightInfluence = 0
	surface.Parent = part

	local background = Instance.new("Frame")
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.fromRGB(16, 44, 66)
	background.BorderSizePixel = 0
	background.Parent = surface

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0.13, 0)
	title.BackgroundColor3 = Color3.fromRGB(255, 196, 70)
	title.BorderSizePixel = 0
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(40, 30, 10)
	title.Text = board.Title
	title.Parent = background

	local list = Instance.new("Frame")
	list.Name = "Rows"
	list.Position = UDim2.new(0.04, 0, 0.15, 0)
	list.Size = UDim2.new(0.92, 0, 0.76, 0)
	list.BackgroundTransparency = 1
	list.Parent = background
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	for rank = 1, 10 do
		local row = Instance.new("TextLabel")
		row.Name = "Row" .. rank
		row.LayoutOrder = rank
		row.Size = UDim2.new(1, 0, 0.1, 0)
		row.BackgroundTransparency = 1
		row.Font = Enum.Font.GothamBold
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = if rank == 1 then Color3.fromRGB(255, 214, 90) elseif rank <= 3 then Color3.fromRGB(220, 230, 240) else Color3.fromRGB(180, 210, 230)
		row.Text = ""
		row.Parent = list
	end

	local footer = Instance.new("TextLabel")
	footer.Name = "Footer"
	footer.Position = UDim2.new(0, 0, 0.93, 0)
	footer.Size = UDim2.new(1, 0, 0.06, 0)
	footer.BackgroundTransparency = 1
	footer.Font = Enum.Font.Gotham
	footer.TextScaled = true
	footer.TextColor3 = Color3.fromRGB(150, 180, 200)
	footer.Text = ""
	footer.Parent = background
	return surface
end

local function render(board: BoardDef, entries: { { UserId: number, Value: number } }, global: boolean)
	local gui = buildBoardGui(board)
	if not gui then
		return
	end
	local rows = gui:FindFirstChild("Rows", true)
	for rank = 1, 10 do
		local row = rows and rows:FindFirstChild("Row" .. rank) :: TextLabel?
		if row then
			local entry = entries[rank]
			row.Text = if entry then string.format("#%d  %s  —  %s", rank, getName(entry.UserId), board.Show(entry.Value)) else ""
		end
	end
	local footer = gui:FindFirstChild("Footer", true) :: TextLabel?
	if footer then
		footer.Text = if global then "All servers • updates every few minutes" else "This server"
	end
end

local function serverEntries(board: BoardDef)
	local entries = {}
	for _, player in services.DataService:GetLoadedPlayers() do
		local data = services.DataService:Get(player)
		table.insert(entries, { UserId = player.UserId, Value = board.Get(data, player) })
	end
	table.sort(entries, function(a, b)
		return a.Value > b.Value
	end)
	return entries
end

local function refreshBoards()
	for _, board in BOARDS do
		local store = board.Store
		local entries = nil
		if store and services.DataService.StoreAvailable then
			local ok, result = pcall(function()
				local pages = store:GetSortedAsync(false, 10)
				local page = pages:GetCurrentPage()
				local list = {}
				for _, entry in page do
					table.insert(list, { UserId = tonumber(entry.key) or 0, Value = entry.value })
				end
				return list
			end)
			if ok then
				entries = result
			end
		end
		if entries and #entries > 0 then
			render(board, entries, true)
		else
			render(board, serverEntries(board), false)
		end
	end
end

local function pushScores()
	if not services.DataService.StoreAvailable then
		return
	end
	for _, player in services.DataService:GetLoadedPlayers() do
		local data = services.DataService:Get(player)
		if services.DataService:IsSandboxed(player) then
			continue -- developer test sessions never reach the global boards
		end
		for _, board in BOARDS do
			if board.Store then
				local value = board.Get(data, player)
				pcall(function()
					(board.Store :: OrderedDataStore):SetAsync(tostring(player.UserId), value)
				end)
			end
		end
		task.wait(0.5)
	end
end

function LeaderboardService:Init(allServices)
	services = allServices
end

function LeaderboardService:Start()
	services.DataService.ProfileLoaded:Connect(function(player)
		createLeaderstats(player)
	end)
	for _, player in services.DataService:GetLoadedPlayers() do
		createLeaderstats(player)
	end
	services.DataService.ProfileReleasing:Connect(function(player)
		if not services.DataService.StoreAvailable then
			return
		end
		local data = services.DataService:Get(player)
		if not data or services.DataService:IsSandboxed(player) then
			return
		end
		for _, board in BOARDS do
			if board.Store then
				local value = board.Get(data, player)
				task.spawn(pcall, function()
					(board.Store :: OrderedDataStore):SetAsync(tostring(player.UserId), value)
				end)
			end
		end
	end)

	local hub = Workspace:WaitForChild("Map"):WaitForChild("Hub")
	local boardsFolder = hub:WaitForChild("Leaderboards", 10)
	for _, board in BOARDS do
		board.Board = boardsFolder and boardsFolder:FindFirstChild(board.Key) :: BasePart?
		local ok, store = pcall(function()
			return DataStoreService:GetOrderedDataStore(GameConfig.LeaderboardPrefix .. (board.StoreKey or board.Key))
		end)
		if ok then
			board.Store = store
		end
	end

	task.spawn(function()
		while true do
			pushScores()
			task.wait(GameConfig.LeaderboardUpdateInterval)
		end
	end)
	task.wait(5)
	while true do
		refreshBoards()
		task.wait(GameConfig.LeaderboardRefreshInterval)
	end
end

return LeaderboardService
