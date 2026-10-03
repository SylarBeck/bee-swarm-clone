-- Reef Rush server entry point: collection loops, cash-in, shop and teleports.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Data = require(script.Parent.Data)
local World = require(script.Parent.World)

local COLLECT_TICK = 0.25
local PLAYER_REACH = 9 -- studs (flat distance) a player can collect from
local CREATURE_RANGE = 40 -- studs around the player creatures will work in

Workspace.Gravity = Config.Gravity

-- Remotes
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage

local function remote(class, name)
	local r = Instance.new(class)
	r.Name = name
	r.Parent = remotes
	return r
end

local BuyFunction = remote("RemoteFunction", "Buy")
local TeleportFunction = remote("RemoteFunction", "Teleport")
local PopEvent = remote("RemoteEvent", "Pop")
local NotifyEvent = remote("RemoteEvent", "Notify")
local OpenShopEvent = remote("RemoteEvent", "OpenShop")

World.Build()

local noticeTimes = {} -- [player] = { [key] = os.clock() }

local function notify(player, text, kind, throttleKey)
	if throttleKey then
		noticeTimes[player] = noticeTimes[player] or {}
		local last = noticeTimes[player][throttleKey]
		if last and os.clock() - last < 4 then
			return
		end
		noticeTimes[player][throttleKey] = os.clock()
	end
	NotifyEvent:FireClient(player, text, kind or "info")
end

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
		humanoid.WalkSpeed = Config.UpgradeValue("Speed", data.Levels.Speed)
		humanoid.JumpPower = 60
	end
end

local function zoneUnlocked(data, zoneId)
	return data.Zones[zoneId] == true
end

-- Player collection: take shells from the closest coral in reach.
local function collectForPlayer(player, data, root)
	local maxShells = Config.UpgradeValue("Capacity", data.Levels.Capacity)
	local space = maxShells - data.Shells

	local nearest, nearestDistance
	for _, node in World.Nodes do
		if node.Shells > 0 then
			local distance = flatDistance(node.Part.Position, root.Position)
			if distance <= PLAYER_REACH and (not nearestDistance or distance < nearestDistance) then
				nearest, nearestDistance = node, distance
			end
		end
	end
	if not nearest then
		return
	end

	if not zoneUnlocked(data, nearest.Zone) then
		notify(player, "This zone is locked! Unlock it in the Shop > Zones tab.", "error", "locked")
		return
	end
	if space <= 0 then
		notify(player, "Satchel full! Cash in at the Dive Station.", "error", "full")
		return
	end

	local power = Config.UpgradeValue("Power", data.Levels.Power) * COLLECT_TICK
	local taken = World.Take(nearest, math.min(power, space))
	if taken > 0 then
		data.Shells += taken
		PopEvent:FireClient(player, nearest.Part.Position + Vector3.new(0, 5, 0), "+" .. math.floor(taken + 0.5), nearest.Part.Color)
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
		if node.Shells > 0 and zoneUnlocked(data, node.Zone) and flatDistance(node.Part.Position, root.Position) <= CREATURE_RANGE then
			table.insert(candidates, node)
		end
	end
	if #candidates == 0 then
		return
	end

	for _, name in data.Creatures do
		local space = maxShells - data.Shells
		if space <= 0 then
			notify(player, "Satchel full! Your creatures stopped collecting.", "error", "full")
			break
		end
		local def = Config.CreatureByName[name]
		local node = candidates[math.random(1, #candidates)]
		local taken = World.Take(node, math.min(def.Power, space))
		if taken > 0 then
			data.Shells += taken
			PopEvent:FireClient(player, node.Part.Position + Vector3.new(0, 5, 0), "+" .. math.floor(taken + 0.5), Config.RarityColors[def.Rarity])
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
	data.Shells = 0
	data.Coins += shells
	Data.Sync(player)
	notify(player, ("Cashed in %d shells for %d coins!"):format(shells, shells), "success")
end)

World.ShopPrompt.Triggered:Connect(function(player)
	OpenShopEvent:FireClient(player)
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
		Data.Sync(player)
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
		return true, ("Sold %s for %d coins."):format(name, value)
	end

	return false, "Unknown request."
end

BuyFunction.OnServerInvoke = function(player, kind, id, extra)
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

TeleportFunction.OnServerInvoke = function(player, zoneId)
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
	applyCharacterStats(player)
end

local function onPlayerRemoving(player)
	Data.Release(player)
	noticeTimes[player] = nil
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
