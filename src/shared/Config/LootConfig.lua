local LootConfig = {}

-- Each entry: { itemId, weight, minQty, maxQty }
-- Tables are sampled with weighted random; multiple rolls per kill.

LootConfig.Tables = {
	low_critter = {
		rolls = { min = 1, max = 2 },
		entries = {
			{ "gold_coin", 100, 1, 5 },
			{ "minor_health_potion", 25, 1, 1 },
			{ "rusty_sword", 5, 1, 1 },
			{ "cloth_tunic", 5, 1, 1 },
		},
	},
	mid_humanoid = {
		rolls = { min = 1, max = 3 },
		entries = {
			{ "gold_coin", 100, 5, 20 },
			{ "health_potion", 30, 1, 2 },
			{ "bronze_sword", 12, 1, 1 },
			{ "iron_sword", 6, 1, 1 },
			{ "leather_vest", 10, 1, 1 },
			{ "chainmail", 5, 1, 1 },
		},
	},
	elite = {
		rolls = { min = 2, max = 4 },
		entries = {
			{ "gold_coin", 100, 25, 80 },
			{ "health_potion", 50, 2, 4 },
			{ "steel_blade", 12, 1, 1 },
			{ "plate_armor", 10, 1, 1 },
			{ "mithril_edge", 4, 1, 1 },
		},
	},
	dragon_hoard = {
		rolls = { min = 4, max = 6 },
		entries = {
			{ "gold_coin", 100, 500, 1500 },
			{ "dragon_heart", 100, 1, 1 },
			{ "dragonbane", 35, 1, 1 },
			{ "dragon_scale_mail", 35, 1, 1 },
			{ "mithril_edge", 60, 1, 1 },
			{ "health_potion", 100, 5, 10 },
		},
	},
}

local function totalWeight(entries)
	local t = 0
	for _, e in ipairs(entries) do
		t = t + e[2]
	end
	return t
end

function LootConfig.Roll(tableId, rng)
	local tbl = LootConfig.Tables[tableId]
	if not tbl then
		return {}
	end
	rng = rng or Random.new()
	local rolls = rng:NextInteger(tbl.rolls.min, tbl.rolls.max)
	local total = totalWeight(tbl.entries)
	local result = {}
	for _ = 1, rolls do
		local pick = rng:NextNumber() * total
		local accum = 0
		for _, entry in ipairs(tbl.entries) do
			accum = accum + entry[2]
			if pick <= accum then
				local qty = rng:NextInteger(entry[3], entry[4])
				table.insert(result, { id = entry[1], qty = qty })
				break
			end
		end
	end
	return result
end

return LootConfig
