-- Click a monster to attack. Press Q to toggle auto-attack (seeks the
-- nearest valid target in range and attacks every cooldown). Server is
-- authoritative; client just requests attacks.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local MonsterConfig = require(Shared.Config.MonsterConfig)

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local ATTACK_COOLDOWN = 1.2 -- keep in sync with server CombatService
local ATTACK_RANGE = 11     -- slightly under server's 12 to absorb latency
local SEARCH_RADIUS = 50    -- how far auto-attack will look for a target

-- Swing animation. If this id isn't available in your game, upload your own
-- and paste the rbxassetid here.
local SLASH_ANIM_ID = "rbxassetid://522635514"
local slashAnim = Instance.new("Animation")
slashAnim.AnimationId = SLASH_ANIM_ID

local pg = player:WaitForChild("PlayerGui")
local screen = Instance.new("ScreenGui")
screen.Name = "CombatHUD"
screen.ResetOnSpawn = false
screen.Parent = pg

-- Auto-attack toggle UI (bottom-left, next to the Inventory button).
local autoLbl = Instance.new("TextLabel")
autoLbl.Name = "AutoAttackIndicator"
autoLbl.AnchorPoint = Vector2.new(0, 1)
autoLbl.Position = UDim2.new(0, 164, 1, -12)
autoLbl.Size = UDim2.new(0, 170, 0, 34)
autoLbl.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
autoLbl.BorderSizePixel = 0
autoLbl.Font = Enum.Font.GothamSemibold
autoLbl.TextSize = 14
autoLbl.TextColor3 = Color3.fromRGB(180, 180, 180)
autoLbl.Text = "Auto-attack: OFF (Q)"
autoLbl.Parent = screen

-- Target panel directly below the character HUD panel.
local targetPanel = Instance.new("Frame")
targetPanel.Name = "TargetPanel"
targetPanel.Size = UDim2.new(0, 260, 0, 62)
targetPanel.Position = UDim2.new(0, 12, 0, 200)
targetPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
targetPanel.BackgroundTransparency = 0.25
targetPanel.BorderSizePixel = 0
targetPanel.Visible = false
targetPanel.Parent = screen

local targetTitle = Instance.new("TextLabel")
targetTitle.Size = UDim2.new(1, -20, 0, 20)
targetTitle.Position = UDim2.new(0, 10, 0, 4)
targetTitle.BackgroundTransparency = 1
targetTitle.Font = Enum.Font.GothamBold
targetTitle.TextSize = 14
targetTitle.TextXAlignment = Enum.TextXAlignment.Left
targetTitle.TextColor3 = Color3.fromRGB(255, 240, 200)
targetTitle.Text = "Target"
targetTitle.Parent = targetPanel

local targetHpLbl = Instance.new("TextLabel")
targetHpLbl.Size = UDim2.new(1, -20, 0, 16)
targetHpLbl.Position = UDim2.new(0, 10, 0, 24)
targetHpLbl.BackgroundTransparency = 1
targetHpLbl.Font = Enum.Font.Gotham
targetHpLbl.TextSize = 13
targetHpLbl.TextXAlignment = Enum.TextXAlignment.Left
targetHpLbl.TextColor3 = Color3.fromRGB(230, 220, 200)
targetHpLbl.Text = "HP: —/—"
targetHpLbl.Parent = targetPanel

local targetBarBg = Instance.new("Frame")
targetBarBg.Position = UDim2.new(0, 10, 0, 44)
targetBarBg.Size = UDim2.new(1, -20, 0, 12)
targetBarBg.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
targetBarBg.BorderSizePixel = 0
targetBarBg.Parent = targetPanel
local targetBarFill = Instance.new("Frame")
targetBarFill.Size = UDim2.new(1, 0, 1, 0)
targetBarFill.BackgroundColor3 = Color3.fromRGB(220, 80, 80)
targetBarFill.BorderSizePixel = 0
targetBarFill.Parent = targetBarBg

local autoAttackEnabled = false
local lastAttack = 0
local currentTarget = nil
local targetHealthConn, targetDiedConn, targetRemovedConn

local function clearTarget()
	if targetHealthConn then targetHealthConn:Disconnect() targetHealthConn = nil end
	if targetDiedConn then targetDiedConn:Disconnect() targetDiedConn = nil end
	if targetRemovedConn then targetRemovedConn:Disconnect() targetRemovedConn = nil end
	currentTarget = nil
	targetPanel.Visible = false
end

local function refreshTargetUI()
	if not currentTarget then targetPanel.Visible = false return end
	local hum = currentTarget:FindFirstChildOfClass("Humanoid")
	if not hum then clearTarget() return end
	local id = currentTarget:GetAttribute("MonsterId")
	local def = id and MonsterConfig.Get(id)
	local displayName = def and def.displayName or currentTarget.Name
	local level = currentTarget:GetAttribute("Level") or (def and def.level) or 0
	targetTitle.Text = string.format("[%d] %s", level, displayName)
	targetHpLbl.Text = string.format("HP: %d/%d", math.floor(hum.Health), math.floor(hum.MaxHealth))
	targetBarFill.Size = UDim2.new(math.clamp(hum.Health / math.max(1, hum.MaxHealth), 0, 1), 0, 1, 0)
	targetPanel.Visible = true
end

local function setTarget(monster)
	if monster == currentTarget then return end
	clearTarget()
	if not monster then return end
	local hum = monster:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end
	currentTarget = monster
	targetHealthConn = hum.HealthChanged:Connect(refreshTargetUI)
	targetDiedConn = hum.Died:Connect(clearTarget)
	targetRemovedConn = monster.AncestryChanged:Connect(function(_, parent)
		if not parent then clearTarget() end
	end)
	refreshTargetUI()
end

local function updateUI()
	if autoAttackEnabled then
		autoLbl.Text = "Auto-attack: ON (Q)"
		autoLbl.TextColor3 = Color3.fromRGB(140, 220, 140)
		autoLbl.BackgroundColor3 = Color3.fromRGB(40, 70, 40)
	else
		autoLbl.Text = "Auto-attack: OFF (Q)"
		autoLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
		autoLbl.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
	end
end

local function getAnimator()
	local char = player.Character
	if not char then return nil end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return nil end
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = hum
	end
	return animator
end

local function playSwing()
	local animator = getAnimator()
	if not animator then return end
	local ok, track = pcall(animator.LoadAnimation, animator, slashAnim)
	if not ok or not track then return end
	track.Priority = Enum.AnimationPriority.Action
	track:Play(0.1, 1, 1.4)
	task.delay(0.8, function()
		if track.IsPlaying then track:Stop(0.15) end
		track:Destroy()
	end)
end

local function findMonsterAncestor(inst)
	local cur = inst
	while cur and cur ~= workspace do
		if cur:IsA("Model") and cur:GetAttribute("MonsterId") then
			return cur
		end
		cur = cur.Parent
	end
end

local function nearestMonster(fromPos, radius)
	local best, bestDist
	for _, m in ipairs(workspace:GetDescendants()) do
		if m:IsA("Model") and m:GetAttribute("MonsterId") and m.PrimaryPart then
			local hum = m:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				local d = (m.PrimaryPart.Position - fromPos).Magnitude
				if d <= radius and (not bestDist or d < bestDist) then
					best, bestDist = m, d
				end
			end
		end
	end
	return best, bestDist
end

local function targetStillValid(fromPos)
	if not currentTarget or not currentTarget.Parent or not currentTarget.PrimaryPart then return false end
	local hum = currentTarget:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return false end
	return (currentTarget.PrimaryPart.Position - fromPos).Magnitude <= SEARCH_RADIUS
end

local function tryAttack(target)
	if not target or not target.PrimaryPart then return false end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end
	local now = os.clock()
	if now - lastAttack < ATTACK_COOLDOWN then return false end
	local dist = (hrp.Position - target.PrimaryPart.Position).Magnitude
	if dist > ATTACK_RANGE then return false end
	lastAttack = now
	Remotes.Event("PlayerAttack"):FireServer(target)
	playSwing()
	return true
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Q then
		autoAttackEnabled = not autoAttackEnabled
		updateUI()
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		local hit = mouse.Target
		local monster = hit and findMonsterAncestor(hit)
		if monster then
			setTarget(monster)
			tryAttack(monster)
		end
	end
end)

-- Auto-attack heartbeat: stick with the current target until it dies or
-- leaves the search radius, otherwise pick the nearest valid one.
RunService.Heartbeat:Connect(function()
	if not autoAttackEnabled then return end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	if not targetStillValid(hrp.Position) then
		local nm = nearestMonster(hrp.Position, SEARCH_RADIUS)
		if nm then setTarget(nm) end
	end
	local now = os.clock()
	if now - lastAttack < ATTACK_COOLDOWN then return end
	if currentTarget then tryAttack(currentTarget) end
end)

updateUI()
