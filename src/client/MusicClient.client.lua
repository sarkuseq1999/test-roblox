-- Ambient Freeport music. Fades in when the player is inside the city,
-- out when they leave.
--
-- Setup: add a Sound to SoundService in Studio named "FreeportMusic"
-- (e.g. via the Toolbox → Audio tab → Insert). The script will pick it up.
-- Leaving the script-side SoundId empty means audio privacy can't block it.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ZoneConfig = require(Shared.Config.ZoneConfig)

local player = Players.LocalPlayer
local TARGET_VOLUME = 0.4

local function findOrCreateMusic()
	local existing = SoundService:FindFirstChild("FreeportMusic")
	if existing and existing:IsA("Sound") and existing.SoundId ~= "" then
		existing.Looped = true
		return existing, true
	end
	-- Fallback placeholder: script sets no SoundId, user must add one.
	local s = Instance.new("Sound")
	s.Name = "FreeportMusic"
	s.Looped = true
	s.Volume = 0
	s.Parent = SoundService
	return s, false
end

local music, ready = findOrCreateMusic()
if ready then
	pcall(function() music:Play() end)
end

-- If the sound isn't set up, drop a one-time hint in the corner.
if not ready then
	local pg = player:WaitForChild("PlayerGui")
	local screen = Instance.new("ScreenGui")
	screen.Name = "MusicHint"
	screen.ResetOnSpawn = false
	screen.Parent = pg
	local lbl = Instance.new("TextLabel")
	lbl.AnchorPoint = Vector2.new(1, 1)
	lbl.Position = UDim2.new(1, -16, 1, -60)
	lbl.Size = UDim2.new(0, 340, 0, 44)
	lbl.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
	lbl.BackgroundTransparency = 0.1
	lbl.BorderSizePixel = 0
	lbl.TextWrapped = true
	lbl.Font = Enum.Font.Gotham
	lbl.TextSize = 12
	lbl.TextColor3 = Color3.fromRGB(255, 230, 180)
	lbl.Text = "No music set.  Add a Sound named 'FreeportMusic' to SoundService (Toolbox → Audio)."
	lbl.Parent = screen
	task.delay(15, function() screen:Destroy() end)
end

local freeport = ZoneConfig.GetById("freeport")

local function inFreeport(pos)
	if not freeport then return false end
	local c, s = freeport.center, freeport.size
	return math.abs(pos.X - c.X) < s.X / 2
		and math.abs(pos.Z - c.Z) < s.Z / 2
end

RunService.Heartbeat:Connect(function(dt)
	if not ready then return end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local target = inFreeport(hrp.Position) and TARGET_VOLUME or 0
	music.Volume = music.Volume + (target - music.Volume) * math.min(1, dt * 2)
	if not music.IsPlaying and target > 0 then
		pcall(function() music:Play() end)
	end
end)
