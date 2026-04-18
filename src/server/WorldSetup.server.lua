-- Builds Freeport (safe city) plus terrain pads for each adventuring zone.
-- Geometry is intentionally minimal — meant to be replaced by real assets,
-- but already gives a navigable, readable layout.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ZoneConfig = require(Shared.Config.ZoneConfig)

local function makePart(name, parent, color, size, position, material, anchored)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = position
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = anchored ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
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
	makePart(zone.id .. "_floor", parent, color, Vector3.new(zone.size.X, 2, zone.size.Z), zone.center - Vector3.new(0, 1, 0), Enum.Material.Grass)

	local sign = Instance.new("Part")
	sign.Name = zone.id .. "_sign"
	sign.Size = Vector3.new(8, 12, 1)
	sign.Position = zone.center + Vector3.new(0, 6, -zone.size.Z / 2 + 4)
	sign.Anchored = true
	sign.Color = Color3.fromRGB(80, 60, 40)
	sign.Parent = parent

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 320, 0, 80)
	gui.StudsOffset = Vector3.new(0, 8, 0)
	gui.AlwaysOnTop = true
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

local function buildFreeport(parent)
	local center = ZoneConfig.GetById("freeport").center

	-- Outer wall: ring with a 30-stud gap on the north side facing the outskirts.
	local wallColor = Color3.fromRGB(160, 150, 130)
	makePart("WallS", parent, wallColor, Vector3.new(300, 30, 4), center + Vector3.new(0, 15, -150), Enum.Material.Concrete)
	makePart("WallE", parent, wallColor, Vector3.new(4, 30, 300), center + Vector3.new(150, 15, 0), Enum.Material.Concrete)
	makePart("WallW", parent, wallColor, Vector3.new(4, 30, 300), center + Vector3.new(-150, 15, 0), Enum.Material.Concrete)
	-- North wall in two segments framing a gate.
	makePart("WallNL", parent, wallColor, Vector3.new(135, 30, 4), center + Vector3.new(-82.5, 15, 150), Enum.Material.Concrete)
	makePart("WallNR", parent, wallColor, Vector3.new(135, 30, 4), center + Vector3.new(82.5, 15, 150), Enum.Material.Concrete)
	makePart("GateArch", parent, Color3.fromRGB(120, 100, 80), Vector3.new(30, 6, 4), center + Vector3.new(0, 27, 150), Enum.Material.Wood)

	-- Town square.
	makePart("Square", parent, Color3.fromRGB(180, 170, 150), Vector3.new(60, 1, 60), center + Vector3.new(0, 0.5, 0), Enum.Material.Cobblestone)

	-- Spawn obelisk.
	local obelisk = makePart("SpawnObelisk", parent, Color3.fromRGB(80, 90, 120), Vector3.new(6, 18, 6), center + Vector3.new(0, 9, 0), Enum.Material.Marble)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 300, 0, 80)
	gui.StudsOffset = Vector3.new(0, 12, 0)
	gui.AlwaysOnTop = true
	gui.Parent = obelisk
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = Color3.fromRGB(255, 240, 200)
	lbl.TextStrokeTransparency = 0
	lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamBlack
	lbl.Text = "FREEPORT\nCity of New Beginnings"
	lbl.Parent = gui

	-- A few buildings as silhouettes.
	for i = 1, 4 do
		local angle = (i - 1) * (math.pi / 2) + math.pi / 4
		local pos = center + Vector3.new(math.cos(angle) * 60, 8, math.sin(angle) * 60)
		makePart("Building" .. i, parent, Color3.fromRGB(140, 110, 80), Vector3.new(20, 16, 20), pos, Enum.Material.Wood)
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
local function road(a, b, color)
	local mid = (a + b) / 2
	local diff = b - a
	local len = diff.Magnitude
	local part = Instance.new("Part")
	part.Anchored = true
	part.Size = Vector3.new(8, 0.5, len)
	part.CFrame = CFrame.lookAt(mid, b) * CFrame.new(0, 0, 0)
	part.Color = color or Color3.fromRGB(170, 150, 110)
	part.Material = Enum.Material.Sand
	part.Parent = world
end

local zoneById = {}
for _, z in ipairs(ZoneConfig.Zones) do zoneById[z.id] = z end

local edges = {
	{"freeport", "outskirts"},
	{"outskirts", "highwayman_road"},
	{"highwayman_road", "orc_hills"},
	{"orc_hills", "bone_crypt"},
	{"bone_crypt", "ember_caves"},
	{"ember_caves", "dragons_reach"},
	{"dragons_reach", "vexrothan_lair"},
}
for _, e in ipairs(edges) do
	road(zoneById[e[1]].center, zoneById[e[2]].center)
end
