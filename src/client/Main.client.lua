-- Reef Rush client: HUD, quest tracker, buffs, menu, hatch reveal, creature visuals and pickups.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local PANEL = Color3.fromRGB(14, 52, 82)
local PANEL_DARK = Color3.fromRGB(8, 30, 50)
local PANEL_LIGHT = Color3.fromRGB(26, 84, 120)
local ACCENT = Color3.fromRGB(0, 200, 220)
local GOLD = Color3.fromRGB(255, 215, 80)
local GOOD = Color3.fromRGB(60, 190, 110)
local BAD = Color3.fromRGB(220, 80, 80)
local DISABLED = Color3.fromRGB(100, 110, 120)
local WHITE = Color3.fromRGB(255, 255, 255)
local MUTED = Color3.fromRGB(180, 215, 235)

local function new(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function corner(inst, radius)
	new("UICorner", { CornerRadius = UDim.new(0, radius or 10) }, inst)
end

local function stroke(inst, color, thickness)
	new("UIStroke", {
		Color = color or Color3.fromRGB(0, 140, 170),
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, inst)
end

local function gradient(inst, top, bottom)
	new("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = 90,
	}, inst)
end

local function panel(props, parent)
	props.BackgroundColor3 = props.BackgroundColor3 or PANEL
	local frame = new("Frame", props, parent)
	corner(frame)
	stroke(frame)
	return frame
end

local function fmt(n)
	n = math.floor(n)
	if n >= 1e9 then
		return ("%.1fB"):format(n / 1e9)
	elseif n >= 1e6 then
		return ("%.1fM"):format(n / 1e6)
	elseif n >= 1e4 then
		return ("%.1fK"):format(n / 1e3)
	end
	return Config.Commas(n)
end

local gui = new("ScreenGui", { Name = "ReefUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))

----------------------------------------------------------------------------
-- HUD (coins, shell bar)
----------------------------------------------------------------------------
local stats = panel({
	Size = UDim2.fromOffset(270, 98),
	Position = UDim2.fromOffset(12, 12),
	BackgroundTransparency = 0.05,
}, gui)
gradient(stats, Color3.fromRGB(24, 80, 116), Color3.fromRGB(10, 40, 66))

local coinsLabel = new("TextLabel", {
	Size = UDim2.new(1, -16, 0, 30),
	Position = UDim2.fromOffset(10, 6),
	BackgroundTransparency = 1,
	Font = Enum.Font.FredokaOne,
	TextSize = 26,
	TextColor3 = GOLD,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "Coins: 0",
}, stats)

local barBack = new("Frame", {
	Size = UDim2.new(1, -20, 0, 24),
	Position = UDim2.fromOffset(10, 42),
	BackgroundColor3 = PANEL_DARK,
}, stats)
corner(barBack, 8)
stroke(barBack, Color3.fromRGB(0, 100, 130), 1)

local barFill = new("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = ACCENT,
}, barBack)
corner(barFill, 8)
gradient(barFill, Color3.fromRGB(120, 255, 255), Color3.fromRGB(0, 150, 190))

local shellsLabel = new("TextLabel", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	TextColor3 = WHITE,
	TextStrokeTransparency = 0.5,
	Text = "Shells 0 / 100",
	ZIndex = 2,
}, barBack)

local infoLabel = new("TextLabel", {
	Size = UDim2.new(1, -20, 0, 20),
	Position = UDim2.fromOffset(10, 72),
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	TextSize = 12,
	TextColor3 = MUTED,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "",
}, stats)

local function updateHud()
	local shells = player:GetAttribute("Shells") or 0
	local maxShells = player:GetAttribute("MaxShells") or 100
	local pearls = player:GetAttribute("Pearls") or 0
	coinsLabel.Text = "Coins: " .. fmt(player:GetAttribute("Coins") or 0)
	shellsLabel.Text = ("Shells %s / %s"):format(fmt(shells), fmt(maxShells))
	barFill.Size = UDim2.fromScale(math.clamp(shells / maxShells, 0, 1), 1)
	barFill.BackgroundColor3 = shells >= maxShells and BAD or WHITE
	if pearls > 0 then
		infoLabel.Text = ("Pearls: %d   Coin bonus: x%.2f"):format(pearls, player:GetAttribute("CoinMult") or 1)
	else
		infoLabel.Text = "Swim near coral. Cash in at the Dive Station!"
	end
end

----------------------------------------------------------------------------
-- Toasts
----------------------------------------------------------------------------
local toast = new("TextLabel", {
	Size = UDim2.fromOffset(480, 42),
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 14),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 1,
	TextTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 16,
	TextColor3 = WHITE,
	Text = "",
	ZIndex = 20,
}, gui)
corner(toast)

local toastToken = 0
local function showToast(text, kind)
	toastToken += 1
	local token = toastToken
	toast.Text = text
	toast.BackgroundColor3 = (kind == "error" and BAD) or (kind == "success" and GOOD) or PANEL
	toast.BackgroundTransparency = 0.05
	toast.TextTransparency = 0
	task.delay(3, function()
		if token == toastToken then
			TweenService:Create(toast, TweenInfo.new(0.5), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
		end
	end)
end

Remotes:WaitForChild("Notify").OnClientEvent:Connect(showToast)

----------------------------------------------------------------------------
-- Quest tracker (bottom-left)
----------------------------------------------------------------------------
local tracker = panel({
	Size = UDim2.fromOffset(300, 84),
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 12, 1, -12),
	BackgroundTransparency = 0.05,
}, gui)
gradient(tracker, Color3.fromRGB(24, 80, 116), Color3.fromRGB(10, 40, 66))

local questTitle = new("TextLabel", {
	Size = UDim2.new(1, -20, 0, 20),
	Position = UDim2.fromOffset(10, 6),
	BackgroundTransparency = 1,
	Font = Enum.Font.FredokaOne,
	TextSize = 16,
	TextColor3 = ACCENT,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "QUEST",
}, tracker)

local questText = new("TextLabel", {
	Size = UDim2.new(1, -20, 0, 20),
	Position = UDim2.fromOffset(10, 26),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	TextColor3 = WHITE,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	Text = "",
}, tracker)

local questBarBack = new("Frame", {
	Size = UDim2.new(1, -20, 0, 18),
	Position = UDim2.fromOffset(10, 54),
	BackgroundColor3 = PANEL_DARK,
}, tracker)
corner(questBarBack, 6)

local questBarFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = GOLD }, questBarBack)
corner(questBarFill, 6)
gradient(questBarFill, Color3.fromRGB(255, 240, 150), Color3.fromRGB(230, 170, 30))

local questBarLabel = new("TextLabel", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 12,
	TextColor3 = WHITE,
	TextStrokeTransparency = 0.5,
	Text = "",
	ZIndex = 2,
}, questBarBack)

local function updateQuest()
	local index = player:GetAttribute("QuestIndex") or 1
	local progress = player:GetAttribute("QuestProgress") or 0
	local quest = Config.GetQuest(index)
	questTitle.Text = ("QUEST #%d   Reward: %s coins"):format(index, fmt(quest.Reward))
	questText.Text = Config.QuestText(quest)
	questBarFill.Size = UDim2.fromScale(math.clamp(progress / quest.Goal, 0, 1), 1)
	questBarLabel.Text = ("%s / %s"):format(fmt(progress), fmt(quest.Goal))
end

----------------------------------------------------------------------------
-- Buff chips (top-right)
----------------------------------------------------------------------------
local buffList = new("Frame", {
	Size = UDim2.fromOffset(190, 140),
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 12),
	BackgroundTransparency = 1,
}, gui)
new("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Right }, buffList)

local buffChips = {}
for _, id in Config.BuffOrder do
	local def = Config.Buffs[id]
	if def.Duration > 0 then
		local chip = panel({
			Size = UDim2.fromOffset(190, 36),
			BackgroundColor3 = PANEL,
			Visible = false,
		}, buffList)
		stroke(chip, def.Color, 2)
		new("TextLabel", {
			Size = UDim2.new(1, -60, 1, 0),
			Position = UDim2.fromOffset(10, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextColor3 = def.Color,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = def.Name,
		}, chip)
		local timer = new("TextLabel", {
			Size = UDim2.fromOffset(50, 36),
			Position = UDim2.new(1, -54, 0, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			TextSize = 16,
			TextColor3 = WHITE,
			Text = "",
		}, chip)
		buffChips[id] = { Chip = chip, Timer = timer }
	end
end

RunService.Heartbeat:Connect(function()
	local now = Workspace:GetServerTimeNow()
	for id, ui in buffChips do
		local expiry = player:GetAttribute("Buff_" .. id) or 0
		local remaining = expiry - now
		ui.Chip.Visible = remaining > 0
		if remaining > 0 then
			ui.Timer.Text = ("%ds"):format(math.ceil(remaining))
		end
	end
end)

----------------------------------------------------------------------------
-- Menu (Shop / Creatures / Zones / Quest / Ascend)
----------------------------------------------------------------------------
local menu = panel({
	Size = UDim2.fromOffset(600, 460),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Visible = false,
	ZIndex = 5,
}, gui)
gradient(menu, Color3.fromRGB(20, 70, 104), Color3.fromRGB(10, 40, 66))
new("UISizeConstraint", { MaxSize = Vector2.new(600, 460) }, menu)

new("TextLabel", {
	Size = UDim2.new(1, -60, 0, 40),
	Position = UDim2.fromOffset(18, 6),
	BackgroundTransparency = 1,
	Font = Enum.Font.FredokaOne,
	TextSize = 30,
	TextColor3 = WHITE,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "Reef Rush",
}, menu)

local closeButton = new("TextButton", {
	Size = UDim2.fromOffset(34, 34),
	Position = UDim2.new(1, -46, 0, 10),
	BackgroundColor3 = BAD,
	Font = Enum.Font.GothamBold,
	TextSize = 18,
	TextColor3 = WHITE,
	Text = "X",
}, menu)
corner(closeButton)

local tabBar = new("Frame", {
	Size = UDim2.new(1, -36, 0, 34),
	Position = UDim2.fromOffset(18, 52),
	BackgroundTransparency = 1,
}, menu)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }, tabBar)

local content = new("ScrollingFrame", {
	Size = UDim2.new(1, -36, 1, -108),
	Position = UDim2.fromOffset(18, 94),
	BackgroundColor3 = PANEL_DARK,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, menu)
corner(content)
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, content)
new("UIPadding", {
	PaddingTop = UDim.new(0, 6),
	PaddingBottom = UDim.new(0, 6),
	PaddingLeft = UDim.new(0, 6),
	PaddingRight = UDim.new(0, 10),
}, content)

local currentTab = "Shop"
local order = 0

local function clearContent()
	order = 0
	for _, child in content:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function addHeader(text)
	order += 1
	new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		TextSize = 20,
		TextColor3 = ACCENT,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = text,
		LayoutOrder = order,
	}, content)
end

local function addRow(title, subtitle, buttonText, buttonColor, onClick, titleColor)
	order += 1
	local row = new("Frame", {
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundColor3 = PANEL_LIGHT,
		LayoutOrder = order,
	}, content)
	corner(row)
	if titleColor then
		stroke(row, titleColor, 1)
	end

	new("TextLabel", {
		Size = UDim2.new(1, -160, 0, 26),
		Position = UDim2.fromOffset(12, 5),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = titleColor or WHITE,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = title,
	}, row)
	new("TextLabel", {
		Size = UDim2.new(1, -160, 0, 20),
		Position = UDim2.fromOffset(12, 31),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextColor3 = MUTED,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = subtitle,
	}, row)

	if buttonText then
		local button = new("TextButton", {
			Size = UDim2.fromOffset(140, 38),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			BackgroundColor3 = buttonColor,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextColor3 = WHITE,
			Text = buttonText,
		}, row)
		corner(button)
		button.Activated:Connect(onClick)
	end
end

local function buy(kind, id, extra)
	local ok, message = Remotes.Buy:InvokeServer(kind, id, extra)
	showToast(message or "...", ok and "success" or "error")
	return ok
end

local function ownedCreatures()
	local list = {}
	local raw = player:GetAttribute("Creatures") or ""
	if raw ~= "" then
		for name in string.gmatch(raw, "[^,]+") do
			table.insert(list, name)
		end
	end
	return list
end

local function zoneUnlocked(id)
	local raw = "," .. (player:GetAttribute("Zones") or "") .. ","
	return string.find(raw, "," .. id .. ",", 1, true) ~= nil
end

local function buildShop()
	local coins = player:GetAttribute("Coins") or 0

	addHeader("Eggs")
	for _, egg in Config.Eggs do
		local parts = {}
		for name, weight in egg.Weights do
			table.insert(parts, { name = name, weight = weight })
		end
		table.sort(parts, function(a, b)
			return a.weight > b.weight
		end)
		local text = {}
		for i = 1, math.min(3, #parts) do
			table.insert(text, parts[i].name)
		end
		addRow(
			egg.Name,
			"Likely: " .. table.concat(text, ", ") .. "...",
			"Buy - " .. fmt(egg.Cost),
			coins >= egg.Cost and GOOD or DISABLED,
			function()
				buy("Egg", egg.Id)
			end
		)
	end

	addHeader("Upgrades")
	for _, upgrade in Config.Upgrades do
		local level = player:GetAttribute("Lv_" .. upgrade.Id) or 0
		if level >= upgrade.Max then
			addRow(upgrade.Name .. "  (MAX)", upgrade.Desc .. ": " .. Config.UpgradeValue(upgrade.Id, level) .. upgrade.Unit, nil)
		else
			local cost = Config.UpgradeCost(upgrade.Id, level)
			addRow(
				("%s  Lv %d/%d"):format(upgrade.Name, level, upgrade.Max),
				("%s: %d%s -> %d%s"):format(
					upgrade.Desc,
					Config.UpgradeValue(upgrade.Id, level),
					upgrade.Unit,
					Config.UpgradeValue(upgrade.Id, level + 1),
					upgrade.Unit
				),
				"Upgrade - " .. fmt(cost),
				coins >= cost and GOOD or DISABLED,
				function()
					buy("Upgrade", upgrade.Id)
				end
			)
		end
	end
end

local function buildCreatures()
	local list = ownedCreatures()
	local slots = player:GetAttribute("Slots") or 0
	addHeader(("Your Creatures (%d / %d)"):format(#list, slots))

	local total = 0
	if #list == 0 then
		addRow("No creatures yet", "Buy an egg in the Shop tab!", nil)
	end
	for index, name in list do
		local def = Config.CreatureByName[name]
		total += def.Power
		addRow(
			name .. "  [" .. def.Rarity .. "]",
			("Collects %d shells/sec"):format(def.Power),
			"Sell - " .. fmt(Config.SellValue(name)),
			BAD,
			function()
				buy("Sell", name, index)
			end,
			Config.RarityColors[def.Rarity]
		)
	end
	if #list > 0 then
		addHeader(("Total creature power: %d shells/sec"):format(total))
	end
end

local function buildZones()
	local coins = player:GetAttribute("Coins") or 0
	addHeader("Zones")

	local function teleport(zoneId)
		local ok, message = Remotes.Teleport:InvokeServer(zoneId)
		if not ok then
			showToast(message, "error")
		else
			menu.Visible = false
		end
	end

	addRow("Dive Hub", "Cash in shells, shop and talk to Captain Finn", "Teleport", ACCENT, function()
		teleport("Hub")
	end)

	for _, zone in Config.Zones do
		local info = ("%d shells per coral, regrows in %ds"):format(zone.NodeShells, zone.RegenSeconds)
		if zoneUnlocked(zone.Id) then
			addRow(zone.Name, info, "Teleport", ACCENT, function()
				teleport(zone.Id)
			end, zone.CoralColors[1])
		else
			addRow(
				zone.Name .. " (Locked)",
				info,
				"Unlock - " .. fmt(zone.Cost),
				coins >= zone.Cost and GOOD or DISABLED,
				function()
					buy("Zone", zone.Id)
				end
			)
		end
	end
end

local function buildQuest()
	local index = player:GetAttribute("QuestIndex") or 1
	local progress = player:GetAttribute("QuestProgress") or 0
	local quest = Config.GetQuest(index)

	addHeader("Captain Finn's Quest #" .. index)
	addRow(
		Config.QuestText(quest),
		("Progress: %s / %s   |   Reward: %s coins"):format(fmt(progress), fmt(quest.Goal), fmt(quest.Reward)),
		nil,
		nil,
		nil,
		GOLD
	)

	addHeader("Coming up")
	for i = 1, 3 do
		local upcoming = Config.GetQuest(index + i)
		addRow(Config.QuestText(upcoming), ("Reward: %s coins"):format(fmt(upcoming.Reward)), nil)
	end

	addHeader("Buff bubbles")
	for _, id in Config.BuffOrder do
		local def = Config.Buffs[id]
		addRow(def.Name, def.Desc .. " - pop the glowing bubbles floating around the zones", nil, nil, nil, def.Color)
	end
end

local ascendConfirmAt = 0
local function buildAscend()
	local coins = player:GetAttribute("Coins") or 0
	local pearls = player:GetAttribute("Pearls") or 0
	local cost = player:GetAttribute("PrestigeCost") or Config.PrestigeCost(0)

	addHeader("Ascend")
	addRow(
		("Pearls: %d"):format(pearls),
		("Each Pearl gives +%d%% coins when you cash in. Current: x%.2f"):format(Config.Prestige.BonusPerPearl * 100, Config.CoinMultiplier(pearls)),
		nil,
		nil,
		nil,
		Color3.fromRGB(255, 240, 200)
	)
	addRow("Resets", "Coins, shells, upgrades, creatures and zones. Pearls and quests stay.", nil)
	addRow(
		"Ascend to the next Pearl",
		("Next bonus: x%.2f"):format(Config.CoinMultiplier(pearls + 1)),
		"Ascend - " .. fmt(cost),
		coins >= cost and GOOD or DISABLED,
		function()
			if os.clock() - ascendConfirmAt < 4 then
				ascendConfirmAt = 0
				if buy("Prestige", "Prestige") then
					menu.Visible = false
				end
			else
				ascendConfirmAt = os.clock()
				showToast("Ascending resets your progress. Click again to confirm.", "error")
			end
		end
	)
end

local tabOrder = { "Shop", "Creatures", "Zones", "Quest", "Ascend" }
local tabs = {
	Shop = buildShop,
	Creatures = buildCreatures,
	Zones = buildZones,
	Quest = buildQuest,
	Ascend = buildAscend,
}

local tabButtons = {}
local function refreshMenu()
	if not menu.Visible then
		return
	end
	local scroll = content.CanvasPosition
	clearContent()
	tabs[currentTab]()
	content.CanvasPosition = scroll
	for name, button in tabButtons do
		button.BackgroundColor3 = name == currentTab and ACCENT or PANEL_LIGHT
	end
end

for _, name in tabOrder do
	local button = new("TextButton", {
		Size = UDim2.fromOffset(100, 34),
		BackgroundColor3 = PANEL_LIGHT,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = WHITE,
		Text = name,
	}, tabBar)
	corner(button)
	tabButtons[name] = button
	button.Activated:Connect(function()
		currentTab = name
		content.CanvasPosition = Vector2.zero
		refreshMenu()
	end)
end

local function openMenu(tab)
	if tabs[tab] then
		currentTab = tab
	end
	menu.Visible = true
	content.CanvasPosition = Vector2.zero
	refreshMenu()
end

closeButton.Activated:Connect(function()
	menu.Visible = false
end)

Remotes:WaitForChild("OpenTab").OnClientEvent:Connect(openMenu)

-- Side buttons
local sideButtons = new("Frame", {
	Size = UDim2.fromOffset(130, 250),
	Position = UDim2.fromOffset(12, 122),
	BackgroundTransparency = 1,
}, gui)
new("UIListLayout", { Padding = UDim.new(0, 6) }, sideButtons)

for _, name in tabOrder do
	local button = new("TextButton", {
		Size = UDim2.fromOffset(130, 42),
		BackgroundColor3 = PANEL,
		Font = Enum.Font.FredokaOne,
		TextSize = 20,
		TextColor3 = WHITE,
		Text = name,
	}, sideButtons)
	corner(button)
	stroke(button)
	button.Activated:Connect(function()
		if menu.Visible and currentTab == name then
			menu.Visible = false
		else
			openMenu(name)
		end
	end)
end

tracker.Active = true
local trackerButton = new("TextButton", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "",
	ZIndex = 3,
}, tracker)
trackerButton.Activated:Connect(function()
	openMenu("Quest")
end)

local refreshQueued = false
player.AttributeChanged:Connect(function()
	updateHud()
	updateQuest()
	if menu.Visible and not refreshQueued then
		refreshQueued = true
		task.delay(0.15, function()
			refreshQueued = false
			refreshMenu()
		end)
	end
end)
updateHud()
updateQuest()

----------------------------------------------------------------------------
-- Egg hatch reveal
----------------------------------------------------------------------------
local hatchFrame = panel({
	Size = UDim2.fromOffset(340, 200),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.4),
	Visible = false,
	ZIndex = 10,
}, gui)
gradient(hatchFrame, Color3.fromRGB(30, 100, 140), Color3.fromRGB(10, 40, 66))
local hatchScale = new("UIScale", { Scale = 1 }, hatchFrame)

local hatchTitle = new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 36),
	Position = UDim2.fromOffset(0, 12),
	BackgroundTransparency = 1,
	Font = Enum.Font.FredokaOne,
	TextSize = 24,
	TextColor3 = WHITE,
	Text = "You hatched...",
	ZIndex = 11,
}, hatchFrame)
local hatchName = new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 60),
	Position = UDim2.fromOffset(0, 56),
	BackgroundTransparency = 1,
	Font = Enum.Font.FredokaOne,
	TextSize = 46,
	TextColor3 = WHITE,
	TextStrokeTransparency = 0.3,
	Text = "",
	ZIndex = 11,
}, hatchFrame)
local hatchInfo = new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 40),
	Position = UDim2.fromOffset(0, 124),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 16,
	TextColor3 = MUTED,
	Text = "",
	ZIndex = 11,
}, hatchFrame)

local hatchToken = 0
Remotes:WaitForChild("Hatch").OnClientEvent:Connect(function(name)
	local def = Config.CreatureByName[name]
	if not def then
		return
	end
	hatchToken += 1
	local token = hatchToken
	local color = Config.RarityColors[def.Rarity]
	hatchName.Text = name
	hatchName.TextColor3 = color
	hatchInfo.Text = ("%s  -  %d shells/sec"):format(def.Rarity, def.Power)
	hatchFrame.UIStroke.Color = color
	hatchScale.Scale = 0.4
	hatchFrame.Visible = true
	TweenService:Create(hatchScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(2.6, function()
		if token == hatchToken then
			hatchFrame.Visible = false
		end
	end)
end)

----------------------------------------------------------------------------
-- Floating "+N" pickups
----------------------------------------------------------------------------
Remotes:WaitForChild("Pop").OnClientEvent:Connect(function(position, text, color)
	local anchor = new("Part", {
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		Transparency = 1,
		Size = Vector3.one,
		Position = position,
	}, Workspace)

	local billboard = new("BillboardGui", {
		Size = UDim2.fromOffset(100, 34),
		AlwaysOnTop = true,
		Adornee = anchor,
	}, anchor)
	local label = new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		TextSize = 24,
		TextColor3 = color,
		TextStrokeTransparency = 0.4,
		Text = text,
	}, billboard)

	local info = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(anchor, info, { Position = position + Vector3.new(0, 4, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(anchor, 1)
end)

----------------------------------------------------------------------------
-- Creature visuals (client-side, for every player)
----------------------------------------------------------------------------
local creatureFolder = new("Folder", { Name = "ReefCreatures" }, Workspace)
local followers = {} -- [Player] = { Raw = string, Models = { { Model, Tail } }, JustBuilt = boolean }

local function buildCreatureModel(name)
	local def = Config.CreatureByName[name]
	local model = new("Model", { Name = name }, creatureFolder)

	local function part(props)
		props.Anchored = true
		props.CanCollide = false
		props.CanQuery = false
		props.CanTouch = false
		props.Material = props.Material or Enum.Material.SmoothPlastic
		return new("Part", props, model)
	end

	local body = part({ Name = "Body", Size = def.Size, Color = def.Color })
	model.PrimaryPart = body

	local eyeOffsetX = def.Size.X * 0.25
	for _, side in { -1, 1 } do
		part({
			Name = "Eye",
			Size = Vector3.new(0.35, 0.35, 0.25),
			Color = Color3.fromRGB(255, 255, 255),
			CFrame = body.CFrame * CFrame.new(side * eyeOffsetX, def.Size.Y * 0.15, -def.Size.Z / 2),
		})
		part({
			Name = "Pupil",
			Size = Vector3.new(0.18, 0.18, 0.2),
			Color = Color3.fromRGB(10, 10, 10),
			CFrame = body.CFrame * CFrame.new(side * eyeOffsetX, def.Size.Y * 0.15, -def.Size.Z / 2 - 0.1),
		})
	end
	part({
		Name = "Fin",
		Size = Vector3.new(0.3, def.Size.Y * 0.5, def.Size.Z * 0.5),
		Color = def.Accent,
		CFrame = body.CFrame * CFrame.new(0, def.Size.Y / 2 + def.Size.Y * 0.2, 0),
	})
	part({
		Name = "Tail",
		Size = Vector3.new(0.3, def.Size.Y * 0.8, def.Size.Z * 0.45),
		Color = def.Accent,
		CFrame = body.CFrame * CFrame.new(0, 0, def.Size.Z / 2 + def.Size.Z * 0.2),
	})

	if def.Rarity == "Legendary" or def.Rarity == "Epic" then
		part({
			Name = "Glow",
			Size = def.Size * 1.15,
			Color = Config.RarityColors[def.Rarity],
			Material = Enum.Material.ForceField,
			CFrame = body.CFrame,
		})
	end
	return model
end

local function rebuildFollowers(owner)
	local state = followers[owner]
	if not state then
		state = { Raw = "", Models = {} }
		followers[owner] = state
	end

	local raw = owner:GetAttribute("Creatures") or ""
	if raw == state.Raw then
		return
	end
	state.Raw = raw

	for _, model in state.Models do
		model:Destroy()
	end
	table.clear(state.Models)

	if raw ~= "" then
		for name in string.gmatch(raw, "[^,]+") do
			if Config.CreatureByName[name] then
				table.insert(state.Models, buildCreatureModel(name))
			end
		end
	end
	state.JustBuilt = true
end

local function trackPlayer(owner)
	rebuildFollowers(owner)
	owner:GetAttributeChangedSignal("Creatures"):Connect(function()
		rebuildFollowers(owner)
	end)
end

for _, owner in Players:GetPlayers() do
	trackPlayer(owner)
end
Players.PlayerAdded:Connect(trackPlayer)
Players.PlayerRemoving:Connect(function(owner)
	local state = followers[owner]
	if state then
		for _, model in state.Models do
			model:Destroy()
		end
		followers[owner] = nil
	end
end)

RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	local alpha = 1 - math.exp(-8 * dt)

	for owner, state in followers do
		local character = owner.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local count = #state.Models
		if root and count > 0 then
			for i, model in state.Models do
				local angle = (i / count) * math.pi * 2 + t * 0.35
				local radius = 5 + math.min(count, 12) * 0.2
				local bob = math.sin(t * 2 + i) * 0.6
				local offset = Vector3.new(math.cos(angle) * radius, -0.5 + bob, math.sin(angle) * radius)
				local wiggle = CFrame.Angles(0, math.sin(t * 3 + i) * 0.25, math.sin(t * 2 + i) * 0.1)
				local target = CFrame.new(root.Position + offset) * root.CFrame.Rotation * wiggle

				if state.JustBuilt then
					model:PivotTo(target)
				else
					model:PivotTo(model:GetPivot():Lerp(target, alpha))
				end
			end
			state.JustBuilt = false
		end
	end
end)
