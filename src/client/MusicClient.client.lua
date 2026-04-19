-- Ambient Freeport music that fades in when the player is inside the city
-- and out when they leave. Swap the FREEPORT_MUSIC id below for your own
-- uploaded track; this is just a placeholder.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ZoneConfig = require(Shared.Config.ZoneConfig)

local player = Players.LocalPlayer

-- Placeholder medieval/fantasy ambient id. If this id is unavailable in your
-- game, upload an audio asset and paste its rbxassetid here.
local FREEPORT_MUSIC = "rbxassetid://9046862972"
local TARGET_VOLUME = 0.4

local music = Instance.new("Sound")
music.Name = "FreeportMusic"
music.SoundId = FREEPORT_MUSIC
music.Looped = true
music.Volume = 0
music.Parent = SoundService
pcall(function() music:Play() end)

local freeport = ZoneConfig.GetById("freeport")

local function inFreeport(pos)
	if not freeport then return false end
	local c, s = freeport.center, freeport.size
	return math.abs(pos.X - c.X) < s.X / 2
		and math.abs(pos.Z - c.Z) < s.Z / 2
end

RunService.Heartbeat:Connect(function()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local target = inFreeport(hrp.Position) and TARGET_VOLUME or 0
	music.Volume = music.Volume + (target - music.Volume) * 0.04
end)
