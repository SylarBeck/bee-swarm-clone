-- Builds the ocean map: seabed, zones, coral nodes, decorations, Dive Station and Reef Shop.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local World = {}

World.Nodes = {} -- array of node tables
World.CashInPrompt = nil
World.ShopPrompt = nil

local MAP_SIZE = 900
local rng = Random.new(1337)

local function makePart(props, parent)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		part[k] = v
	end
	part.Parent = parent
	return part
end

local function addSign(adornee, text, color)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 60)
	gui.StudsOffset = Vector3.new(0, 6, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 120
	gui.Adornee = adornee
	gui.Parent = adornee

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 32
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
end

local function buildLighting()
	Lighting.ClockTime = 13
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(70, 110, 140)
	Lighting.OutdoorAmbient = Color3.fromRGB(80, 130, 160)
	Lighting.FogColor = Color3.fromRGB(35, 120, 165)
	Lighting.FogStart = 60
	Lighting.FogEnd = 650

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Color = Color3.fromRGB(80, 170, 200)
	atmosphere.Density = 0.35
	atmosphere.Haze = 1.5
	atmosphere.Parent = Lighting

	local tint = Instance.new("ColorCorrectionEffect")
	tint.TintColor = Color3.fromRGB(190, 235, 255)
	tint.Saturation = 0.15
	tint.Parent = Lighting
end

local function buildTerrain(map)
	local old = Workspace:FindFirstChild("Baseplate")
	if old then
		old:Destroy()
	end

	makePart({
		Name = "Seabed",
		Size = Vector3.new(MAP_SIZE, 4, MAP_SIZE),
		Position = Vector3.new(0, -2, 0),
		Color = Color3.fromRGB(194, 178, 128),
		Material = Enum.Material.Sand,
	}, map)

	-- Invisible boundary walls
	local half = MAP_SIZE / 2
	local walls = {
		{ Vector3.new(0, 100, half), Vector3.new(MAP_SIZE, 200, 2) },
		{ Vector3.new(0, 100, -half), Vector3.new(MAP_SIZE, 200, 2) },
		{ Vector3.new(half, 100, 0), Vector3.new(2, 200, MAP_SIZE) },
		{ Vector3.new(-half, 100, 0), Vector3.new(2, 200, MAP_SIZE) },
	}
	for _, wall in walls do
		makePart({ Name = "Wall", Position = wall[1], Size = wall[2], Transparency = 1 }, map)
	end

	-- Hub plaza
	local hub = makePart({
		Name = "HubPlaza",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 90, 90),
		CFrame = CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(230, 205, 150),
	}, map)
	hub.Material = Enum.Material.Cobblestone

	for _, zone in Config.Zones do
		makePart({
			Name = zone.Id .. "Ground",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.4, zone.Radius * 2, zone.Radius * 2),
			CFrame = CFrame.new(zone.Center.X, 0.2, zone.Center.Z) * CFrame.Angles(0, 0, math.pi / 2),
			Color = zone.GroundColor,
		}, map)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "ReefSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.Position = Config.HubSpawn + Vector3.new(0, 0.5, 0)
	spawn.Color = Color3.fromRGB(80, 200, 220)
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.5
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = map
end

local function buildBuilding(map, name, center, color, signText, prompt)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = map

	makePart({ Name = "Floor", Size = Vector3.new(16, 1, 12), Position = center + Vector3.new(0, 0.5, 0), Color = Color3.fromRGB(110, 90, 70) }, model)
	makePart({ Name = "Roof", Size = Vector3.new(18, 1, 14), Position = center + Vector3.new(0, 11, 0), Color = color }, model)
	for _, x in { -7, 7 } do
		makePart({ Name = "Pillar", Size = Vector3.new(1.5, 10, 1.5), Position = center + Vector3.new(x, 5.5, -4), Color = Color3.fromRGB(240, 235, 220) }, model)
	end
	local counter = makePart({
		Name = "Counter",
		Size = Vector3.new(12, 4, 3),
		Position = center + Vector3.new(0, 2.5, 0),
		Color = color,
	}, model)

	addSign(counter, signText, Color3.fromRGB(255, 255, 255))

	local proximity = Instance.new("ProximityPrompt")
	proximity.ActionText = prompt.Action
	proximity.ObjectText = prompt.Object
	proximity.HoldDuration = prompt.Hold
	proximity.MaxActivationDistance = 14
	proximity.RequiresLineOfSight = false
	proximity.Parent = counter
	return proximity
end

local function buildDecor(map)
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = map

	local function scatter(center, radius, count, minRadius)
		for _ = 1, count do
			local angle = rng:NextNumber(0, math.pi * 2)
			local dist = rng:NextNumber(minRadius, radius)
			local pos = center + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)

			if rng:NextNumber() < 0.7 then
				local height = rng:NextNumber(8, 20)
				local sway = makePart({
					Name = "Seaweed",
					Size = Vector3.new(1, height, 1),
					Position = pos + Vector3.new(0, height / 2, 0),
					Color = Color3.fromRGB(40, rng:NextInteger(140, 200), rng:NextInteger(70, 110)),
					CanCollide = false,
				}, decor)
				sway.Material = Enum.Material.Grass
			else
				local size = rng:NextNumber(3, 7)
				local rock = makePart({
					Name = "Rock",
					Size = Vector3.new(size, size * 0.7, size * 1.2),
					CFrame = CFrame.new(pos + Vector3.new(0, size * 0.25, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0),
					Color = Color3.fromRGB(110, 120, 130),
				}, decor)
				rock.Material = Enum.Material.Slate
			end
		end
	end

	scatter(Vector3.zero, 420, 90, 60)
	for _, zone in Config.Zones do
		scatter(zone.Center, zone.Radius + 10, 40, zone.Radius * 0.85)
	end
end

local function applyNodeVisual(node)
	local frac = node.Shells / node.Max
	local scale = 0.25 + 0.75 * frac
	local height = node.BaseSize.Y * scale
	local width = node.BaseSize.X * scale
	node.Part.Size = Vector3.new(width, height, width)
	node.Part.CFrame = CFrame.new(node.Position.X, height / 2, node.Position.Z) * CFrame.Angles(0, node.Yaw, 0)
	node.Part.Transparency = frac <= 0 and 0.5 or 0
end

local function buildNodes(map)
	local folder = Instance.new("Folder")
	folder.Name = "Coral"
	folder.Parent = map

	for _, zone in Config.Zones do
		local placed = {}
		local attempts = 0
		while #placed < zone.NodeCount and attempts < 1000 do
			attempts += 1
			local angle = rng:NextNumber(0, math.pi * 2)
			local dist = math.sqrt(rng:NextNumber()) * (zone.Radius - 8)
			local pos = zone.Center + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)

			local clear = true
			for _, other in placed do
				if (other - pos).Magnitude < 9 then
					clear = false
					break
				end
			end

			if clear then
				table.insert(placed, pos)
				local baseHeight = rng:NextNumber(4, 6)
				local part = makePart({
					Name = "Coral_" .. zone.Id,
					Size = Vector3.new(baseHeight, baseHeight, baseHeight),
					Color = zone.CoralColors[rng:NextInteger(1, #zone.CoralColors)],
					Material = Enum.Material.Neon,
				}, folder)

				local node = {
					Part = part,
					Zone = zone.Id,
					Position = pos,
					Yaw = rng:NextNumber(0, math.pi),
					BaseSize = Vector3.new(baseHeight, baseHeight, baseHeight),
					Max = zone.NodeShells,
					Shells = zone.NodeShells,
					RegenPerSecond = zone.NodeShells / zone.RegenSeconds,
					Dirty = false,
				}
				applyNodeVisual(node)
				table.insert(World.Nodes, node)
			end
		end
	end
end

-- Removes shells from a node; returns the amount actually taken.
function World.Take(node, amount)
	local taken = math.min(amount, node.Shells)
	if taken <= 0 then
		return 0
	end
	node.Shells -= taken
	node.Dirty = true
	return taken
end

-- Applies visual updates for nodes that changed.
function World.Flush()
	for _, node in World.Nodes do
		if node.Dirty then
			node.Dirty = false
			applyNodeVisual(node)
		end
	end
end

-- Regrows nodes; call once per second.
function World.Regen()
	for _, node in World.Nodes do
		if node.Shells < node.Max then
			node.Shells = math.min(node.Max, node.Shells + node.RegenPerSecond)
			node.Dirty = true
		end
	end
end

function World.Build()
	local map = Instance.new("Folder")
	map.Name = "ReefMap"
	map.Parent = Workspace

	buildLighting()
	buildTerrain(map)
	buildNodes(map)
	buildDecor(map)

	World.CashInPrompt = buildBuilding(map, "DiveStation", Vector3.new(-18, 0, -8), Color3.fromRGB(240, 140, 40), "Dive Station", {
		Action = "Cash In Shells",
		Object = "Dive Station",
		Hold = 0.25,
	})
	World.ShopPrompt = buildBuilding(map, "ReefShop", Vector3.new(18, 0, -8), Color3.fromRGB(60, 170, 220), "Reef Shop", {
		Action = "Open Shop",
		Object = "Reef Shop",
		Hold = 0,
	})
end

return World
