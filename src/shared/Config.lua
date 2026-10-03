-- Shared game configuration for Reef Rush. Read by both server and client.
local Config = {}

Config.SaveKey = "ReefRushV1"
Config.AutosaveSeconds = 60
Config.Gravity = 90
Config.HubSpawn = Vector3.new(0, 0, 25)

Config.RarityColors = {
	Common = Color3.fromRGB(225, 225, 225),
	Rare = Color3.fromRGB(80, 160, 255),
	Epic = Color3.fromRGB(190, 100, 255),
	Legendary = Color3.fromRGB(255, 200, 40),
}

-- Zones: shells are collected from coral nodes. Bigger nodes deeper down.
Config.Zones = {
	{
		Id = "Shallows",
		Name = "Sunny Shallows",
		Cost = 0,
		Center = Vector3.new(0, 0, -170),
		Radius = 75,
		NodeCount = 35,
		NodeShells = 30,
		RegenSeconds = 25,
		GroundColor = Color3.fromRGB(120, 210, 200),
		CoralColors = { Color3.fromRGB(255, 120, 150), Color3.fromRGB(255, 170, 90), Color3.fromRGB(255, 220, 110) },
	},
	{
		Id = "Kelp",
		Name = "Kelp Forest",
		Cost = 4000,
		Center = Vector3.new(150, 0, 85),
		Radius = 75,
		NodeCount = 35,
		NodeShells = 150,
		RegenSeconds = 30,
		GroundColor = Color3.fromRGB(70, 150, 90),
		CoralColors = { Color3.fromRGB(120, 255, 160), Color3.fromRGB(90, 220, 220), Color3.fromRGB(180, 255, 120) },
	},
	{
		Id = "Trench",
		Name = "Deep Trench",
		Cost = 40000,
		Center = Vector3.new(-150, 0, 85),
		Radius = 75,
		NodeCount = 35,
		NodeShells = 700,
		RegenSeconds = 40,
		GroundColor = Color3.fromRGB(60, 50, 110),
		CoralColors = { Color3.fromRGB(190, 110, 255), Color3.fromRGB(90, 140, 255), Color3.fromRGB(255, 90, 220) },
	},
}

-- Creatures: Power = shells collected per second automatically.
Config.Creatures = {
	{ Name = "Crab", Rarity = "Common", Power = 2, Color = Color3.fromRGB(235, 90, 70), Accent = Color3.fromRGB(255, 160, 120), Size = Vector3.new(1.6, 1, 1.4) },
	{ Name = "Clownfish", Rarity = "Common", Power = 3, Color = Color3.fromRGB(255, 140, 40), Accent = Color3.fromRGB(255, 255, 255), Size = Vector3.new(1, 1.1, 1.8) },
	{ Name = "Starfish", Rarity = "Common", Power = 5, Color = Color3.fromRGB(255, 190, 90), Accent = Color3.fromRGB(255, 230, 160), Size = Vector3.new(1.8, 0.5, 1.8) },
	{ Name = "Pufferfish", Rarity = "Rare", Power = 9, Color = Color3.fromRGB(240, 220, 120), Accent = Color3.fromRGB(200, 170, 60), Size = Vector3.new(1.8, 1.8, 1.8) },
	{ Name = "Seahorse", Rarity = "Rare", Power = 14, Color = Color3.fromRGB(255, 120, 190), Accent = Color3.fromRGB(255, 200, 230), Size = Vector3.new(0.9, 2.2, 0.9) },
	{ Name = "Jellyfish", Rarity = "Epic", Power = 30, Color = Color3.fromRGB(190, 140, 255), Accent = Color3.fromRGB(230, 200, 255), Size = Vector3.new(1.8, 1.4, 1.8) },
	{ Name = "Octopus", Rarity = "Epic", Power = 55, Color = Color3.fromRGB(200, 70, 120), Accent = Color3.fromRGB(255, 120, 170), Size = Vector3.new(2, 1.8, 2) },
	{ Name = "Turtle", Rarity = "Legendary", Power = 120, Color = Color3.fromRGB(80, 180, 100), Accent = Color3.fromRGB(150, 110, 60), Size = Vector3.new(2.4, 1.2, 2.8) },
	{ Name = "Shark", Rarity = "Legendary", Power = 220, Color = Color3.fromRGB(110, 140, 170), Accent = Color3.fromRGB(240, 240, 250), Size = Vector3.new(1.6, 1.6, 4) },
	{ Name = "Anglerfish", Rarity = "Legendary", Power = 450, Color = Color3.fromRGB(50, 50, 80), Accent = Color3.fromRGB(255, 240, 120), Size = Vector3.new(2.4, 2.2, 2.6) },
}

-- Eggs: Weights are relative odds.
Config.Eggs = {
	{
		Id = "Basic",
		Name = "Basic Egg",
		Cost = 250,
		Weights = { Crab = 45, Clownfish = 30, Starfish = 15, Pufferfish = 8, Seahorse = 2 },
	},
	{
		Id = "Coral",
		Name = "Coral Egg",
		Cost = 4000,
		Weights = { Starfish = 20, Pufferfish = 30, Seahorse = 25, Jellyfish = 17, Octopus = 7, Turtle = 1 },
	},
	{
		Id = "Abyss",
		Name = "Abyss Egg",
		Cost = 45000,
		Weights = { Jellyfish = 25, Octopus = 40, Turtle = 25, Shark = 9.5, Anglerfish = 0.5 },
	},
}

-- Upgrades: value = Base + Step * level, cost = CostBase * CostGrowth ^ level.
Config.Upgrades = {
	{ Id = "Capacity", Name = "Shell Satchel", Desc = "Carry more shells", Base = 100, Step = 100, Max = 20, CostBase = 100, CostGrowth = 1.55, Unit = " shells" },
	{ Id = "Power", Name = "Collector Claw", Desc = "Collect shells faster", Base = 16, Step = 6, Max = 20, CostBase = 150, CostGrowth = 1.6, Unit = "/sec" },
	{ Id = "Speed", Name = "Flippers", Desc = "Swim faster", Base = 16, Step = 1, Max = 12, CostBase = 300, CostGrowth = 1.8, Unit = "" },
	{ Id = "Slots", Name = "Creature Slots", Desc = "Hold more creatures", Base = 4, Step = 1, Max = 8, CostBase = 1000, CostGrowth = 2.6, Unit = "" },
}

-- Prestige ("Ascend"): reset progress for a permanent coin bonus.
Config.Prestige = { BaseCost = 250000, CostGrowth = 2, BonusPerPearl = 0.25 }

function Config.PrestigeCost(pearls)
	return math.floor(Config.Prestige.BaseCost * Config.Prestige.CostGrowth ^ pearls)
end

function Config.CoinMultiplier(pearls)
	return 1 + Config.Prestige.BonusPerPearl * pearls
end

-- Buff bubbles that float around the zones.
Config.Tokens = { MaxActive = 12, SpawnInterval = 8, Lifetime = 90, PickupRange = 8 }
Config.Buffs = {
	Haste = { Name = "Swift Current", Label = "SPEED", Desc = "+50% swim speed", Duration = 60, Color = Color3.fromRGB(80, 230, 255) },
	Frenzy = { Name = "Shell Frenzy", Label = "x2", Desc = "Double shell collection", Duration = 45, Color = Color3.fromRGB(255, 120, 200) },
	Burst = { Name = "Pearl Burst", Label = "COINS", Desc = "Instant coins", Duration = 0, Color = Color3.fromRGB(255, 220, 70) },
}
Config.BuffOrder = { "Haste", "Frenzy", "Burst" }

-- Quests: Captain Finn hands these out in order; they never run out.
Config.Quests = {
	{ Type = "Collect", Goal = 100, Reward = 100 },
	{ Type = "CashIn", Goal = 100, Reward = 150 },
	{ Type = "Hatch", Goal = 1, Reward = 200 },
	{ Type = "Upgrade", Goal = 2, Reward = 300 },
	{ Type = "Collect", Goal = 1000, Reward = 600 },
	{ Type = "Hatch", Goal = 3, Reward = 800 },
	{ Type = "CashIn", Goal = 5000, Reward = 1500 },
	{ Type = "HaveZone", Zone = "Kelp", Goal = 1, Reward = 3000 },
	{ Type = "Bubble", Goal = 5, Reward = 2500 },
	{ Type = "Hatch", Goal = 10, Reward = 6000 },
	{ Type = "Collect", Goal = 20000, Reward = 10000 },
	{ Type = "HaveZone", Zone = "Trench", Goal = 1, Reward = 25000 },
	{ Type = "CashIn", Goal = 250000, Reward = 50000 },
	{ Type = "Prestige", Goal = 1, Reward = 25000 },
}

local endlessCycle = {
	{ Type = "Collect", Base = 60000, Factor = 0.3 },
	{ Type = "CashIn", Base = 60000, Factor = 0.3 },
	{ Type = "Hatch", Base = 8, Factor = 6000 },
	{ Type = "Bubble", Base = 8, Factor = 5000 },
}

function Config.GetQuest(index)
	local quest = Config.Quests[index]
	if quest then
		return quest
	end
	local n = index - #Config.Quests
	local entry = endlessCycle[(n - 1) % #endlessCycle + 1]
	local scale = 1.25 ^ n
	local goal = math.floor(entry.Base * scale)
	if goal > 100 then
		goal = math.floor(goal / 100) * 100
	end
	local reward = (entry.Type == "Collect" or entry.Type == "CashIn") and goal * entry.Factor or entry.Factor * scale
	return { Type = entry.Type, Goal = goal, Reward = math.floor(reward) }
end

local function commas(n)
	local grouped = tostring(math.floor(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return grouped
end
Config.Commas = commas

function Config.QuestText(quest)
	local t = quest.Type
	if t == "Collect" then
		return ("Collect %s shells"):format(commas(quest.Goal))
	elseif t == "CashIn" then
		return ("Earn %s coins at the Dive Station"):format(commas(quest.Goal))
	elseif t == "Hatch" then
		return ("Hatch %s egg%s"):format(commas(quest.Goal), quest.Goal == 1 and "" or "s")
	elseif t == "Upgrade" then
		return ("Buy %s upgrades"):format(commas(quest.Goal))
	elseif t == "Bubble" then
		return ("Pop %s buff bubbles"):format(commas(quest.Goal))
	elseif t == "HaveZone" then
		return "Unlock the " .. Config.ZoneById[quest.Zone].Name
	elseif t == "Prestige" then
		return "Ascend once to earn a Pearl"
	end
	return "???"
end

Config.ZoneById = {}
for _, zone in Config.Zones do
	Config.ZoneById[zone.Id] = zone
end

Config.CreatureByName = {}
for _, creature in Config.Creatures do
	Config.CreatureByName[creature.Name] = creature
end

Config.EggById = {}
for _, egg in Config.Eggs do
	Config.EggById[egg.Id] = egg
end

Config.UpgradeById = {}
for _, upgrade in Config.Upgrades do
	Config.UpgradeById[upgrade.Id] = upgrade
end

function Config.UpgradeValue(id, level)
	local upgrade = Config.UpgradeById[id]
	return upgrade.Base + upgrade.Step * level
end

function Config.UpgradeCost(id, level)
	local upgrade = Config.UpgradeById[id]
	return math.floor(upgrade.CostBase * upgrade.CostGrowth ^ level + 0.5)
end

function Config.SellValue(creatureName)
	return Config.CreatureByName[creatureName].Power * 20
end

return Config
