-- Player data: persistent profile, level/XP, inventory, equipment.
-- Uses DataStoreService when available; falls back to in-memory in Studio
-- without API access enabled. Pure server module exposed via _G.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LevelConfig = require(Shared.Config.LevelConfig)
local ItemConfig = require(Shared.Config.ItemConfig)
local ZoneConfig = require(Shared.Config.ZoneConfig)
local Remotes = require(Shared.Remotes)

local DATA_VERSION = 1
local STORE_NAME = "DragonsOfFreeport_v" .. DATA_VERSION
local store
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then store = result end
end

local profiles = {}
local PlayerDataService = {}

local function defaultProfile()
	local stats = LevelConfig.GetStatsForLevel(1)
	return {
		race = "Human",
		level = 1,
		xp = 0,
		hp = stats.MaxHP,
		mp = stats.MaxMP,
		gold = 0,
		inventory = {},
		equipment = { Weapon = nil, Chest = nil },
		homeCity = "Freeport",
	}
end

local function loadProfile(player)
	local data
	if store then
		local ok, result = pcall(function()
			return store:GetAsync("p_" .. player.UserId)
		end)
		if ok and type(result) == "table" then
			data = result
		end
	end
	data = data or defaultProfile()
	-- forward-compat: ensure missing keys exist
	for k, v in pairs(defaultProfile()) do
		if data[k] == nil then data[k] = v end
	end
	profiles[player] = data
	return data
end

local function saveProfile(player)
	local data = profiles[player]
	if not data or not store then return end
	pcall(function()
		store:SetAsync("p_" .. player.UserId, data)
	end)
end

function PlayerDataService.Get(player)
	return profiles[player]
end

function PlayerDataService.Replicate(player)
	local data = profiles[player]
	if not data then return end
	Remotes.Event("DataUpdated"):FireClient(player, {
		race = data.race,
		level = data.level,
		xp = data.xp,
		xpRequired = LevelConfig.GetXPRequired(data.level),
		hp = data.hp,
		mp = data.mp,
		gold = data.gold,
		stats = PlayerDataService.GetEffectiveStats(player),
	})
	Remotes.Event("InventoryUpdated"):FireClient(player, {
		inventory = data.inventory,
		equipment = data.equipment,
	})
end

function PlayerDataService.GetEffectiveStats(player)
	local data = profiles[player]
	if not data then return nil end
	local stats = LevelConfig.GetStatsForLevel(data.level)
	stats.Damage = 5 -- bare-handed baseline
	stats.Armor = 0
	for _, itemId in pairs(data.equipment) do
		local def = itemId and ItemConfig.Get(itemId)
		if def and def.stats then
			for k, v in pairs(def.stats) do
				stats[k] = (stats[k] or 0) + v
			end
		end
	end
	return stats
end

local function notify(player, message)
	Remotes.Event("NotifyPlayer"):FireClient(player, message)
end

function PlayerDataService.AwardXP(player, amount)
	local data = profiles[player]
	if not data then return end
	if data.level >= LevelConfig.MaxLevel then return end
	data.xp = data.xp + amount
	notify(player, string.format("+%d XP", amount))
	while data.level < LevelConfig.MaxLevel and data.xp >= LevelConfig.GetXPRequired(data.level) do
		data.xp = data.xp - LevelConfig.GetXPRequired(data.level)
		data.level = data.level + 1
		local newStats = LevelConfig.GetStatsForLevel(data.level)
		data.hp = newStats.MaxHP
		data.mp = newStats.MaxMP
		notify(player, string.format("DING! You are now level %d!", data.level))
		local char = player.Character
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.MaxHealth = newStats.MaxHP
				hum.Health = newStats.MaxHP
			end
		end
	end
	PlayerDataService.Replicate(player)
end

function PlayerDataService.AddItem(player, itemId, qty)
	qty = qty or 1
	local data = profiles[player]
	local def = ItemConfig.Get(itemId)
	if not data or not def then return end
	if def.slot == "Currency" and itemId == "gold_coin" then
		data.gold = data.gold + qty
	else
		if def.stackable then
			for _, entry in ipairs(data.inventory) do
				if entry.id == itemId then
					entry.qty = entry.qty + qty
					PlayerDataService.Replicate(player)
					notify(player, string.format("Looted %dx %s", qty, def.name))
					return
				end
			end
		end
		table.insert(data.inventory, { id = itemId, qty = qty })
		notify(player, string.format("Looted %s", def.name))
	end
	PlayerDataService.Replicate(player)
end

function PlayerDataService.EquipItem(player, slotIndex)
	local data = profiles[player]
	if not data then return end
	local entry = data.inventory[slotIndex]
	if not entry then return end
	local def = ItemConfig.Get(entry.id)
	if not def or not (def.slot == "Weapon" or def.slot == "Chest") then return end
	if def.levelReq and data.level < def.levelReq then
		notify(player, string.format("Requires level %d.", def.levelReq))
		return
	end
	local previous = data.equipment[def.slot]
	data.equipment[def.slot] = entry.id
	table.remove(data.inventory, slotIndex)
	if previous then
		table.insert(data.inventory, { id = previous, qty = 1 })
	end
	notify(player, "Equipped " .. def.name)
	PlayerDataService.Replicate(player)
end

function PlayerDataService.ConsumeItem(player, slotIndex)
	local data = profiles[player]
	if not data then return end
	local entry = data.inventory[slotIndex]
	if not entry then return end
	local def = ItemConfig.Get(entry.id)
	if not def or not def.consume then return end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and def.consume.Heal then
		hum.Health = math.min(hum.MaxHealth, hum.Health + def.consume.Heal)
	end
	entry.qty = entry.qty - 1
	if entry.qty <= 0 then
		table.remove(data.inventory, slotIndex)
	end
	PlayerDataService.Replicate(player)
end

local function onPlayerAdded(player)
	loadProfile(player)
	-- Spawn at Freeport.
	player.RespawnLocation = nil
	player.CharacterAdded:Connect(function(char)
		local hum = char:WaitForChild("Humanoid")
		local stats = LevelConfig.GetStatsForLevel(profiles[player].level)
		hum.MaxHealth = stats.MaxHP
		hum.Health = stats.MaxHP
		local hrp = char:WaitForChild("HumanoidRootPart")
		hrp.CFrame = CFrame.new(ZoneConfig.FreeportSpawn + Vector3.new(math.random(-15, 15), 5, math.random(-15, 15)))
		PlayerDataService.Replicate(player)
	end)
	player:LoadCharacter()
end

local function onPlayerRemoving(player)
	saveProfile(player)
	profiles[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end

game:BindToClose(function()
	for player in pairs(profiles) do
		saveProfile(player)
	end
end)

-- Periodic autosave.
task.spawn(function()
	while true do
		task.wait(120)
		for player in pairs(profiles) do
			saveProfile(player)
		end
	end
end)

-- Remotes
Remotes.Function("GetMyData").OnServerInvoke = function(player)
	return profiles[player]
end

Remotes.Event("UseItem").OnServerEvent:Connect(function(player, action, slotIndex)
	if action == "equip" then
		PlayerDataService.EquipItem(player, slotIndex)
	elseif action == "consume" then
		PlayerDataService.ConsumeItem(player, slotIndex)
	end
end)

_G.PlayerDataService = PlayerDataService
return PlayerDataService
