local LevelConfig = {}

LevelConfig.MaxLevel = 50

local xpTable = {}
for level = 1, LevelConfig.MaxLevel - 1 do
	xpTable[level] = math.floor(100 * level ^ 1.6 + 50 * level)
end
LevelConfig.XPToNext = xpTable

function LevelConfig.GetXPRequired(level)
	return xpTable[level] or math.huge
end

function LevelConfig.GetTotalXPForLevel(level)
	local total = 0
	for i = 1, level - 1 do
		total = total + (xpTable[i] or 0)
	end
	return total
end

LevelConfig.BaseStats = {
	MaxHP = 100,
	MaxMP = 50,
	Strength = 10,
	Stamina = 10,
	Intelligence = 10,
	Agility = 10,
}

LevelConfig.PerLevelStats = {
	MaxHP = 18,
	MaxMP = 8,
	Strength = 2,
	Stamina = 2,
	Intelligence = 1,
	Agility = 1,
}

function LevelConfig.GetStatsForLevel(level)
	local stats = {}
	for k, base in pairs(LevelConfig.BaseStats) do
		stats[k] = base + (LevelConfig.PerLevelStats[k] or 0) * (level - 1)
	end
	return stats
end

return LevelConfig
