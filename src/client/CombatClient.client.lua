-- Click-to-attack: clicking a monster sends an attack to the server.
-- Server is authoritative for range / cooldown / damage.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local function findMonsterAncestor(inst)
	local cur = inst
	while cur and cur ~= workspace do
		if cur:IsA("Model") and cur:GetAttribute("MonsterId") then
			return cur
		end
		cur = cur.Parent
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1
		and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local target = mouse.Target
	local monster = target and findMonsterAncestor(target)
	if monster then
		Remotes.Event("PlayerAttack"):FireServer(monster)
	end
end)
