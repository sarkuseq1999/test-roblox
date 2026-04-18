-- Validates and processes player melee attacks. Clients send a target model;
-- server confirms range and cooldown, then routes damage through MonsterService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local function waitForGlobal(name)
	while not _G[name] do task.wait() end
	return _G[name]
end

local PlayerDataService = waitForGlobal("PlayerDataService")
local MonsterService = waitForGlobal("MonsterService")

local ATTACK_COOLDOWN = 1.2
local ATTACK_RANGE = 12

local lastAttack = {}

Remotes.Event("PlayerAttack").OnServerEvent:Connect(function(player, targetModel)
	if typeof(targetModel) ~= "Instance" or not targetModel:IsA("Model") then return end
	local now = os.clock()
	if (lastAttack[player] or 0) + ATTACK_COOLDOWN > now then return end
	lastAttack[player] = now

	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local root = targetModel.PrimaryPart
	if not hrp or not root then return end
	if (hrp.Position - root.Position).Magnitude > ATTACK_RANGE then return end

	local stats = PlayerDataService.GetEffectiveStats(player)
	if not stats then return end
	MonsterService.ApplyDamage(targetModel, player, stats.Damage + (stats.Strength or 0) * 0.5)
end)

game:GetService("Players").PlayerRemoving:Connect(function(p)
	lastAttack[p] = nil
end)
