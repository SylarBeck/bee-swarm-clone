-- Builds the ocean map: seabed, zones, coral nodes, decorations, Dive Station, Reef Shop, Captain Finn.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local World = {}

World.Nodes = {} -- array of node tables
World.CashInPrompt = nil
World.ShopPrompt = nil
World.QuestPrompt = nil

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

-- Vertical cylinder helper (Cylinder axis is X, so rotate onto Y).
local function makePillar(props, parent)
	local height, diameter = props.Height, props.Diameter
	local part = makePart({
		Name = props.Name or "Pillar",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(props.Position) * CFrame.Angles(0, 0, math.pi / 2),
		Color = props.Color,
		Material = props.Material,
		CanCollide = props.CanCollide,
	}, parent)
	return part
end

local function addSign(adornee, text, color, offset)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(240, 60)
	gui.StudsOffset = Vector3.new(0, offset or 6, 0)
	gui.MaxDistance = 140
	gui.Adornee = adornee
	gui.Parent = adornee

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 34
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
end

local function addBubbles(parent, position, spread, rate)
	local emitterPart = makePart({
		Name = "Bubbles",
		Size = Vector3.new(spread, 1, spread),
		Position = position,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	}, parent)

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Rate = rate or 5
	emitter.Lifetime = NumberRange.new(7, 10)
	emitter.Speed = NumberRange.new(3, 6)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.SpreadAngle = Vector2.new(12, 12)
	emitter.Size = NumberSequence.new(0.5, 1.2)
	emitter.Transparency = NumberSequence.new(0.3, 1)
	emitter.LightEmission = 0.7
	emitter.Color = ColorSequence.new(Color3.fromRGB(200, 240, 255))
	emitter.Parent = emitterPart
end

local function buildLighting()
	Lighting.ClockTime = 13
	Lighting.Brightness = 2.5
	Lighting.Ambient = Color3.fromRGB(70, 110, 140)
	Lighting.OutdoorAmbient = Color3.fromRGB(80, 130, 160)
	Lighting.FogColor = Color3.fromRGB(35, 120, 165)
	Lighting.FogStart = 70
	Lighting.FogEnd = 700

	local function effect(class, props)
		local inst = Instance.new(class)
		for k, v in props do
			inst[k] = v
		end
		inst.Parent = Lighting
	end

	effect("Atmosphere", { Color = Color3.fromRGB(80, 170, 200), Density = 0.35, Haze = 1.5 })
	effect("ColorCorrectionEffect", { TintColor = Color3.fromRGB(190, 235, 255), Saturation = 0.2, Contrast = 0.05 })
	effect("BloomEffect", { Intensity = 0.5, Size = 28, Threshold = 1.1 })
	effect("SunRaysEffect", { Intensity = 0.15, Spread = 0.8 })
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

	-- Water surface "ceiling"
	makePart({
		Name = "Surface",
		Size = Vector3.new(MAP_SIZE, 1, MAP_SIZE),
		Position = Vector3.new(0, 190, 0),
		Color = Color3.fromRGB(120, 210, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.6,
		CanCollide = false,
		CanQuery = false,
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

	-- Hub plaza: two stacked discs
	makePillar({
		Name = "HubRim",
		Height = 0.5,
		Diameter = 96,
		Position = Vector3.new(0, 0.25, 0),
		Color = Color3.fromRGB(90, 150, 170),
		Material = Enum.Material.Slate,
	}, map)
	makePillar({
		Name = "HubPlaza",
		Height = 0.6,
		Diameter = 88,
		Position = Vector3.new(0, 0.3, 0),
		Color = Color3.fromRGB(235, 215, 165),
		Material = Enum.Material.Cobblestone,
	}, map)

	for _, zone in Config.Zones do
		makePillar({
			Name = zone.Id .. "Rim",
			Height = 0.4,
			Diameter = zone.Radius * 2 + 6,
			Position = Vector3.new(zone.Center.X, 0.2, zone.Center.Z),
			Color = zone.GroundColor:Lerp(Color3.new(0, 0, 0), 0.35),
		}, map)
		makePillar({
			Name = zone.Id .. "Ground",
			Height = 0.5,
			Diameter = zone.Radius * 2,
			Position = Vector3.new(zone.Center.X, 0.25, zone.Center.Z),
			Color = zone.GroundColor,
			Material = Enum.Material.Sand,
		}, map)
	end

	-- Walkways from the hub to each zone
	for _, zone in Config.Zones do
		local from = Vector3.new(0, 0.15, 0)
		local to = Vector3.new(zone.Center.X, 0.15, zone.Center.Z)
		local length = (to - from).Magnitude - 44 - zone.Radius
		local mid = from + (to - from).Unit * (44 + length / 2)
		makePart({
			Name = zone.Id .. "Path",
			Size = Vector3.new(12, 0.3, length),
			CFrame = CFrame.lookAt(mid, to),
			Color = Color3.fromRGB(215, 195, 150),
			Material = Enum.Material.Cobblestone,
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

	local trim = color:Lerp(Color3.new(1, 1, 1), 0.5)
	makePart({ Name = "Floor", Size = Vector3.new(18, 1, 14), Position = center + Vector3.new(0, 0.9, 0), Color = Color3.fromRGB(110, 90, 70), Material = Enum.Material.WoodPlanks }, model)
	makePart({ Name = "Roof", Size = Vector3.new(20, 1, 16), Position = center + Vector3.new(0, 11.5, 0), Color = color }, model)
	makePart({ Name = "RoofTrim", Size = Vector3.new(20.4, 0.5, 16.4), Position = center + Vector3.new(0, 12.2, 0), Color = trim, Material = Enum.Material.Neon }, model)
	for _, x in { -8, 8 } do
		for _, z in { -5, 5 } do
			makePart({ Name = "Pillar", Size = Vector3.new(1.5, 10, 1.5), Position = center + Vector3.new(x, 6, z), Color = Color3.fromRGB(240, 235, 220) }, model)
		end
	end
	local counter = makePart({
		Name = "Counter",
		Size = Vector3.new(13, 4, 3),
		Position = center + Vector3.new(0, 3, 0),
		Color = color,
	}, model)
	makePart({ Name = "CounterTop", Size = Vector3.new(14, 0.6, 4), Position = center + Vector3.new(0, 5.2, 0), Color = trim }, model)

	addSign(counter, signText, Color3.fromRGB(255, 255, 255), 8)

	local proximity = Instance.new("ProximityPrompt")
	proximity.ActionText = prompt.Action
	proximity.ObjectText = prompt.Object
	proximity.HoldDuration = prompt.Hold
	proximity.MaxActivationDistance = 14
	proximity.RequiresLineOfSight = false
	proximity.Parent = counter
	return proximity
end

local function buildNpc(map, center)
	local model = Instance.new("Model")
	model.Name = "CaptainFinn"
	model.Parent = map

	local skin = Color3.fromRGB(240, 190, 150)
	local coat = Color3.fromRGB(30, 80, 160)
	local function part(name, size, offset, color, material)
		return makePart({
			Name = name,
			Size = size,
			Position = center + offset,
			Color = color,
			Material = material or Enum.Material.SmoothPlastic,
		}, model)
	end

	part("LegL", Vector3.new(1.3, 3, 1.3), Vector3.new(-0.8, 1.5, 0), Color3.fromRGB(40, 40, 60))
	part("LegR", Vector3.new(1.3, 3, 1.3), Vector3.new(0.8, 1.5, 0), Color3.fromRGB(40, 40, 60))
	local torso = part("Torso", Vector3.new(3.4, 3.6, 1.9), Vector3.new(0, 4.8, 0), coat)
	part("Belt", Vector3.new(3.5, 0.5, 2), Vector3.new(0, 3.4, 0), Color3.fromRGB(255, 200, 60), Enum.Material.Neon)
	part("ArmL", Vector3.new(1, 3, 1), Vector3.new(-2.3, 4.8, 0), coat)
	part("ArmR", Vector3.new(1, 3, 1), Vector3.new(2.3, 4.8, 0), coat)
	part("Head", Vector3.new(2, 2, 2), Vector3.new(0, 7.6, 0), skin)
	part("Beard", Vector3.new(1.8, 0.9, 0.4), Vector3.new(0, 6.9, 1.1), Color3.fromRGB(240, 240, 240))
	part("EyeL", Vector3.new(0.3, 0.3, 0.2), Vector3.new(-0.5, 7.9, 1.05), Color3.fromRGB(20, 20, 20))
	part("EyeR", Vector3.new(0.3, 0.3, 0.2), Vector3.new(0.5, 7.9, 1.05), Color3.fromRGB(20, 20, 20))
	part("HatBrim", Vector3.new(2.8, 0.5, 2.8), Vector3.new(0, 8.8, 0), Color3.fromRGB(245, 245, 245))
	part("Hat", Vector3.new(2, 1.2, 2), Vector3.new(0, 9.6, 0), Color3.fromRGB(30, 80, 160))
	part("HatBadge", Vector3.new(0.8, 0.5, 0.2), Vector3.new(0, 9.5, 1.05), Color3.fromRGB(255, 200, 60), Enum.Material.Neon)

	addSign(torso, "Captain Finn", Color3.fromRGB(255, 220, 120), 7.5)

	local proximity = Instance.new("ProximityPrompt")
	proximity.ActionText = "Talk"
	proximity.ObjectText = "Captain Finn (Quests)"
	proximity.HoldDuration = 0
	proximity.MaxActivationDistance = 14
	proximity.RequiresLineOfSight = false
	proximity.Parent = torso
	return proximity
end

local function buildHubDecor(map)
	local decor = Instance.new("Folder")
	decor.Name = "HubDecor"
	decor.Parent = map

	-- Lantern posts ringing the plaza
	for i = 1, 10 do
		local angle = (i / 10) * math.pi * 2 + 0.15
		local pos = Vector3.new(math.cos(angle) * 40, 0, math.sin(angle) * 40)
		makePillar({
			Name = "LanternPost",
			Height = 12,
			Diameter = 1.2,
			Position = pos + Vector3.new(0, 6, 0),
			Color = Color3.fromRGB(70, 90, 110),
			Material = Enum.Material.Metal,
		}, decor)
		local lamp = makePart({
			Name = "Lamp",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(3, 3, 3),
			Position = pos + Vector3.new(0, 13, 0),
			Color = Color3.fromRGB(255, 240, 170),
			Material = Enum.Material.Neon,
			CanCollide = false,
		}, decor)
		local light = Instance.new("PointLight")
		light.Range = 26
		light.Brightness = 1.2
		light.Color = Color3.fromRGB(255, 235, 170)
		light.Parent = lamp
	end

	-- Entrance arch near spawn
	local archZ = 44
	for _, x in { -13, 13 } do
		makePart({ Name = "ArchPillar", Size = Vector3.new(4, 24, 4), Position = Vector3.new(x, 12, archZ), Color = Color3.fromRGB(110, 150, 170), Material = Enum.Material.Slate }, decor)
	end
	makePart({ Name = "ArchBeam", Size = Vector3.new(34, 4, 4), Position = Vector3.new(0, 26, archZ), Color = Color3.fromRGB(110, 150, 170), Material = Enum.Material.Slate }, decor)
	local archGlow = makePart({ Name = "ArchGlow", Size = Vector3.new(34, 0.6, 4.4), Position = Vector3.new(0, 23.9, archZ), Color = Color3.fromRGB(0, 230, 240), Material = Enum.Material.Neon }, decor)
	addSign(archGlow, "REEF RUSH", Color3.fromRGB(120, 240, 255), 6)

	-- Central coral fountain
	local center = Vector3.new(0, 0, 18)
	makePillar({ Name = "FountainBase", Height = 2, Diameter = 14, Position = center + Vector3.new(0, 1, 0), Color = Color3.fromRGB(120, 150, 170), Material = Enum.Material.Slate }, decor)
	makePillar({ Name = "FountainWater", Height = 0.4, Diameter = 11, Position = center + Vector3.new(0, 2.1, 0), Color = Color3.fromRGB(90, 220, 255), Material = Enum.Material.Neon }, decor)
	local colors = { Color3.fromRGB(255, 120, 150), Color3.fromRGB(255, 190, 90), Color3.fromRGB(190, 110, 255) }
	for i, color in colors do
		local h = 6 + i * 2
		local angle = i * 2.1
		makePillar({
			Name = "FountainCoral",
			Height = h,
			Diameter = 1.6,
			Position = center + Vector3.new(math.cos(angle) * 2, 2 + h / 2, math.sin(angle) * 2),
			Color = color,
			Material = Enum.Material.Neon,
		}, decor)
	end
	addBubbles(decor, center + Vector3.new(0, 4, 0), 4, 14)
	addBubbles(decor, Vector3.new(-18, 1, -8), 10, 6)
	addBubbles(decor, Vector3.new(18, 1, -8), 10, 6)
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

			local roll = rng:NextNumber()
			if roll < 0.6 then
				local height = rng:NextNumber(8, 22)
				makePillar({
					Name = "Seaweed",
					Height = height,
					Diameter = rng:NextNumber(0.8, 1.4),
					Position = pos + Vector3.new(0, height / 2, 0),
					Color = Color3.fromRGB(40, rng:NextInteger(140, 210), rng:NextInteger(70, 120)),
					Material = Enum.Material.Grass,
					CanCollide = false,
				}, decor)
			elseif roll < 0.85 then
				local size = rng:NextNumber(3, 8)
				makePart({
					Name = "Rock",
					Size = Vector3.new(size, size * 0.7, size * 1.2),
					CFrame = CFrame.new(pos + Vector3.new(0, size * 0.25, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0),
					Color = Color3.fromRGB(105, 118, 130),
					Material = Enum.Material.Slate,
				}, decor)
			else
				local size = rng:NextNumber(3, 5)
				makePart({
					Name = "Clam",
					Shape = Enum.PartType.Ball,
					Size = Vector3.new(size, size * 0.6, size),
					Position = pos + Vector3.new(0, size * 0.25, 0),
					Color = Color3.fromRGB(245, 215, 225),
					Material = Enum.Material.Marble,
				}, decor)
			end
		end
	end

	scatter(Vector3.zero, 430, 120, 70)
	for _, zone in Config.Zones do
		scatter(zone.Center, zone.Radius + 14, 45, zone.Radius * 0.88)
		for i = 1, 4 do
			local angle = rng:NextNumber(0, math.pi * 2)
			local pos = zone.Center + Vector3.new(math.cos(angle) * zone.Radius * 0.5, 0, math.sin(angle) * zone.Radius * 0.5)
			addBubbles(decor, pos + Vector3.new(0, 1, 0), 8, 4)
		end
		local signPart = makePart({
			Name = zone.Id .. "Sign",
			Size = Vector3.new(4, 4, 4),
			Position = zone.Center + Vector3.new(0, 14, 0),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
		}, decor)
		addSign(signPart, zone.Name, zone.CoralColors[1], 0)
	end
end

----------------------------------------------------------------------------
-- Coral nodes
----------------------------------------------------------------------------
local function shade(color, amount)
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

-- Builds a coral cluster at the origin with its pivot at the base; returns model, main color.
local function buildCoralModel(zone, color)
	local model = Instance.new("Model")
	model.Name = "Coral_" .. zone.Id

	local function part(props)
		props.Anchored = true
		props.CanCollide = false
		props.TopSurface = Enum.SurfaceType.Smooth
		props.BottomSurface = Enum.SurfaceType.Smooth
		props.Material = props.Material or Enum.Material.Neon
		return makePart(props, model)
	end

	local base = part({
		Name = "Base",
		Size = Vector3.new(6.5, 1, 6.5),
		Position = Vector3.new(0, 0.5, 0),
		Color = Color3.fromRGB(95, 95, 110),
		Material = Enum.Material.Slate,
	})
	model.PrimaryPart = base

	local style = rng:NextInteger(1, 3)
	if style == 1 then
		-- Tube coral
		for i = 1, rng:NextInteger(3, 5) do
			local height = rng:NextNumber(3, 7)
			local angle = (i / 5) * math.pi * 2
			local radius = rng:NextNumber(0.6, 1.8)
			local c = color:Lerp(Color3.new(1, 1, 1), rng:NextNumber(0, 0.25))
			local tube = part({
				Name = "Tube",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(height, rng:NextNumber(1, 1.7), rng:NextNumber(1, 1.7)),
				CFrame = CFrame.new(math.cos(angle) * radius, 1 + height / 2, math.sin(angle) * radius) * CFrame.Angles(0, 0, math.pi / 2),
				Color = c,
			})
			part({
				Name = "TubeMouth",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.3, tube.Size.Y * 0.7, tube.Size.Z * 0.7),
				CFrame = tube.CFrame * CFrame.new(height / 2 + 0.05, 0, 0),
				Color = shade(c, 0.5),
			})
		end
	elseif style == 2 then
		-- Fan coral
		for i = 1, 3 do
			local width = rng:NextNumber(3, 5)
			local height = rng:NextNumber(3.5, 6)
			part({
				Name = "Fan",
				Size = Vector3.new(width, height, 0.5),
				CFrame = CFrame.new(0, 1 + height / 2, 0) * CFrame.Angles(0, (i - 1) * math.pi / 3, rng:NextNumber(-0.2, 0.2)),
				Color = color:Lerp(Color3.new(1, 1, 1), 0.1 * i),
			})
		end
	else
		-- Brain coral
		local size = rng:NextNumber(4, 5.5)
		part({ Name = "Brain", Shape = Enum.PartType.Ball, Size = Vector3.new(size, size * 0.8, size), Position = Vector3.new(0, 1 + size * 0.35, 0), Color = color })
		part({ Name = "BrainLump", Shape = Enum.PartType.Ball, Size = Vector3.new(2.4, 2.2, 2.4), Position = Vector3.new(1.8, 1.8, -1.2), Color = color:Lerp(Color3.new(1, 1, 1), 0.2) })
		part({ Name = "BrainLump", Shape = Enum.PartType.Ball, Size = Vector3.new(1.8, 1.6, 1.8), Position = Vector3.new(-1.7, 1.5, 1.4), Color = shade(color, 0.15) })
	end

	return model
end

local function applyNodeVisual(node)
	local frac = node.Shells / node.Max
	local scale = 0.2 + 0.8 * frac
	if math.abs(scale - node.AppliedScale) < 0.03 and frac > 0 and frac < 1 then
		return
	end
	node.AppliedScale = scale
	node.Model:ScaleTo(scale)
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
				if (other - pos).Magnitude < 10 then
					clear = false
					break
				end
			end

			if clear then
				table.insert(placed, pos)
				local color = zone.CoralColors[rng:NextInteger(1, #zone.CoralColors)]
				local model = buildCoralModel(zone, color)
				model:PivotTo(CFrame.new(pos.X, 0.5, pos.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
				model.Parent = folder

				table.insert(World.Nodes, {
					Model = model,
					Color = color,
					Zone = zone.Id,
					Position = pos + Vector3.new(0, 2, 0),
					Max = zone.NodeShells,
					Shells = zone.NodeShells,
					RegenPerSecond = zone.NodeShells / zone.RegenSeconds,
					AppliedScale = 1,
					Dirty = false,
				})
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
	buildHubDecor(map)

	World.CashInPrompt = buildBuilding(map, "DiveStation", Vector3.new(-20, 0, -8), Color3.fromRGB(240, 140, 40), "Dive Station", {
		Action = "Cash In Shells",
		Object = "Dive Station",
		Hold = 0.25,
	})
	World.ShopPrompt = buildBuilding(map, "ReefShop", Vector3.new(20, 0, -8), Color3.fromRGB(60, 170, 220), "Reef Shop", {
		Action = "Open Shop",
		Object = "Reef Shop",
		Hold = 0,
	})
	World.QuestPrompt = buildNpc(map, Vector3.new(0, 0, -24))
end

return World
