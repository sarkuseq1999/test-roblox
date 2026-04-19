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
