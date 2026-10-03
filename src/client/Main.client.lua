-- Reef Rush client: HUD, shop/creature/zone menu, creature visuals and floating pickups.
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
local PANEL_LIGHT = Color3.fromRGB(26, 84, 120)
local ACCENT = Color3.fromRGB(0, 190, 210)
local GOOD = Color3.fromRGB(60, 190, 110)
local BAD = Color3.fromRGB(220, 80, 80)
local WHITE = Color3.fromRGB(255, 255, 255)

local function new(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function corner(inst, radius)
	new("UICorner", { CornerRadius = UDim.new(0, radius or 8) }, inst)
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
	local s = tostring(n)
	local grouped = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return grouped
end

local gui = new("ScreenGui", { Name = "ReefUI", ResetOnSpawn = false }, player:WaitForChild("PlayerGui"))

----------------------------------------------------------------------------
-- HUD
----------------------------------------------------------------------------
local stats = new("Frame", {
	Size = UDim2.fromOffset(260, 92),
	Position = UDim2.fromOffset(12, 12),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.1,
}, gui)
corner(stats)

local coinsLabel = new("TextLabel", {
	Size = UDim2.new(1, -16, 0, 30),
	Position = UDim2.fromOffset(8, 6),
	BackgroundTransparency = 1,
	Font = Enum.Font.FredokaOne,
	TextSize = 24,
	TextColor3 = Color3.fromRGB(255, 215, 80),
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "Coins: 0",
}, stats)

local barBack = new("Frame", {
	Size = UDim2.new(1, -16, 0, 22),
	Position = UDim2.fromOffset(8, 42),
	BackgroundColor3 = Color3.fromRGB(8, 28, 46),
}, stats)
corner(barBack, 6)

local barFill = new("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = ACCENT,
}, barBack)
corner(barFill, 6)

local shellsLabel = new("TextLabel", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	TextColor3 = WHITE,
	Text = "Shells 0 / 100",
}, barBack)

new("TextLabel", {
	Size = UDim2.new(1, -16, 0, 18),
	Position = UDim2.fromOffset(8, 68),
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	TextSize = 12,
	TextColor3 = Color3.fromRGB(180, 220, 240),
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "Swim near coral to collect. Cash in at the Dive Station!",
}, stats)

local function updateHud()
	local shells = player:GetAttribute("Shells") or 0
	local maxShells = player:GetAttribute("MaxShells") or 100
	coinsLabel.Text = "Coins: " .. fmt(player:GetAttribute("Coins") or 0)
	shellsLabel.Text = ("Shells %s / %s"):format(fmt(shells), fmt(maxShells))
	barFill.Size = UDim2.fromScale(math.clamp(shells / maxShells, 0, 1), 1)
	barFill.BackgroundColor3 = shells >= maxShells and BAD or ACCENT
end

----------------------------------------------------------------------------
-- Toasts
----------------------------------------------------------------------------
local toast = new("TextLabel", {
	Size = UDim2.fromOffset(460, 40),
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 14),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 1,
	TextTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 16,
	TextColor3 = WHITE,
	Text = "",
}, gui)
corner(toast)

local toastToken = 0
local function showToast(text, kind)
	toastToken += 1
	local token = toastToken
	toast.Text = text
	toast.BackgroundColor3 = (kind == "error" and BAD) or (kind == "success" and GOOD) or PANEL
	toast.BackgroundTransparency = 0.1
	toast.TextTransparency = 0
	task.delay(3, function()
		if token == toastToken then
			TweenService:Create(toast, TweenInfo.new(0.5), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
		end
	end)
end

Remotes:WaitForChild("Notify").OnClientEvent:Connect(showToast)

----------------------------------------------------------------------------
-- Menu (Shop / Creatures / Zones)
----------------------------------------------------------------------------
local menu = new("Frame", {
	Size = UDim2.fromOffset(580, 440),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	BackgroundColor3 = PANEL,
	Visible = false,
}, gui)
corner(menu, 12)

new("TextLabel", {
	Size = UDim2.new(1, -60, 0, 40),
	Position = UDim2.fromOffset(16, 6),
	BackgroundTransparency = 1,
	Font = Enum.Font.FredokaOne,
	TextSize = 28,
	TextColor3 = WHITE,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "Reef Rush",
}, menu)

local closeButton = new("TextButton", {
	Size = UDim2.fromOffset(34, 34),
	Position = UDim2.new(1, -44, 0, 8),
	BackgroundColor3 = BAD,
	Font = Enum.Font.GothamBold,
	TextSize = 18,
	TextColor3 = WHITE,
	Text = "X",
}, menu)
corner(closeButton)

local tabBar = new("Frame", {
	Size = UDim2.new(1, -32, 0, 34),
	Position = UDim2.fromOffset(16, 50),
	BackgroundTransparency = 1,
}, menu)
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 8),
}, tabBar)

local content = new("ScrollingFrame", {
	Size = UDim2.new(1, -32, 1, -104),
	Position = UDim2.fromOffset(16, 92),
	BackgroundColor3 = Color3.fromRGB(8, 32, 52),
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
		Size = UDim2.new(1, 0, 0, 26),
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
		Size = UDim2.new(1, 0, 0, 54),
		BackgroundColor3 = PANEL_LIGHT,
		LayoutOrder = order,
	}, content)
	corner(row)

	new("TextLabel", {
		Size = UDim2.new(1, -150, 0, 26),
		Position = UDim2.fromOffset(10, 4),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = titleColor or WHITE,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = title,
	}, row)
	new("TextLabel", {
		Size = UDim2.new(1, -150, 0, 20),
		Position = UDim2.fromOffset(10, 29),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(190, 220, 240),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = subtitle,
	}, row)

	if buttonText then
		local button = new("TextButton", {
			Size = UDim2.fromOffset(130, 36),
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
			coins >= egg.Cost and GOOD or Color3.fromRGB(110, 110, 110),
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
				coins >= cost and GOOD or Color3.fromRGB(110, 110, 110),
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

	addRow("Dive Hub", "Cash in shells and shop here", "Teleport", ACCENT, function()
		teleport("Hub")
	end)

	for _, zone in Config.Zones do
		local info = ("%d shells per coral, regrows in %ds"):format(zone.NodeShells, zone.RegenSeconds)
		if zoneUnlocked(zone.Id) then
			addRow(zone.Name, info, "Teleport", ACCENT, function()
				teleport(zone.Id)
			end)
		else
			addRow(
				zone.Name .. " (Locked)",
				info,
				"Unlock - " .. fmt(zone.Cost),
				coins >= zone.Cost and GOOD or Color3.fromRGB(110, 110, 110),
				function()
					buy("Zone", zone.Id)
				end
			)
		end
	end
end

local tabs = {
	Shop = buildShop,
	Creatures = buildCreatures,
	Zones = buildZones,
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

for _, name in { "Shop", "Creatures", "Zones" } do
	local button = new("TextButton", {
		Size = UDim2.fromOffset(110, 34),
		BackgroundColor3 = PANEL_LIGHT,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
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
	currentTab = tab or currentTab
	menu.Visible = true
	content.CanvasPosition = Vector2.zero
	refreshMenu()
end

closeButton.Activated:Connect(function()
	menu.Visible = false
end)

Remotes:WaitForChild("OpenShop").OnClientEvent:Connect(function()
	openMenu("Shop")
end)

-- Side buttons
local sideButtons = new("Frame", {
	Size = UDim2.fromOffset(120, 150),
	Position = UDim2.fromOffset(12, 116),
	BackgroundTransparency = 1,
}, gui)
new("UIListLayout", { Padding = UDim.new(0, 8) }, sideButtons)

for _, name in { "Shop", "Creatures", "Zones" } do
	local button = new("TextButton", {
		Size = UDim2.fromOffset(120, 42),
		BackgroundColor3 = PANEL,
		Font = Enum.Font.FredokaOne,
		TextSize = 20,
		TextColor3 = WHITE,
		Text = name,
	}, sideButtons)
	corner(button)
	button.Activated:Connect(function()
		if menu.Visible and currentTab == name then
			menu.Visible = false
		else
			openMenu(name)
		end
	end)
end

local refreshQueued = false
player.AttributeChanged:Connect(function()
	updateHud()
	if menu.Visible and not refreshQueued then
		refreshQueued = true
		task.delay(0.15, function()
			refreshQueued = false
			refreshMenu()
		end)
	end
end)
updateHud()

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
local followers = {} -- [Player] = { Raw = string, Models = { Model } }

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
			Size = Vector3.new(0.3, 0.3, 0.3),
			Color = Color3.fromRGB(20, 20, 20),
			CFrame = body.CFrame * CFrame.new(side * eyeOffsetX, def.Size.Y * 0.15, -def.Size.Z / 2),
		})
	end
	part({
		Name = "Fin",
		Size = Vector3.new(0.3, def.Size.Y * 0.5, def.Size.Z * 0.5),
		Color = def.Accent,
		CFrame = body.CFrame * CFrame.new(0, def.Size.Y / 2 + def.Size.Y * 0.2, 0),
	})

	if def.Rarity == "Legendary" then
		part({
			Name = "Glow",
			Size = def.Size * 1.15,
			Color = Config.RarityColors.Legendary,
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
				local target = CFrame.new(root.Position + offset) * root.CFrame.Rotation

				local current = model:GetPivot()
				if state.JustBuilt then
					model:PivotTo(target)
				else
					model:PivotTo(current:Lerp(target, alpha))
				end
			end
			state.JustBuilt = false
		end
	end
end)
