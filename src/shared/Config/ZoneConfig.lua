local ZoneConfig = {}

-- Each zone: name, center, size, levelRange, spawns = { { monsterId, count } }
ZoneConfig.Zones = {
	{
		id = "freeport",
		name = "Freeport",
		center = Vector3.new(0, 5, 0),
		size = Vector3.new(300, 1, 300),
		levelRange = { 1, 1 },
		isSafe = true,
		spawns = {},
	},
	{
		id = "outskirts",
		name = "Freeport Outskirts",
		center = Vector3.new(0, 5, 400),
		size = Vector3.new(400, 1, 400),
		levelRange = { 1, 8 },
		spawns = {
			{ "giant_rat", 8 },
			{ "wild_boar", 5 },
		},
	},
	{
		id = "highwayman_road",
		name = "Highwayman's Road",
		center = Vector3.new(500, 5, 400),
		size = Vector3.new(400, 1, 400),
		levelRange = { 8, 16 },
		spawns = {
			{ "bandit", 8 },
			{ "wild_boar", 4 },
		},
	},
	{
		id = "orc_hills",
		name = "Greenscar Hills",
		center = Vector3.new(900, 5, 0),
		size = Vector3.new(500, 1, 500),
		levelRange = { 16, 25 },
		spawns = {
			{ "orc_warrior", 10 },
		},
	},
	{
		id = "bone_crypt",
		name = "Bone Crypt",
		center = Vector3.new(900, 5, -600),
		size = Vector3.new(400, 1, 400),
		levelRange = { 25, 33 },
		spawns = {
			{ "skeletal_knight", 8 },
		},
	},
	{
		id = "ember_caves",
		name = "Ember Caves",
		center = Vector3.new(300, 5, -800),
		size = Vector3.new(500, 1, 500),
		levelRange = { 33, 42 },
		spawns = {
			{ "dragon_whelp", 6 },
		},
	},
	{
		id = "dragons_reach",
		name = "Dragon's Reach",
		center = Vector3.new(-400, 5, -900),
		size = Vector3.new(600, 1, 600),
		levelRange = { 42, 49 },
		spawns = {
			{ "fire_drake", 5 },
		},
	},
	{
		id = "vexrothan_lair",
		name = "Vexrothan's Lair",
		center = Vector3.new(-1100, 5, -1100),
		size = Vector3.new(500, 1, 500),
		levelRange = { 50, 50 },
		isRaidZone = true,
		spawns = {},
	},
}

ZoneConfig.FreeportSpawn = Vector3.new(0, 10, 0)

function ZoneConfig.GetById(id)
	for _, z in ipairs(ZoneConfig.Zones) do
		if z.id == id then
			return z
		end
	end
end

return ZoneConfig
