-- Reef Rush server entry point: collection loops, cash-in, shop, quests, buffs, prestige and teleports.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(script.Parent.Remotes)
local Data = require(script.Parent.Data)
local World = require(script.Parent.World)
local Quests = require(script.Parent.Quests)
local Buffs = require(script.Parent.Buffs)

local COLLECT_TICK = 0.25
local PLAYER_REACH = 10 -- studs (flat distance) a player can collect from
local CREATURE_RANGE = 40 -- studs around the player creatures will work in
local BASE_JUMP = 60

Workspace.Gravity = Config.Gravity

World.Build()
Buffs.Start()

local notify = Remotes.Notify

local function flatDistance(a, b)
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

local function getRoot(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function applyCharacterStats(player)
	local data = Data.Get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if data and humanoid then
		local speed = Config.UpgradeValue("Speed", data.Levels.Speed)
		if Buffs.IsActive(player, "Haste") then
			speed *= 1.5
		end
		humanoid.WalkSpeed = speed
		humanoid.JumpPower = BASE_JUMP
	end
end
Buffs.OnChanged = function(player)
	applyCharacterStats(player)
	Data.Sync(player)
end

local function zoneUnlocked(data, zoneId)
	return data.Zones[zoneId] == true
end

local function collectMultiplier(player)
	return Buffs.IsActive(player, "Frenzy") and 2 or 1
end

-- Player collection: take shells from the closest coral in reach.
local function collectForPlayer(player, data, root)
	local maxShells = Config.UpgradeValue("Capacity", data.Levels.Capacity)
	local space = maxShells - data.Shells

	local nearest, nearestDistance
	for _, node in World.Nodes do
		if node.Shells > 0 then
			local distance = flatDistance(node.Position, root.Position)
			if distance <= PLAYER_REACH and (not nearestDistance or distance < nearestDistance) then
				nearest, nearestDistance = node, distance
			end
		end
	end
	if not nearest then
		return
	end

	if not zoneUnlocked(data, nearest.Zone) then
		notify(player, "This zone is locked! Unlock it in the Zones tab.", "error", "locked")
		return
	end
	if space <= 0 then
		notify(player, "Satchel full! Cash in at the Dive Station.", "error", "full")
		return
	end

	local power = Config.UpgradeValue("Power", data.Levels.Power) * COLLECT_TICK * collectMultiplier(player)
	local taken = World.Take(nearest, math.min(power, space))
	if taken > 0 then
		data.Shells += taken
		Quests.Report(player, "Collect", taken)
		Remotes.Pop:FireClient(player, nearest.Position + Vector3.new(0, 5, 0), "+" .. math.floor(taken + 0.5), nearest.Color)
	end
end

-- Creatures collect on their own from random nodes near the player.
local function creatureTick(player, data, root)
	if #data.Creatures == 0 then
		return
	end

	local maxShells = Config.UpgradeValue("Capacity", data.Levels.Capacity)
	local candidates = {}
	for _, node in World.Nodes do
		if node.Shells > 0 and zoneUnlocked(data, node.Zone) and flatDistance(node.Position, root.Position) <= CREATURE_RANGE then
			table.insert(candidates, node)
		end
	end
	if #candidates == 0 then
		return
	end

	local multiplier = collectMultiplier(player)
	for _, name in data.Creatures do
		local space = maxShells - data.Shells
		if space <= 0 then
			notify(player, "Satchel full! Your creatures stopped collecting.", "error", "full")
			break
		end
		local def = Config.CreatureByName[name]
		local node = candidates[math.random(1, #candidates)]
		local taken = World.Take(node, math.min(def.Power * multiplier, space))
		if taken > 0 then
			data.Shells += taken
			Quests.Report(player, "Collect", taken)
			Remotes.Pop:FireClient(player, node.Position + Vector3.new(0, 5, 0), "+" .. math.floor(taken + 0.5), Config.RarityColors[def.Rarity])
		end
	end
end

task.spawn(function()
	while true do
		task.wait(COLLECT_TICK)
		for _, player in Players:GetPlayers() do
			local data = Data.Get(player)
			local root = getRoot(player)
			if data and root then
				collectForPlayer(player, data, root)
				Buffs.TryPickup(player, root.Position)
				Data.Sync(player)
			end
		end
		World.Flush()
	end
end)

task.spawn(function()
	while true do
		task.wait(1)
		World.Regen()
		for _, player in Players:GetPlayers() do
			local data = Data.Get(player)
			local root = getRoot(player)
			if data and root then
				creatureTick(player, data, root)
				Data.Sync(player)
			end
		end
	end
end)

-- Cash in
World.CashInPrompt.Triggered:Connect(function(player)
	local data = Data.Get(player)
	if not data then
		return
	end
	local shells = math.floor(data.Shells)
	if shells <= 0 then
		notify(player, "You have no shells to cash in.", "error")
		return
	end
	local coins = math.floor(shells * Config.CoinMultiplier(data.Pearls))
	data.Shells = 0
	data.Coins += coins
	Quests.Report(player, "CashIn", coins)
	Data.Sync(player)
	notify(player, ("Cashed in %s shells for %s coins!"):format(Config.Commas(shells), Config.Commas(coins)), "success")
end)

World.ShopPrompt.Triggered:Connect(function(player)
	Remotes.OpenTab:FireClient(player, "Shop")
end)

World.QuestPrompt.Triggered:Connect(function(player)
	Remotes.OpenTab:FireClient(player, "Quest")
end)

-- Shop
local function rollEgg(egg)
	local total = 0
	for _, weight in egg.Weights do
		total += weight
	end
	local roll = math.random() * total
	for name, weight in egg.Weights do
		roll -= weight
		if roll <= 0 then
			return name
		end
	end
	return next(egg.Weights)
end

local buying = {}

local function handleBuy(player, kind, id, extra)
	local data = Data.Get(player)
	if not data then
		return false, "Still loading your data..."
	end
	if typeof(kind) ~= "string" or typeof(id) ~= "string" then
		return false, "Invalid request."
	end

	if kind == "Upgrade" then
		local upgrade = Config.UpgradeById[id]
		if not upgrade then
			return false, "Unknown upgrade."
		end
		local level = data.Levels[id]
		if level >= upgrade.Max then
			return false, upgrade.Name .. " is maxed out!"
		end
		local cost = Config.UpgradeCost(id, level)
		if data.Coins < cost then
			return false, "Not enough coins."
		end
		data.Coins -= cost
		data.Levels[id] = level + 1
		if id == "Speed" then
			applyCharacterStats(player)
		end
		Quests.Report(player, "Upgrade", 1)
		Data.Sync(player)
		return true, ("%s upgraded to level %d!"):format(upgrade.Name, level + 1)
	elseif kind == "Egg" then
		local egg = Config.EggById[id]
		if not egg then
			return false, "Unknown egg."
		end
		local slots = Config.UpgradeValue("Slots", data.Levels.Slots)
		if #data.Creatures >= slots then
			return false, "Creature slots are full! Sell one or buy more slots."
		end
		if data.Coins < egg.Cost then
			return false, "Not enough coins."
		end
		data.Coins -= egg.Cost
		local name = rollEgg(egg)
		table.insert(data.Creatures, name)
		Quests.Report(player, "Hatch", 1)
		Data.Sync(player)
		Remotes.Hatch:FireClient(player, name)
		return true, ("You hatched a %s %s!"):format(Config.CreatureByName[name].Rarity, name)
	elseif kind == "Zone" then
		local zone = Config.ZoneById[id]
		if not zone then
			return false, "Unknown zone."
		end
		if data.Zones[id] then
			return false, "Zone already unlocked."
		end
		if data.Coins < zone.Cost then
			return false, "Not enough coins."
		end
		data.Coins -= zone.Cost
		data.Zones[id] = true
		Quests.Check(player)
		Data.Sync(player)
		return true, zone.Name .. " unlocked!"
	elseif kind == "Sell" then
		local index = tonumber(extra)
		if not index or index % 1 ~= 0 or index < 1 or index > #data.Creatures then
			return false, "Invalid creature."
		end
		local name = table.remove(data.Creatures, index)
		local value = Config.SellValue(name)
		data.Coins += value
		Data.Sync(player)
		return true, ("Sold %s for %s coins."):format(name, Config.Commas(value))
	elseif kind == "Prestige" then
		local cost = Config.PrestigeCost(data.Pearls)
		if data.Coins < cost then
			return false, ("You need %s coins to Ascend."):format(Config.Commas(cost))
		end
		data.Pearls += 1
		data.Coins = 0
		data.Shells = 0
		for upgradeId in data.Levels do
			data.Levels[upgradeId] = 0
		end
		data.Zones = { Shallows = true }
		data.Creatures = {}
		Quests.Report(player, "Prestige", 1)
		applyCharacterStats(player)
		Data.Sync(player)
		local root = getRoot(player)
		if root then
			root.CFrame = CFrame.new(Config.HubSpawn + Vector3.new(0, 5, 0))
		end
		return true, ("You Ascended! Pearls: %d (x%.2f coins)"):format(data.Pearls, Config.CoinMultiplier(data.Pearls))
	end

	return false, "Unknown request."
end

Remotes.Buy.OnServerInvoke = function(player, kind, id, extra)
	if buying[player] then
		return false, "Slow down!"
	end
	buying[player] = true
	local ok, success, message = pcall(handleBuy, player, kind, id, extra)
	buying[player] = nil
	if not ok then
		warn("[Shop] " .. tostring(success))
		return false, "Something went wrong."
	end
	return success, message
end

Remotes.Teleport.OnServerInvoke = function(player, zoneId)
	local data = Data.Get(player)
	local root = getRoot(player)
	if not data or not root or typeof(zoneId) ~= "string" then
		return false, "Can't teleport right now."
	end

	local target
	if zoneId == "Hub" then
		target = Config.HubSpawn
	else
		local zone = Config.ZoneById[zoneId]
		if not zone then
			return false, "Unknown zone."
		end
		if not zoneUnlocked(data, zoneId) then
			return false, "Unlock this zone first."
		end
		target = zone.Center
	end

	root.CFrame = CFrame.new(target + Vector3.new(0, 5, 0))
	return true, "Teleported!"
end

-- Player lifecycle
local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function()
		task.wait()
		applyCharacterStats(player)
	end)

	Data.Load(player)
	Quests.Check(player)
	applyCharacterStats(player)
	Data.Sync(player)
end

local function onPlayerRemoving(player)
	Data.Release(player)
	Remotes.Forget(player)
	Buffs.Forget(player)
	buying[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

task.spawn(function()
	while true do
		task.wait(Config.AutosaveSeconds)
		for _, player in Players:GetPlayers() do
			task.spawn(Data.Save, player)
		end
	end
end)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		task.spawn(Data.Release, player)
	end
	task.wait(3)
end)
