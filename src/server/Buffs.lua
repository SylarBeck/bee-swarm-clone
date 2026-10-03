-- Floating buff bubbles and per-player timed buffs.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Data = require(script.Parent.Data)
local Remotes = require(script.Parent.Remotes)
local Quests = require(script.Parent.Quests)

local Buffs = {}
Buffs.OnChanged = nil -- set by Game: called when a player's buffs change

local active = {} -- [player] = { [buffId] = expiry (server time) }
local tokens = {} -- { Part, Id, Expires }
local rng = Random.new()
local folder

function Buffs.IsActive(player, id)
	local expiry = active[player] and active[player][id]
	return expiry ~= nil and expiry > Workspace:GetServerTimeNow()
end

function Buffs.Grant(player, id)
	local def = Config.Buffs[id]
	local data = Data.Get(player)
	if not def or not data then
		return
	end

	if id == "Burst" then
		local coins = math.floor(Config.UpgradeValue("Capacity", data.Levels.Capacity) * 0.5 * Config.CoinMultiplier(data.Pearls))
		data.Coins += coins
		Remotes.Notify(player, ("Pearl Burst! +%s coins"):format(Config.Commas(coins)), "success")
	else
		local expiry = Workspace:GetServerTimeNow() + def.Duration
		active[player] = active[player] or {}
		active[player][id] = expiry
		player:SetAttribute("Buff_" .. id, expiry)
		Remotes.Notify(player, ("%s active for %ds!"):format(def.Name, def.Duration), "success")
		task.delay(def.Duration + 0.2, function()
			if Buffs.OnChanged and player.Parent then
				Buffs.OnChanged(player)
			end
		end)
	end

	if Buffs.OnChanged then
		Buffs.OnChanged(player)
	end
end

local function removeToken(index)
	local token = table.remove(tokens, index)
	if token then
		token.Part:Destroy()
	end
end

local function spawnToken()
	local zone = Config.Zones[rng:NextInteger(1, #Config.Zones)]
	local id = Config.BuffOrder[rng:NextInteger(1, #Config.BuffOrder)]
	local def = Config.Buffs[id]

	local angle = rng:NextNumber(0, math.pi * 2)
	local dist = math.sqrt(rng:NextNumber()) * (zone.Radius - 6)
	local position = zone.Center + Vector3.new(math.cos(angle) * dist, 5, math.sin(angle) * dist)

	local part = Instance.new("Part")
	part.Name = "BuffBubble"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(4, 4, 4)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Neon
	part.Color = def.Color
	part.Transparency = 0.25
	part.Position = position

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 40)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.MaxDistance = 200
	gui.Adornee = part
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = def.Label
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 26
	label.TextColor3 = def.Color
	label.TextStrokeTransparency = 0.2
	label.Parent = gui

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Rate = 8
	sparkles.Lifetime = NumberRange.new(1, 2)
	sparkles.Speed = NumberRange.new(1, 3)
	sparkles.Size = NumberSequence.new(0.6, 0)
	sparkles.LightEmission = 1
	sparkles.Color = ColorSequence.new(def.Color)
	sparkles.Parent = part

	part.Parent = folder

	TweenService:Create(part, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Position = position + Vector3.new(0, 2.5, 0),
	}):Play()

	table.insert(tokens, { Part = part, Id = id, Expires = os.clock() + Config.Tokens.Lifetime })
end

-- Called each collect tick for a player standing at `position`.
function Buffs.TryPickup(player, position)
	for i = #tokens, 1, -1 do
		local token = tokens[i]
		if (token.Part.Position - position).Magnitude <= Config.Tokens.PickupRange then
			local id = token.Id
			removeToken(i)
			Buffs.Grant(player, id)
			Quests.Report(player, "Bubble", 1)
		end
	end
end

function Buffs.Forget(player)
	active[player] = nil
end

function Buffs.Start()
	folder = Instance.new("Folder")
	folder.Name = "BuffBubbles"
	folder.Parent = Workspace

	task.spawn(function()
		while true do
			task.wait(Config.Tokens.SpawnInterval)
			for i = #tokens, 1, -1 do
				if os.clock() > tokens[i].Expires then
					removeToken(i)
				end
			end
			if #tokens < Config.Tokens.MaxActive then
				spawnToken()
			end
		end
	end)
end

return Buffs
