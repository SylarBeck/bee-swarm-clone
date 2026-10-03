-- Quest progression from Captain Finn. Rewards are paid automatically.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Data = require(script.Parent.Data)
local Remotes = require(script.Parent.Remotes)

local Quests = {}

local function advance(player, data)
	local quest = Config.GetQuest(data.QuestIndex)
	data.Coins += quest.Reward
	data.QuestIndex += 1
	data.QuestProgress = 0
	Remotes.Notify(player, ("Quest complete! +%s coins"):format(Config.Commas(quest.Reward)), "success")
end

-- Completes any quest whose condition is already met (progress full or zone owned).
function Quests.Check(player)
	local data = Data.Get(player)
	if not data then
		return
	end
	while true do
		local quest = Config.GetQuest(data.QuestIndex)
		if quest.Type == "HaveZone" and data.Zones[quest.Zone] then
			advance(player, data)
		elseif data.QuestProgress >= quest.Goal then
			advance(player, data)
		else
			break
		end
	end
end

-- Adds progress if the active quest matches. Callers are responsible for Data.Sync.
function Quests.Report(player, kind, amount)
	local data = Data.Get(player)
	if not data then
		return
	end
	local quest = Config.GetQuest(data.QuestIndex)
	if quest.Type ~= kind then
		return
	end
	data.QuestProgress = math.min(quest.Goal, data.QuestProgress + amount)
	Quests.Check(player)
end

return Quests
