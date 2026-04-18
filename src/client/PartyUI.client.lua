-- Press P to open the party panel: invite, leave, convert to raid.
-- Invite popups auto-show when received.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

local screen = Instance.new("ScreenGui")
screen.Name = "PartyUI"
screen.ResetOnSpawn = false
screen.Parent = pg

-- Persistent party roster (always visible if in a party).
local roster = Instance.new("Frame")
roster.Position = UDim2.new(0, 12, 0, 160)
roster.Size = UDim2.new(0, 220, 0, 160)
roster.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
roster.BackgroundTransparency = 0.3
roster.BorderSizePixel = 0
roster.Visible = false
roster.Parent = screen

local rosterTitle = Instance.new("TextLabel")
rosterTitle.Size = UDim2.new(1, 0, 0, 22)
rosterTitle.BackgroundTransparency = 1
rosterTitle.Font = Enum.Font.GothamBold
rosterTitle.TextSize = 14
rosterTitle.TextColor3 = Color3.fromRGB(255, 240, 200)
rosterTitle.Text = "Party"
rosterTitle.Parent = roster

local rosterList = Instance.new("Frame")
rosterList.Position = UDim2.new(0, 6, 0, 24)
rosterList.Size = UDim2.new(1, -12, 1, -30)
rosterList.BackgroundTransparency = 1
rosterList.Parent = roster

local rosterLayout = Instance.new("UIListLayout")
rosterLayout.Padding = UDim.new(0, 2)
rosterLayout.Parent = rosterList

-- Management panel (toggle with P).
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.new(0.5, 0, 0.5, 0)
panel.Size = UDim2.new(0, 360, 0, 220)
panel.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = screen

local pTitle = Instance.new("TextLabel")
pTitle.Size = UDim2.new(1, 0, 0, 28)
pTitle.BackgroundTransparency = 1
pTitle.Font = Enum.Font.GothamBlack
pTitle.TextSize = 18
pTitle.TextColor3 = Color3.fromRGB(255, 240, 200)
pTitle.Text = "Party  (P to close)"
pTitle.Parent = panel

local hint = Instance.new("TextLabel")
hint.Position = UDim2.new(0, 12, 0, 32)
hint.Size = UDim2.new(1, -24, 0, 18)
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.Gotham
hint.TextSize = 12
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.TextColor3 = Color3.fromRGB(200, 200, 220)
hint.Text = "Invite by exact player name. Type /joinraid <id> in chat to join a raid."
hint.Parent = panel

local inviteBox = Instance.new("TextBox")
inviteBox.Position = UDim2.new(0, 12, 0, 60)
inviteBox.Size = UDim2.new(1, -130, 0, 28)
inviteBox.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
inviteBox.BorderSizePixel = 0
inviteBox.PlaceholderText = "Player name…"
inviteBox.Text = ""
inviteBox.TextColor3 = Color3.fromRGB(255, 240, 200)
inviteBox.Font = Enum.Font.Gotham
inviteBox.TextSize = 14
inviteBox.ClearTextOnFocus = false
inviteBox.Parent = panel

local function makeButton(text, x, y, w, color)
	local b = Instance.new("TextButton")
	b.Position = UDim2.new(0, x, 0, y)
	b.Size = UDim2.new(0, w, 0, 28)
	b.BackgroundColor3 = color
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamSemibold
	b.TextSize = 14
	b.TextColor3 = Color3.fromRGB(20, 20, 28)
	b.Text = text
	b.Parent = panel
	return b
end

local inviteBtn = makeButton("Invite", 0, 60, 100, Color3.fromRGB(180, 200, 120))
inviteBtn.Position = UDim2.new(1, -112, 0, 60)

local leaveBtn = makeButton("Leave Party", 12, 100, 160, Color3.fromRGB(220, 120, 120))
local raidBtn = makeButton("Form Raid", 184, 100, 160, Color3.fromRGB(200, 160, 80))

local statusLbl = Instance.new("TextLabel")
statusLbl.Position = UDim2.new(0, 12, 0, 140)
statusLbl.Size = UDim2.new(1, -24, 0, 60)
statusLbl.BackgroundTransparency = 1
statusLbl.Font = Enum.Font.Gotham
statusLbl.TextSize = 13
statusLbl.TextWrapped = true
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.TextYAlignment = Enum.TextYAlignment.Top
statusLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
statusLbl.Text = "Not in a party."
statusLbl.Parent = panel

inviteBtn.MouseButton1Click:Connect(function()
	if inviteBox.Text ~= "" then
		Remotes.Event("PartyInvite"):FireServer(inviteBox.Text)
		inviteBox.Text = ""
	end
end)
leaveBtn.MouseButton1Click:Connect(function()
	Remotes.Event("PartyLeave"):FireServer()
end)
raidBtn.MouseButton1Click:Connect(function()
	Remotes.Event("RaidConvert"):FireServer()
end)

Remotes.Event("PartyUpdated").OnClientEvent:Connect(function(snapshot)
	for _, c in ipairs(rosterList:GetChildren()) do
		if c:IsA("TextLabel") then c:Destroy() end
	end
	if not snapshot or not snapshot.id or #snapshot.members == 0 then
		roster.Visible = false
		statusLbl.Text = "Not in a party."
		return
	end
	roster.Visible = true
	rosterTitle.Text = string.format("Party  (Leader: %s)%s", snapshot.leader, snapshot.raidId and ("  •  Raid #" .. snapshot.raidId) or "")
	statusLbl.Text = string.format("Party of %d. Leader: %s.%s",
		#snapshot.members, snapshot.leader,
		snapshot.raidId and ("\nIn raid #" .. snapshot.raidId .. ".") or "")
	for i, m in ipairs(snapshot.members) do
		local lbl = Instance.new("TextLabel")
		lbl.LayoutOrder = i
		lbl.Size = UDim2.new(1, 0, 0, 18)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.Gotham
		lbl.TextSize = 13
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextColor3 = Color3.fromRGB(255, 240, 200)
		lbl.Text = string.format("• %s   %d/%d", m.name, math.floor(m.hp), math.floor(m.maxHp))
		lbl.Parent = rosterList
	end
end)

-- Invite popup.
Remotes.Event("PartyInvite").OnClientEvent:Connect(function(info)
	local pop = Instance.new("Frame")
	pop.AnchorPoint = Vector2.new(0.5, 0)
	pop.Position = UDim2.new(0.5, 0, 0, 280)
	pop.Size = UDim2.new(0, 320, 0, 90)
	pop.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	pop.BackgroundTransparency = 0.1
	pop.BorderSizePixel = 0
	pop.Parent = screen
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0, 40)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamSemibold
	lbl.TextSize = 14
	lbl.TextColor3 = Color3.fromRGB(255, 240, 200)
	lbl.Text = info.from .. " invites you to a party."
	lbl.Parent = pop
	local accept = Instance.new("TextButton")
	accept.Position = UDim2.new(0, 20, 0, 50)
	accept.Size = UDim2.new(0, 130, 0, 30)
	accept.BackgroundColor3 = Color3.fromRGB(140, 220, 140)
	accept.BorderSizePixel = 0
	accept.Font = Enum.Font.GothamBold
	accept.TextSize = 14
	accept.Text = "Accept"
	accept.Parent = pop
	local decline = accept:Clone()
	decline.Position = UDim2.new(0, 170, 0, 50)
	decline.BackgroundColor3 = Color3.fromRGB(220, 120, 120)
	decline.Text = "Decline"
	decline.Parent = pop
	accept.MouseButton1Click:Connect(function()
		Remotes.Event("PartyRespond"):FireServer(true)
		pop:Destroy()
	end)
	decline.MouseButton1Click:Connect(function()
		Remotes.Event("PartyRespond"):FireServer(false)
		pop:Destroy()
	end)
	task.delay(30, function() if pop.Parent then pop:Destroy() end end)
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.P then
		panel.Visible = not panel.Visible
	end
end)
