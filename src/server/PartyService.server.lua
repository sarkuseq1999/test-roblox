-- Party (1-6) and Raid (up to 24, made of up-to-4 parties).
-- Used for grouped XP/loot distribution and raid-only zone access.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local MAX_PARTY = 6
local MAX_RAID_PARTIES = 4

local PartyService = {}

local parties = {}        -- partyId -> { id, leader, members={} }
local playerParty = {}    -- player -> partyId
local pendingInvites = {} -- invitee -> { fromPartyId, expires }
local nextPartyId = 1

local raids = {}        -- raidId -> { id, leader, partyIds = {} }
local partyRaid = {}    -- partyId -> raidId
local nextRaidId = 1

local function notify(player, msg)
	Remotes.Event("NotifyPlayer"):FireClient(player, msg)
end

local function broadcastParty(partyId)
	local party = parties[partyId]
	if not party then return end
	local snapshot = { id = party.id, leader = party.leader.Name, members = {} }
	for _, p in ipairs(party.members) do
		local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		table.insert(snapshot.members, {
			name = p.Name,
			hp = hum and hum.Health or 0,
			maxHp = hum and hum.MaxHealth or 0,
		})
	end
	snapshot.raidId = partyRaid[partyId]
	for _, p in ipairs(party.members) do
		Remotes.Event("PartyUpdated"):FireClient(p, snapshot)
	end
end

function PartyService.GetPartyOf(player)
	local pid = playerParty[player]
	return pid and parties[pid]
end

local function createParty(leader)
	local pid = nextPartyId
	nextPartyId = nextPartyId + 1
	parties[pid] = { id = pid, leader = leader, members = { leader } }
	playerParty[leader] = pid
	return parties[pid]
end

local function removeFromParty(player)
	local pid = playerParty[player]
	if not pid then return end
	local party = parties[pid]
	playerParty[player] = nil
	for i, p in ipairs(party.members) do
		if p == player then
			table.remove(party.members, i)
			break
		end
	end
	if #party.members == 0 then
		-- if party belonged to a raid, remove from raid
		local rid = partyRaid[pid]
		if rid then
			local raid = raids[rid]
			for i, p2 in ipairs(raid.partyIds) do
				if p2 == pid then table.remove(raid.partyIds, i) break end
			end
			partyRaid[pid] = nil
			if #raid.partyIds == 0 then raids[rid] = nil end
		end
		parties[pid] = nil
	else
		if party.leader == player then
			party.leader = party.members[1]
		end
		broadcastParty(pid)
	end
	Remotes.Event("PartyUpdated"):FireClient(player, { id = nil, members = {} })
end

Remotes.Event("PartyInvite").OnServerEvent:Connect(function(player, targetName)
	local target = Players:FindFirstChild(targetName)
	if not target or target == player then return end
	if playerParty[target] then notify(player, target.Name .. " is already in a party.") return end

	local party = parties[playerParty[player]] or createParty(player)
	if party.leader ~= player then notify(player, "Only the party leader can invite.") return end
	if #party.members >= MAX_PARTY then notify(player, "Party is full.") return end

	pendingInvites[target] = { fromPartyId = party.id, expires = os.clock() + 30 }
	Remotes.Event("PartyInvite"):FireClient(target, { from = player.Name, partyId = party.id })
	notify(player, "Invited " .. target.Name)
end)

Remotes.Event("PartyRespond").OnServerEvent:Connect(function(player, accept)
	local invite = pendingInvites[player]
	if not invite or os.clock() > invite.expires then
		pendingInvites[player] = nil
		return
	end
	pendingInvites[player] = nil
	if not accept then return end
	local party = parties[invite.fromPartyId]
	if not party or #party.members >= MAX_PARTY then
		notify(player, "Party no longer available.")
		return
	end
	if playerParty[player] then removeFromParty(player) end
	table.insert(party.members, player)
	playerParty[player] = party.id
	broadcastParty(party.id)
end)

Remotes.Event("PartyLeave").OnServerEvent:Connect(function(player)
	removeFromParty(player)
end)

Remotes.Event("RaidConvert").OnServerEvent:Connect(function(player)
	local pid = playerParty[player]
	local party = pid and parties[pid]
	if not party or party.leader ~= player then
		notify(player, "Only a party leader can form a raid.")
		return
	end
	if partyRaid[pid] then return end
	local rid = nextRaidId
	nextRaidId = nextRaidId + 1
	raids[rid] = { id = rid, leader = player, partyIds = { pid } }
	partyRaid[pid] = rid
	notify(player, "Raid formed. Other party leaders can join with /joinraid " .. rid)
	broadcastParty(pid)
end)

-- Chat command handler for /joinraid <id>.
Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(msg)
		local raidId = msg:match("^/joinraid%s+(%d+)$")
		if raidId then
			raidId = tonumber(raidId)
			local pid = playerParty[player]
			local party = pid and parties[pid]
			if not party or party.leader ~= player then
				notify(player, "Must be a party leader.")
				return
			end
			local raid = raids[raidId]
			if not raid then notify(player, "No such raid.") return end
			if #raid.partyIds >= MAX_RAID_PARTIES then notify(player, "Raid is full.") return end
			if partyRaid[pid] then notify(player, "Already in a raid.") return end
			table.insert(raid.partyIds, pid)
			partyRaid[pid] = raidId
			for _, otherPid in ipairs(raid.partyIds) do broadcastParty(otherPid) end
			notify(player, "Joined raid " .. raidId)
		end
	end)
end)

function PartyService.GetRaidOf(player)
	local pid = playerParty[player]
	if not pid then return nil end
	local rid = partyRaid[pid]
	if not rid then return nil end
	local raid = raids[rid]
	local players = {}
	for _, p2 in ipairs(raid.partyIds) do
		for _, member in ipairs(parties[p2].members) do
			table.insert(players, member)
		end
	end
	return raid, players
end

Remotes.Function("GetParty").OnServerInvoke = function(player)
	local party = PartyService.GetPartyOf(player)
	if not party then return nil end
	local out = { id = party.id, leader = party.leader.Name, members = {}, raidId = partyRaid[party.id] }
	for _, p in ipairs(party.members) do
		table.insert(out.members, p.Name)
	end
	return out
end

Players.PlayerRemoving:Connect(function(player)
	pendingInvites[player] = nil
	if playerParty[player] then removeFromParty(player) end
end)

_G.PartyService = PartyService
return PartyService
