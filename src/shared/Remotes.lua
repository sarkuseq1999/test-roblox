-- Centralized RemoteEvent / RemoteFunction registry.
-- Server creates instances on require; client just looks them up.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FOLDER_NAME = "DragonsRemotes"

local EVENTS = {
	"PlayerAttack",
	"DataUpdated",
	"InventoryUpdated",
	"NotifyPlayer",
	"UseItem",
	"PartyInvite",
	"PartyRespond",
	"PartyLeave",
	"PartyUpdated",
	"RaidConvert",
	"BossPhase",
	"DamageNumber",
}

local FUNCTIONS = {
	"GetMyData",
	"GetParty",
}

local Remotes = {}

local folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
	for _, name in ipairs(EVENTS) do
		if not folder:FindFirstChild(name) then
			local r = Instance.new("RemoteEvent")
			r.Name = name
			r.Parent = folder
		end
	end
	for _, name in ipairs(FUNCTIONS) do
		if not folder:FindFirstChild(name) then
			local r = Instance.new("RemoteFunction")
			r.Name = name
			r.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

function Remotes.Event(name)
	return folder:WaitForChild(name)
end

function Remotes.Function(name)
	return folder:WaitForChild(name)
end

return Remotes
