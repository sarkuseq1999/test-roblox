-- Builds Freeport (safe city) plus terrain pads for adventuring zones.
-- Freeport styled after classic EverQuest: tan stone block walls with
-- crenellations, triple-arched gate, plaza with fountain, wall lanterns.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ZoneConfig = require(Shared.Config.ZoneConfig)

-- Palette
local STONE_LIGHT = Color3.fromRGB(205, 188, 150)
local STONE_DARK = Color3.fromRGB(130, 115, 95)
local STONE_TRIM = Color3.fromRGB(170, 150, 120)
local WOOD_DARK = Color3.fromRGB(90, 60, 40)
local COBBLE = Color3.fromRGB(165, 150, 125)
local SAND = Color3.fromRGB(210, 190, 150)
local WATER = Color3.fromRGB(90, 140, 170)
local LANTERN = Color3.fromRGB(255, 200, 110)

local function makePart(opts)
	local p = Instance.new("Part")
	p.Name = opts.name or "Part"
	p.Size = opts.size
	p.Color = opts.color or STONE_LIGHT
	p.Material = opts.material or Enum.Material.Brick
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if opts.cframe then
		p.CFrame = opts.cframe
	else
		p.Position = opts.position
	end
	if opts.transparency then p.Transparency = opts.transparency end
	if opts.shape then p.Shape = opts.shape end
	p.Parent = opts.parent
	return p
end

local function makeZonePad(zone, parent)
	local color
	if zone.isSafe then
		color = Color3.fromRGB(120, 180, 120)
	elseif zone.isRaidZone then
		color = Color3.fromRGB(140, 60, 60)
	else
		local lo = zone.levelRange[1]
		local t = math.clamp(lo / 50, 0, 1)
		color = Color3.fromRGB(80 + 120 * (1 - t), 100, 80 + 120 * t)
	end
	makePart({
		name = zone.id .. "_floor", parent = parent, color = color,
		size = Vector3.new(zone.size.X, 2, zone.size.Z),
		position = zone.center - Vector3.new(0, 1, 0),
		material = Enum.Material.Grass,
	})

	if zone.isSafe then return end -- no sign post inside the city itself

	local sign = makePart({
		name = zone.id .. "_sign", parent = parent,
		size = Vector3.new(1, 6, 1),
		position = zone.center + Vector3.new(14, 3, -zone.size.Z / 2 + 4),
		color = WOOD_DARK, material = Enum.Material.Wood,
	})
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 260, 0, 70)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.MaxDistance = 250
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 240, 200)
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = string.format("%s\nLvl %d–%d", zone.name, zone.levelRange[1], zone.levelRange[2])
	label.Parent = gui
end

-- A crenellated wall segment: main wall, a cap, then merlons on top.
-- axis = "x" (runs along X) or "z" (runs along Z); length is along that axis.
local function wallSegment(parent, name, centerPos, length, axis, height, thickness)
	height = height or 26
	thickness = thickness or 5
	local size
	if axis == "x" then
		size = Vector3.new(length, height, thickness)
	else
		size = Vector3.new(thickness, height, length)
	end
	makePart({
		name = name, parent = parent, size = size,
		position = centerPos + Vector3.new(0, height / 2, 0),
		color = STONE_LIGHT, material = Enum.Material.Brick,
	})
	-- cap (slightly darker, slightly wider visually by using a lip)
	local capSize = axis == "x"
		and Vector3.new(length, 1.5, thickness + 1)
		or Vector3.new(thickness + 1, 1.5, length)
	makePart({
		name = name .. "_cap", parent = parent, size = capSize,
		position = centerPos + Vector3.new(0, height + 0.75, 0),
		color = STONE_DARK, material = Enum.Material.Slate,
	})
	-- merlons along the length
	local merlonSize = Vector3.new(3, 3, thickness + 1)
	if axis == "z" then
		merlonSize = Vector3.new(thickness + 1, 3, 3)
	end
	local step = 6
	local count = math.floor(length / step)
	local startOffset = -((count - 1) * step) / 2
	for i = 0, count - 1 do
		local off = startOffset + i * step
		local pos
		if axis == "x" then
			pos = centerPos + Vector3.new(off, height + 3, 0)
		else
			pos = centerPos + Vector3.new(0, height + 3, off)
		end
		makePart({
			name = name .. "_merlon" .. i, parent = parent, size = merlonSize,
			position = pos, color = STONE_LIGHT, material = Enum.Material.Brick,
		})
	end
end

local function lantern(parent, name, pos)
	-- wall bracket
	makePart({
		name = name .. "_bracket", parent = parent, size = Vector3.new(0.8, 2, 0.8),
		position = pos, color = WOOD_DARK, material = Enum.Material.Wood,
	})
	local glow = makePart({
		name = name .. "_glow", parent = parent, size = Vector3.new(1.2, 1.2, 1.2),
		position = pos + Vector3.new(0, 1.8, 0),
		color = LANTERN, material = Enum.Material.Neon,
	})
	local light = Instance.new("PointLight")
	light.Color = LANTERN
	light.Range = 22
	light.Brightness = 1.8
	light.Parent = glow
end

-- Triple-arched gate spanning the north wall (centered on x=centerX, at z=wallZ).
local function tripleArchGate(parent, centerX, wallZ, wallHeight)
	local y = 0
	local thickness = 6
	-- 4 piers (columns) making 3 openings
	local pierW = 5
	local openingW = 10
	local totalW = 4 * pierW + 3 * openingW -- 50 + 30 = 50 wait: 4*5=20, 3*10=30, total 50? Let me recompute
	-- Actually: 4*5 + 3*10 = 20 + 30 = 50
	local leftX = centerX - totalW / 2 + pierW / 2
	for i = 0, 3 do
		local x = leftX + i * (pierW + openingW)
		makePart({
			name = "GatePier" .. i, parent = parent,
			size = Vector3.new(pierW, wallHeight, thickness),
			position = Vector3.new(x, y + wallHeight / 2, wallZ),
			color = STONE_LIGHT, material = Enum.Material.Brick,
		})
	end
	-- Horizontal beam / entablature above openings
	makePart({
		name = "GateBeam", parent = parent,
		size = Vector3.new(totalW + 4, 3, thickness + 1),
		position = Vector3.new(centerX, y + wallHeight - 1.5, wallZ),
		color = STONE_DARK, material = Enum.Material.Slate,
	})
	-- "Arch" suggestion: thin wedge-like cap between piers
	for i = 0, 2 do
		local x = leftX + i * (pierW + openingW) + (pierW + openingW) / 2
		makePart({
			name = "GateArchSpan" .. i, parent = parent,
			size = Vector3.new(openingW - 1, 3, thickness - 1),
			position = Vector3.new(x, y + wallHeight - 5, wallZ),
			color = STONE_LIGHT, material = Enum.Material.Brick,
		})
		makePart({
			name = "GateArchKey" .. i, parent = parent,
			size = Vector3.new(2, 2, thickness - 1),
			position = Vector3.new(x, y + wallHeight - 4, wallZ),
			color = STONE_DARK, material = Enum.Material.Slate,
		})
	end
	-- Crenellated top cap running across the gate
	makePart({
		name = "GateTopCap", parent = parent,
		size = Vector3.new(totalW + 8, 1.5, thickness + 2),
		position = Vector3.new(centerX, y + wallHeight + 0.75, wallZ),
		color = STONE_DARK, material = Enum.Material.Slate,
	})
	for i = 0, 7 do
		local x = centerX - totalW / 2 - 4 + i * ((totalW + 8) / 8) + ((totalW + 8) / 16)
		makePart({
			name = "GateMerlon" .. i, parent = parent, size = Vector3.new(3, 3, thickness + 2),
			position = Vector3.new(x, y + wallHeight + 3, wallZ),
			color = STONE_LIGHT, material = Enum.Material.Brick,
		})
	end
	-- Gate lanterns
	lantern(parent, "GateLanternL", Vector3.new(centerX - totalW / 2 - 2, 16, wallZ + thickness / 2 - 0.5))
	lantern(parent, "GateLanternR", Vector3.new(centerX + totalW / 2 + 2, 16, wallZ + thickness / 2 - 0.5))
end

-- A stylized building: stone base, wooden door, flat roof with trim.
local function building(parent, name, pos, size, facing)
	-- pos is center at ground level; size = (w, h, d)
	local w, h, d = size.X, size.Y, size.Z
	makePart({
		name = name .. "_body", parent = parent,
		size = Vector3.new(w, h, d),
		position = pos + Vector3.new(0, h / 2, 0),
		color = STONE_LIGHT, material = Enum.Material.Brick,
	})
	-- Trim at the top
	makePart({
		name = name .. "_trim", parent = parent,
		size = Vector3.new(w + 1, 1.5, d + 1),
		position = pos + Vector3.new(0, h + 0.75, 0),
		color = STONE_DARK, material = Enum.Material.Slate,
	})
	-- Wooden door facing the plaza
	local doorOffset = Vector3.new(0, 0, 0)
	if facing == "+z" then doorOffset = Vector3.new(0, 0, d / 2 + 0.05)
	elseif facing == "-z" then doorOffset = Vector3.new(0, 0, -d / 2 - 0.05)
	elseif facing == "+x" then doorOffset = Vector3.new(w / 2 + 0.05, 0, 0)
	elseif facing == "-x" then doorOffset = Vector3.new(-w / 2 - 0.05, 0, 0)
	end
	local doorSize
	if facing == "+z" or facing == "-z" then
		doorSize = Vector3.new(5, 8, 0.4)
	else
		doorSize = Vector3.new(0.4, 8, 5)
	end
	makePart({
		name = name .. "_door", parent = parent, size = doorSize,
		position = pos + Vector3.new(0, 4, 0) + doorOffset,
		color = WOOD_DARK, material = Enum.Material.Wood,
	})
	-- Door lanterns
	local latOff = Vector3.new(doorOffset.X * 1.1, 6, doorOffset.Z * 1.1)
	local side1, side2 = Vector3.zero, Vector3.zero
	if facing == "+z" or facing == "-z" then
		side1 = Vector3.new(-4, 0, 0); side2 = Vector3.new(4, 0, 0)
	else
		side1 = Vector3.new(0, 0, -4); side2 = Vector3.new(0, 0, 4)
	end
	lantern(parent, name .. "_lantL", pos + latOff + side1)
	lantern(parent, name .. "_lantR", pos + latOff + side2)
end

local function buildFreeport(parent)
	local center = ZoneConfig.GetById("freeport").center
	local cx, cy, cz = center.X, center.Y, center.Z

	-- Sandy street replacing the grass within the walls.
	makePart({
		name = "FreeportGround", parent = parent,
		size = Vector3.new(290, 1, 290),
		position = center,
		color = SAND, material = Enum.Material.Sand,
	})

	-- Walls ring. North wall is split around the gate (total opening ~50 wide).
	wallSegment(parent, "WallS", Vector3.new(cx, cy - 0.5, cz - 150), 300, "x")
	wallSegment(parent, "WallE", Vector3.new(cx + 150, cy - 0.5, cz), 300, "z")
	wallSegment(parent, "WallW", Vector3.new(cx - 150, cy - 0.5, cz), 300, "z")
	wallSegment(parent, "WallNL", Vector3.new(cx - 100, cy - 0.5, cz + 150), 100, "x")
	wallSegment(parent, "WallNR", Vector3.new(cx + 100, cy - 0.5, cz + 150), 100, "x")

	tripleArchGate(parent, cx, cz + 150, 26)

	-- Corner lanterns at wall tops
	local corners = {
		Vector3.new(cx - 148, 18, cz - 148),
		Vector3.new(cx + 148, 18, cz - 148),
		Vector3.new(cx - 148, 18, cz + 148),
		Vector3.new(cx + 148, 18, cz + 148),
	}
	for i, p in ipairs(corners) do
		lantern(parent, "CornerLantern" .. i, p)
	end

	-- Central plaza: cobblestone square
	makePart({
		name = "Plaza", parent = parent,
		size = Vector3.new(90, 1, 90),
		position = center + Vector3.new(0, 0.5, 0),
		color = COBBLE, material = Enum.Material.Cobblestone,
	})

	-- Fountain: outer basin, water, centerpiece
	makePart({
		name = "FountainRim", parent = parent, size = Vector3.new(22, 3, 22),
		position = center + Vector3.new(0, 1.5, 0),
		color = STONE_TRIM, material = Enum.Material.Slate,
	})
	makePart({
		name = "FountainWater", parent = parent, size = Vector3.new(18, 1.2, 18),
		position = center + Vector3.new(0, 2.6, 0),
		color = WATER, material = Enum.Material.Water, transparency = 0.35,
	})
	makePart({
		name = "FountainCenterpiece", parent = parent, size = Vector3.new(3, 6, 3),
		position = center + Vector3.new(0, 6, 0),
		color = STONE_DARK, material = Enum.Material.Slate,
	})
	local topStone = makePart({
		name = "FountainTop", parent = parent, size = Vector3.new(5, 2, 5),
		position = center + Vector3.new(0, 9.5, 0),
		color = STONE_DARK, material = Enum.Material.Slate,
	})
	-- Floating banner above the fountain
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 320, 0, 80)
	gui.StudsOffset = Vector3.new(0, 10, 0)
	gui.MaxDistance = 220
	gui.Parent = topStone
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = Color3.fromRGB(255, 240, 200)
	lbl.TextStrokeTransparency = 0
	lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamBlack
	lbl.Text = "FREEPORT\nCity of New Beginnings"
	lbl.Parent = gui

	-- Spawn obelisk, moved to the south side of the plaza so the fountain is the focal point.
	local obelisk = makePart({
		name = "SpawnObelisk", parent = parent, size = Vector3.new(4, 14, 4),
		position = center + Vector3.new(0, 7, -35),
		color = Color3.fromRGB(80, 90, 120), material = Enum.Material.Marble,
	})
	local og = Instance.new("BillboardGui")
	og.Size = UDim2.new(0, 240, 0, 50)
	og.StudsOffset = Vector3.new(0, 10, 0)
	og.MaxDistance = 180
	og.Parent = obelisk
	local olbl = Instance.new("TextLabel")
	olbl.Size = UDim2.fromScale(1, 1)
	olbl.BackgroundTransparency = 1
	olbl.TextColor3 = Color3.fromRGB(220, 230, 255)
	olbl.TextStrokeTransparency = 0
	olbl.TextScaled = true
	olbl.Font = Enum.Font.GothamSemibold
	olbl.Text = "Bind Point"
	olbl.Parent = og

	-- Buildings around the plaza.
	-- West row
	building(parent, "Bank", center + Vector3.new(-80, 0, 50), Vector3.new(30, 20, 25), "+x")
	building(parent, "Inn", center + Vector3.new(-80, 0, 0), Vector3.new(30, 18, 25), "+x")
	building(parent, "Smithy", center + Vector3.new(-80, 0, -50), Vector3.new(30, 16, 25), "+x")
	-- East row
	building(parent, "Temple", center + Vector3.new(80, 0, 50), Vector3.new(30, 24, 30), "-x")
	building(parent, "Guildhall", center + Vector3.new(80, 0, 0), Vector3.new(30, 20, 25), "-x")
	building(parent, "Merchant", center + Vector3.new(80, 0, -50), Vector3.new(30, 18, 25), "-x")
	-- South
	building(parent, "Barracks", center + Vector3.new(-40, 0, -110), Vector3.new(40, 18, 25), "+z")
	building(parent, "Library", center + Vector3.new(40, 0, -110), Vector3.new(40, 18, 25), "+z")

	-- Paths from plaza to the gate and to the side buildings
	local function path(x1, z1, x2, z2)
		local mid = Vector3.new((x1 + x2) / 2, cy + 0.2, (z1 + z2) / 2)
		local dx, dz = x2 - x1, z2 - z1
		local len = math.sqrt(dx * dx + dz * dz)
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = Vector3.new(6, 0.4, len)
		p.CFrame = CFrame.lookAt(mid, Vector3.new(x2, mid.Y, z2))
		p.Color = COBBLE
		p.Material = Enum.Material.Cobblestone
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = parent
	end
	path(cx, cz + 45, cx, cz + 150)  -- plaza to gate
	path(cx - 45, cz, cx - 65, cz)   -- plaza to west row
	path(cx + 45, cz, cx + 65, cz)   -- plaza to east row
	path(cx, cz - 45, cx, cz - 110)  -- plaza to south row

	-- A few stone benches around the fountain
	for i = 0, 3 do
		local angle = i * math.pi / 2 + math.pi / 4
		local r = 18
		makePart({
			name = "Bench" .. i, parent = parent, size = Vector3.new(6, 1.2, 1.8),
			cframe = CFrame.new(center + Vector3.new(math.cos(angle) * r, 1, math.sin(angle) * r))
				* CFrame.Angles(0, angle + math.pi / 2, 0),
			color = STONE_TRIM, material = Enum.Material.Slate,
		})
	end
end

local world = Instance.new("Folder")
world.Name = "DragonsOfFreeportWorld"
world.Parent = workspace

for _, zone in ipairs(ZoneConfig.Zones) do
	makeZonePad(zone, world)
end

buildFreeport(world)

-- Connect zones with simple road strips so players can see paths.
local function road(a, b)
	local mid = (a + b) / 2
	local diff = b - a
	local len = diff.Magnitude
	local part = Instance.new("Part")
	part.Anchored = true
	part.Size = Vector3.new(10, 0.4, len)
	part.CFrame = CFrame.lookAt(mid, b)
	part.Color = SAND
	part.Material = Enum.Material.Sand
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = world
end

local zoneById = {}
for _, z in ipairs(ZoneConfig.Zones) do zoneById[z.id] = z end

local edges = {
	{ "freeport", "outskirts" },
}
for _, e in ipairs(edges) do
	local a, b = zoneById[e[1]], zoneById[e[2]]
	if a and b then road(a.center, b.center) end
end
