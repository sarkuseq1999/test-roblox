-- Vexrothan, the Ancient: end-game raid encounter at Dragon's Reach.
-- Encounter starts when a raid leader stands on the activation pad.
-- Three phases: Stomp (>66%), Inferno adds (33-66%), Frenzy (<33%).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ZoneConfig = require(Shared.Config.ZoneConfig)
local Remotes = require(Shared.Remotes)

local function waitForGlobal(name)
	while not _G[name] do task.wait() end
	return _G[name]
end

local MonsterService = waitForGlobal("MonsterService")
local PartyService = waitForGlobal("PartyService")

local DragonBossService = {}
local activeEncounter = nil
local activationPad

local lairZone = ZoneConfig.GetById("vexrothan_lair")
if not lairZone then
	-- Lair zone not configured — boss encounter disabled.
	_G.DragonBossService = DragonBossService
	return DragonBossService
end
local PAD_POS = lairZone.center + Vector3.new(0, 5, 80)
local DRAGON_POS = lairZone.center + Vector3.new(0, 15, 0)

local function buildLair()
	local folder = Instance.new("Folder")
	folder.Name = "VexrothanLair"
	folder.Parent = workspace

	local floor = Instance.new("Part")
	floor.Name = "LairFloor"
	floor.Size = Vector3.new(400, 4, 400)
	floor.Position = lairZone.center - Vector3.new(0, 2, 0)
	floor.Anchored = true
	floor.Material = Enum.Material.Slate
	floor.Color = Color3.fromRGB(70, 50, 50)
	floor.Parent = folder

	activationPad = Instance.new("Part")
	activationPad.Name = "ActivationPad"
	activationPad.Size = Vector3.new(20, 1, 20)
	activationPad.Position = PAD_POS
	activationPad.Anchored = true
	activationPad.Material = Enum.Material.Neon
	activationPad.Color = Color3.fromRGB(255, 80, 80)
	activationPad.Parent = folder

	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.new(0, 400, 0, 80)
	sign.StudsOffset = Vector3.new(0, 6, 0)
	sign.AlwaysOnTop = true
	sign.Parent = activationPad
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 220, 200)
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.Text = "Vexrothan's Lair — Raid Leader: step on pad"
	label.Parent = sign
end

local function announce(playerList, msg)
	for _, p in ipairs(playerList) do
		Remotes.Event("NotifyPlayer"):FireClient(p, msg)
	end
end

local function broadcastPhase(state, phase)
	for _, p in ipairs(state.raidPlayers) do
		Remotes.Event("BossPhase"):FireClient(p, {
			name = state.def.displayName,
			phase = phase,
			hpPct = state.humanoid.Health / state.humanoid.MaxHealth,
		})
	end
end

local function startEncounter(leader)
	if activeEncounter then return end
	local raid, raidPlayers = PartyService.GetRaidOf(leader)
	if not raid then
		Remotes.Event("NotifyPlayer"):FireClient(leader, "You must be in a raid to challenge Vexrothan.")
		return
	end
	if #raidPlayers < 6 then
		Remotes.Event("NotifyPlayer"):FireClient(leader, "Need at least 6 raid members.")
		return
	end

	local state = MonsterService.Spawn("ancient_dragon", DRAGON_POS, { isBossSpawn = true })
	activeEncounter = {
		humanoid = state.humanoid,
		model = state.model,
		def = state.def,
		raidPlayers = raidPlayers,
		phase = 1,
		nextSpecial = os.clock() + 8,
	}
	announce(raidPlayers, "Vexrothan, the Ancient awakens!")
	broadcastPhase(activeEncounter, 1)

	state.humanoid.Died:Connect(function()
		announce(activeEncounter.raidPlayers, "Vexrothan has fallen! The realm is saved.")
		activeEncounter = nil
	end)
end

local function tickEncounter()
	local enc = activeEncounter
	if not enc or not enc.humanoid or enc.humanoid.Health <= 0 then return end

	local pct = enc.humanoid.Health / enc.humanoid.MaxHealth
	local desiredPhase = (pct > 0.66 and 1) or (pct > 0.33 and 2) or 3
	if desiredPhase ~= enc.phase then
		enc.phase = desiredPhase
		broadcastPhase(enc, desiredPhase)
		if desiredPhase == 2 then
			announce(enc.raidPlayers, "Vexrothan summons reinforcements!")
		elseif desiredPhase == 3 then
			announce(enc.raidPlayers, "Vexrothan enters a frenzy!")
		end
	end

	local now = os.clock()
	if now < enc.nextSpecial then return end
	enc.nextSpecial = now + (enc.phase == 3 and 5 or 9)

	local root = enc.model.PrimaryPart
	if not root then return end

	if enc.phase == 1 then
		-- Tail Sweep: AoE around the dragon.
		for _, p in ipairs(enc.raidPlayers) do
			local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
			if hrp and hum and hum.Health > 0 and (hrp.Position - root.Position).Magnitude < 25 then
				hum:TakeDamage(120)
				Remotes.Event("DamageNumber"):FireClient(p, { amount = 120, target = "self" })
			end
		end
	elseif enc.phase == 2 then
		-- Summon two whelps to pressure the raid.
		for _ = 1, 2 do
			MonsterService.Spawn("dragon_whelp", root.Position + Vector3.new(math.random(-15, 15), 5, math.random(-15, 15)), { isBossSpawn = true })
		end
	else
		-- Frenzy: heavy single-target on closest player.
		local closest, dist
		for _, p in ipairs(enc.raidPlayers) do
			local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
			if hrp and hum and hum.Health > 0 then
				local d = (hrp.Position - root.Position).Magnitude
				if not dist or d < dist then closest, dist = p, d end
			end
		end
		if closest then
			local hum = closest.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				hum:TakeDamage(280)
				Remotes.Event("DamageNumber"):FireClient(closest, { amount = 280, target = "self" })
			end
		end
	end
end

buildLair()

-- Pad activation watcher: leader stands on pad to start.
RunService.Heartbeat:Connect(function()
	tickEncounter()
	if activeEncounter or not activationPad then return end
	for _, p in ipairs(Players:GetPlayers()) do
		local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if hrp and (hrp.Position - PAD_POS).Magnitude < 12 then
			startEncounter(p)
			break
		end
	end
end)

_G.DragonBossService = DragonBossService
return DragonBossService
