-- Builds monster rigs, runs simple aggro/attack AI, handles death + respawn,
-- awards XP/loot to attackers (or their group), and exposes a registry so
-- other services (raid, dragon) can spawn or look up actors.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonsterConfig = require(Shared.Config.MonsterConfig)
local LootConfig = require(Shared.Config.LootConfig)
local ZoneConfig = require(Shared.Config.ZoneConfig)
local CombatMath = require(Shared.CombatMath)
local Remotes = require(Shared.Remotes)

-- Wait for sibling services exposed via _G.
local function waitForGlobal(name)
	while not _G[name] do task.wait() end
	return _G[name]
end

local PlayerDataService = waitForGlobal("PlayerDataService")

local MonsterService = {}
local active = {} -- model -> state

local rng = Random.new()

local function buildRig(monsterId, position)
	local def = MonsterConfig.Get(monsterId)
	assert(def, "Unknown monster: " .. tostring(monsterId))
	local scale = def.scale or 1

	local model = Instance.new("Model")
	model.Name = def.displayName

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1) * scale
	root.Color = def.color
	root.Material = Enum.Material.SmoothPlastic
	root.Anchored = false
	root.CanCollide = true
	root.TopSurface = Enum.SurfaceType.Smooth
	root.BottomSurface = Enum.SurfaceType.Smooth
	root.Position = position
	root.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.2, 1.2, 1.2) * scale
	head.Color = def.color
	head.Material = Enum.Material.SmoothPlastic
	head.Position = position + Vector3.new(0, 1.6 * scale, 0)
	head.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = head
	weld.Parent = head

	local hum = Instance.new("Humanoid")
	hum.MaxHealth = def.hp
	hum.Health = def.hp
	hum.WalkSpeed = math.clamp(10 + def.level * 0.15, 10, 22)
	hum.Parent = model

	model.PrimaryPart = root

	local nameTag = Instance.new("BillboardGui")
	nameTag.Size = UDim2.new(0, 200, 0, 50)
	nameTag.StudsOffset = Vector3.new(0, 2.5 * scale, 0)
	nameTag.AlwaysOnTop = true
	nameTag.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = def.isBoss and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(255, 240, 200)
	label.TextStrokeTransparency = 0.2
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = string.format("[%d] %s", def.level, def.displayName)
	label.Parent = nameTag

	model.Parent = workspace

	model:SetAttribute("MonsterId", monsterId)
	model:SetAttribute("Level", def.level)
	model:SetAttribute("IsBoss", def.isBoss == true)

	return model, hum, def
end

local function nearestPlayer(rootPos, range)
	local closest, dist
	for _, p in ipairs(Players:GetPlayers()) do
		local char = p.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hrp and hum and hum.Health > 0 then
			local d = (hrp.Position - rootPos).Magnitude
			if d <= range and (not dist or d < dist) then
				dist, closest = d, p
			end
		end
	end
	return closest, dist
end

local function awardKill(state, killerPlayer)
	local def = state.def
	local PartyService = _G.PartyService
	local members = { killerPlayer }
	if PartyService then
		local party = PartyService.GetPartyOf(killerPlayer)
		if party then
			members = {}
			for _, p in ipairs(party.members) do
				if p.Character and (p.Character.HumanoidRootPart.Position - state.model.PrimaryPart.Position).Magnitude < 200 then
					table.insert(members, p)
				end
			end
			if #members == 0 then members = { killerPlayer } end
		end
	end

	for _, p in ipairs(members) do
		local data = PlayerDataService.Get(p)
		if data then
			local base = CombatMath.ScaleXP(def.xpReward, data.level, def.level)
			local share = CombatMath.SplitGroupXP(base, #members)
			PlayerDataService.AwardXP(p, share)
		end
	end

	local loot = LootConfig.Roll(def.lootTable, rng)
	for i, drop in ipairs(loot) do
		local recipient = members[((i - 1) % #members) + 1]
		PlayerDataService.AddItem(recipient, drop.id, drop.qty)
	end
end

local function damagePlayer(player, raw)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end
	local dmg = CombatMath.ComputeDamage(raw, 0, rng)
	hum:TakeDamage(dmg)
	Remotes.Event("DamageNumber"):FireClient(player, { amount = dmg, target = "self" })
end

function MonsterService.Spawn(monsterId, position, options)
	local model, hum, def = buildRig(monsterId, position)
	local state = {
		model = model,
		humanoid = hum,
		def = def,
		spawnPos = position,
		zoneId = options and options.zoneId,
		isBossSpawn = options and options.isBossSpawn,
		threat = {},
		nextAttack = 0,
	}
	active[model] = state

	hum.Died:Connect(function()
		local topAttacker
		local topDmg = -1
		for player, dmg in pairs(state.threat) do
			if dmg > topDmg then
				topDmg = dmg
				topAttacker = player
			end
		end
		if topAttacker then
			awardKill(state, topAttacker)
		end
		task.delay(4, function()
			model:Destroy()
		end)
		active[model] = nil

		if not state.isBossSpawn and state.zoneId then
			task.delay(20 + math.random() * 20, function()
				local zone = ZoneConfig.GetById(state.zoneId)
				if zone then
					local pos = Vector3.new(
						zone.center.X + math.random(-zone.size.X / 2, zone.size.X / 2),
						zone.center.Y + 5,
						zone.center.Z + math.random(-zone.size.Z / 2, zone.size.Z / 2)
					)
					MonsterService.Spawn(monsterId, pos, options)
				end
			end)
		end
	end)

	return state
end

-- Player damages a monster (called from CombatService).
function MonsterService.ApplyDamage(model, player, rawDamage)
	local state = active[model]
	if not state then return end
	local hum = state.humanoid
	if not hum or hum.Health <= 0 then return end
	local dmg = CombatMath.ComputeDamage(rawDamage, 0, rng)
	hum:TakeDamage(dmg)
	state.threat[player] = (state.threat[player] or 0) + dmg
	Remotes.Event("DamageNumber"):FireClient(player, {
		amount = dmg,
		target = "monster",
		position = state.model.PrimaryPart.Position,
	})
end

function MonsterService.GetState(model)
	return active[model]
end

function MonsterService.GetActive()
	return active
end

-- Single tick driving every monster's AI; cheaper than per-monster threads.
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for model, state in pairs(active) do
		local root = model.PrimaryPart
		local hum = state.humanoid
		if not root or not hum or hum.Health <= 0 then
			-- skip
		else
			local target, dist = nearestPlayer(root.Position, state.def.aggroRadius)
			if target and target.Character then
				hum:MoveTo(target.Character.HumanoidRootPart.Position)
				if dist and dist < 6 and now >= state.nextAttack then
					state.nextAttack = now + state.def.attackSpeed
					damagePlayer(target, state.def.damage)
					state.threat[target] = (state.threat[target] or 0) + state.def.damage * 0.5
				end
			else
				-- wander toward spawn
				if (root.Position - state.spawnPos).Magnitude > 4 then
					hum:MoveTo(state.spawnPos)
				end
			end
		end
	end
end)

-- Initial population from zone configs.
task.defer(function()
	for _, zone in ipairs(ZoneConfig.Zones) do
		for _, spawn in ipairs(zone.spawns) do
			local monsterId, count = spawn[1], spawn[2]
			for _ = 1, count do
				local pos = Vector3.new(
					zone.center.X + math.random(-zone.size.X / 2, zone.size.X / 2),
					zone.center.Y + 5,
					zone.center.Z + math.random(-zone.size.Z / 2, zone.size.Z / 2)
				)
				MonsterService.Spawn(monsterId, pos, { zoneId = zone.id })
			end
		end
	end
end)

_G.MonsterService = MonsterService
return MonsterService
