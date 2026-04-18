-- Top-left character panel + scrolling notification feed.
-- Listens for DataUpdated / NotifyPlayer / BossPhase events.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

local screen = Instance.new("ScreenGui")
screen.Name = "HUD"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.Parent = pg

local panel = Instance.new("Frame")
panel.Name = "CharacterPanel"
panel.Size = UDim2.new(0, 260, 0, 130)
panel.Position = UDim2.new(0, 12, 0, 12)
panel.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
panel.BackgroundTransparency = 0.25
panel.BorderSizePixel = 0
panel.Parent = screen

local function makeLabel(name, parent, posY, text, size)
	local lbl = Instance.new("TextLabel")
	lbl.Name = name
	lbl.BackgroundTransparency = 1
	lbl.Position = UDim2.new(0, 10, 0, posY)
	lbl.Size = UDim2.new(1, -20, 0, size or 18)
	lbl.Font = Enum.Font.GothamSemibold
	lbl.TextColor3 = Color3.fromRGB(240, 230, 200)
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextSize = size or 16
	lbl.Text = text
	lbl.Parent = parent
	return lbl
end

local nameLbl = makeLabel("Name", panel, 6, player.Name, 18)
local raceLbl = makeLabel("Race", panel, 26, "Human  •  Lvl 1", 14)
local hpLbl = makeLabel("HP", panel, 50, "HP: ?/?", 14)
local mpLbl = makeLabel("MP", panel, 70, "MP: ?/?", 14)
local xpLbl = makeLabel("XP", panel, 92, "XP: 0/0", 14)
local goldLbl = makeLabel("Gold", panel, 110, "Gold: 0", 14)

local function makeBar(parent, posY, color)
	local bg = Instance.new("Frame")
	bg.Position = UDim2.new(0, 60, 0, posY + 2)
	bg.Size = UDim2.new(1, -75, 0, 10)
	bg.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	bg.BorderSizePixel = 0
	bg.Parent = parent
	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = bg
	return fill
end

local hpFill = makeBar(panel, 50, Color3.fromRGB(220, 60, 60))
local mpFill = makeBar(panel, 70, Color3.fromRGB(60, 110, 220))
local xpFill = makeBar(panel, 92, Color3.fromRGB(220, 200, 60))

-- Notification feed.
local feed = Instance.new("Frame")
feed.Name = "Notifications"
feed.AnchorPoint = Vector2.new(0.5, 0)
feed.Position = UDim2.new(0.5, 0, 0, 24)
feed.Size = UDim2.new(0, 480, 0, 160)
feed.BackgroundTransparency = 1
feed.Parent = screen
local feedLayout = Instance.new("UIListLayout")
feedLayout.SortOrder = Enum.SortOrder.LayoutOrder
feedLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
feedLayout.Padding = UDim.new(0, 2)
feedLayout.Parent = feed

local feedOrder = 0
local function pushNotification(text)
	feedOrder = feedOrder + 1
	local lbl = Instance.new("TextLabel")
	lbl.LayoutOrder = feedOrder
	lbl.Size = UDim2.new(1, 0, 0, 22)
	lbl.BackgroundTransparency = 0.4
	lbl.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	lbl.TextColor3 = Color3.fromRGB(255, 240, 200)
	lbl.TextStrokeTransparency = 0.3
	lbl.Font = Enum.Font.Gotham
	lbl.TextSize = 15
	lbl.Text = text
	lbl.Parent = feed
	task.delay(5, function()
		for i = 0, 30 do
			lbl.TextTransparency = i / 30
			lbl.BackgroundTransparency = 0.4 + i / 50
			task.wait(0.05)
		end
		lbl:Destroy()
	end)
end

-- Boss banner.
local bossBanner = Instance.new("Frame")
bossBanner.Name = "BossBanner"
bossBanner.AnchorPoint = Vector2.new(0.5, 0)
bossBanner.Position = UDim2.new(0.5, 0, 0, 200)
bossBanner.Size = UDim2.new(0, 600, 0, 50)
bossBanner.BackgroundColor3 = Color3.fromRGB(60, 0, 0)
bossBanner.BackgroundTransparency = 0.2
bossBanner.Visible = false
bossBanner.BorderSizePixel = 0
bossBanner.Parent = screen
local bossLbl = Instance.new("TextLabel")
bossLbl.Size = UDim2.new(1, 0, 0, 24)
bossLbl.BackgroundTransparency = 1
bossLbl.Font = Enum.Font.GothamBlack
bossLbl.TextColor3 = Color3.fromRGB(255, 200, 200)
bossLbl.TextSize = 18
bossLbl.Text = ""
bossLbl.Parent = bossBanner
local bossBarBg = Instance.new("Frame")
bossBarBg.Position = UDim2.new(0, 10, 0, 30)
bossBarBg.Size = UDim2.new(1, -20, 0, 14)
bossBarBg.BackgroundColor3 = Color3.fromRGB(20, 0, 0)
bossBarBg.BorderSizePixel = 0
bossBarBg.Parent = bossBanner
local bossBarFill = Instance.new("Frame")
bossBarFill.Size = UDim2.new(1, 0, 1, 0)
bossBarFill.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
bossBarFill.BorderSizePixel = 0
bossBarFill.Parent = bossBarBg

Remotes.Event("NotifyPlayer").OnClientEvent:Connect(pushNotification)

Remotes.Event("DataUpdated").OnClientEvent:Connect(function(data)
	raceLbl.Text = string.format("%s  •  Lvl %d", data.race, data.level)
	local stats = data.stats or {}
	local maxHp = stats.MaxHP or 100
	local maxMp = stats.MaxMP or 50
	local hp = data.hp or maxHp
	local mp = data.mp or maxMp
	hpLbl.Text = string.format("HP: %d/%d", hp, maxHp)
	mpLbl.Text = string.format("MP: %d/%d", mp, maxMp)
	xpLbl.Text = string.format("XP: %d/%d", data.xp, data.xpRequired)
	goldLbl.Text = string.format("Gold: %d", data.gold)
	hpFill.Size = UDim2.new(math.clamp(hp / maxHp, 0, 1), 0, 1, 0)
	mpFill.Size = UDim2.new(math.clamp(mp / maxMp, 0, 1), 0, 1, 0)
	xpFill.Size = UDim2.new(math.clamp(data.xp / data.xpRequired, 0, 1), 0, 1, 0)
end)

-- Live HP from humanoid (between server snapshots).
local function trackCharacter(char)
	local hum = char:WaitForChild("Humanoid")
	hum.HealthChanged:Connect(function(h)
		hpLbl.Text = string.format("HP: %d/%d", h, hum.MaxHealth)
		hpFill.Size = UDim2.new(math.clamp(h / hum.MaxHealth, 0, 1), 0, 1, 0)
	end)
end
if player.Character then trackCharacter(player.Character) end
player.CharacterAdded:Connect(trackCharacter)

Remotes.Event("BossPhase").OnClientEvent:Connect(function(info)
	bossBanner.Visible = true
	bossLbl.Text = string.format("%s — Phase %d", info.name, info.phase)
	bossBarFill.Size = UDim2.new(math.clamp(info.hpPct, 0, 1), 0, 1, 0)
	if info.hpPct <= 0 then
		task.delay(4, function() bossBanner.Visible = false end)
	end
end)

Remotes.Event("DamageNumber").OnClientEvent:Connect(function(info)
	if info.target == "self" then
		pushNotification(string.format("You take %d damage", info.amount))
	end
end)

-- Server replicates DataUpdated on character spawn; nothing else to pull here.
