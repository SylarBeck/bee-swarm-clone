-- Player data: loading, saving (DataStore) and replication via player attributes.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local store = DataStoreService:GetDataStore(Config.SaveKey)

local Data = {}

-- [player] = { Data = table, Loaded = boolean, Saving = boolean }
local profiles = {}

local function defaultData()
	return {
		Coins = 0,
		Shells = 0,
		Levels = { Capacity = 0, Power = 0, Speed = 0, Slots = 0 },
		Zones = { Shallows = true },
		Creatures = {},
		Pearls = 0,
		QuestIndex = 1,
		QuestProgress = 0,
	}
end

local function reconcile(saved)
	local data = defaultData()
	if type(saved) ~= "table" then
		return data
	end

	data.Coins = math.max(0, tonumber(saved.Coins) or 0)
	data.Shells = math.max(0, tonumber(saved.Shells) or 0)
	data.Pearls = math.max(0, math.floor(tonumber(saved.Pearls) or 0))
	data.QuestIndex = math.max(1, math.floor(tonumber(saved.QuestIndex) or 1))
	data.QuestProgress = math.max(0, tonumber(saved.QuestProgress) or 0)

	if type(saved.Levels) == "table" then
		for _, upgrade in Config.Upgrades do
			local level = math.floor(tonumber(saved.Levels[upgrade.Id]) or 0)
			data.Levels[upgrade.Id] = math.clamp(level, 0, upgrade.Max)
		end
	end

	if type(saved.Zones) == "table" then
		for _, zone in Config.Zones do
			if saved.Zones[zone.Id] then
				data.Zones[zone.Id] = true
			end
		end
	end

	if type(saved.Creatures) == "table" then
		local slots = Config.UpgradeValue("Slots", data.Levels.Slots)
		for _, name in saved.Creatures do
			if Config.CreatureByName[name] and #data.Creatures < slots then
				table.insert(data.Creatures, name)
			end
		end
	end

	data.Shells = math.min(data.Shells, Config.UpgradeValue("Capacity", data.Levels.Capacity))
	return data
end

local function key(player)
	return "Player_" .. player.UserId
end

function Data.Get(player)
	local profile = profiles[player]
	if profile and profile.Loaded then
		return profile.Data
	end
	return nil
end

-- Pushes the player's data to attributes so the client can read it.
function Data.Sync(player)
	local data = Data.Get(player)
	if not data then
		return
	end

	local zones = {}
	for _, zone in Config.Zones do
		if data.Zones[zone.Id] then
			table.insert(zones, zone.Id)
		end
	end

	player:SetAttribute("Coins", data.Coins)
	player:SetAttribute("Shells", data.Shells)
	player:SetAttribute("MaxShells", Config.UpgradeValue("Capacity", data.Levels.Capacity))
	player:SetAttribute("PowerPerSec", Config.UpgradeValue("Power", data.Levels.Power))
	player:SetAttribute("WalkSpeedValue", Config.UpgradeValue("Speed", data.Levels.Speed))
	player:SetAttribute("Slots", Config.UpgradeValue("Slots", data.Levels.Slots))
	for id, level in data.Levels do
		player:SetAttribute("Lv_" .. id, level)
	end
	player:SetAttribute("Pearls", data.Pearls)
	player:SetAttribute("CoinMult", Config.CoinMultiplier(data.Pearls))
	player:SetAttribute("PrestigeCost", Config.PrestigeCost(data.Pearls))
	player:SetAttribute("QuestIndex", data.QuestIndex)
	player:SetAttribute("QuestProgress", data.QuestProgress)

	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		for _, name in { "Coins", "Pearls" } do
			local value = Instance.new("IntValue")
			value.Name = name
			value.Parent = leaderstats
		end
		leaderstats.Parent = player
	end
	leaderstats.Coins.Value = math.floor(data.Coins)
	leaderstats.Pearls.Value = data.Pearls

	player:SetAttribute("Zones", table.concat(zones, ","))
	player:SetAttribute("Creatures", table.concat(data.Creatures, ","))
	player:SetAttribute("DataLoaded", true)
end

function Data.Load(player)
	local profile = { Data = nil, Loaded = false, Saving = false }
	profiles[player] = profile

	local saved, success
	for attempt = 1, 3 do
		success, saved = pcall(function()
			return store:GetAsync(key(player))
		end)
		if success then
			break
		end
		warn(("[Data] Load failed for %s (attempt %d): %s"):format(player.Name, attempt, tostring(saved)))
		task.wait(2 * attempt)
	end

	if not player.Parent then
		profiles[player] = nil
		return false
	end

	if success then
		profile.Data = reconcile(saved)
		profile.Loaded = true
		Data.Sync(player)
		return true
	end

	-- Load failed: play with a temporary profile, but never save it over real data.
	warn("[Data] Using temporary data for " .. player.Name .. "; progress will NOT be saved.")
	profile.Data = defaultData()
	profile.Loaded = true
	profile.Temporary = true
	Data.Sync(player)
	return true
end

function Data.Save(player)
	local profile = profiles[player]
	if not profile or not profile.Loaded or profile.Temporary or profile.Saving then
		return
	end

	profile.Saving = true
	local snapshot = table.clone(profile.Data)
	snapshot.Levels = table.clone(profile.Data.Levels)
	snapshot.Zones = table.clone(profile.Data.Zones)
	snapshot.Creatures = table.clone(profile.Data.Creatures)

	for attempt = 1, 3 do
		local ok, err = pcall(function()
			store:SetAsync(key(player), snapshot)
		end)
		if ok then
			break
		end
		warn(("[Data] Save failed for %s (attempt %d): %s"):format(player.Name, attempt, tostring(err)))
		task.wait(2 * attempt)
	end
	profile.Saving = false
end

function Data.Release(player)
	Data.Save(player)
	profiles[player] = nil
end

return Data
