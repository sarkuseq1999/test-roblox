local ItemConfig = {}

ItemConfig.Items = {
	rusty_sword = {
		name = "Rusty Sword",
		slot = "Weapon",
		rarity = "Common",
		stats = { Damage = 4 },
		levelReq = 1,
	},
	bronze_sword = {
		name = "Bronze Sword",
		slot = "Weapon",
		rarity = "Common",
		stats = { Damage = 9 },
		levelReq = 5,
	},
	iron_sword = {
		name = "Iron Sword",
		slot = "Weapon",
		rarity = "Uncommon",
		stats = { Damage = 16 },
		levelReq = 12,
	},
	steel_blade = {
		name = "Steel Blade",
		slot = "Weapon",
		rarity = "Rare",
		stats = { Damage = 28 },
		levelReq = 22,
	},
	mithril_edge = {
		name = "Mithril Edge",
		slot = "Weapon",
		rarity = "Epic",
		stats = { Damage = 44 },
		levelReq = 35,
	},
	dragonbane = {
		name = "Dragonbane",
		slot = "Weapon",
		rarity = "Legendary",
		stats = { Damage = 75, Strength = 10 },
		levelReq = 48,
	},

	cloth_tunic = {
		name = "Cloth Tunic",
		slot = "Chest",
		rarity = "Common",
		stats = { Armor = 3 },
		levelReq = 1,
	},
	leather_vest = {
		name = "Leather Vest",
		slot = "Chest",
		rarity = "Common",
		stats = { Armor = 8 },
		levelReq = 6,
	},
	chainmail = {
		name = "Chainmail",
		slot = "Chest",
		rarity = "Uncommon",
		stats = { Armor = 18 },
		levelReq = 15,
	},
	plate_armor = {
		name = "Plate Armor",
		slot = "Chest",
		rarity = "Rare",
		stats = { Armor = 32 },
		levelReq = 28,
	},
	dragon_scale_mail = {
		name = "Dragon Scale Mail",
		slot = "Chest",
		rarity = "Legendary",
		stats = { Armor = 60, Stamina = 8 },
		levelReq = 48,
	},

	minor_health_potion = {
		name = "Minor Health Potion",
		slot = "Consumable",
		rarity = "Common",
		stackable = true,
		consume = { Heal = 50 },
	},
	health_potion = {
		name = "Health Potion",
		slot = "Consumable",
		rarity = "Uncommon",
		stackable = true,
		consume = { Heal = 200 },
	},
	dragon_heart = {
		name = "Dragon Heart",
		slot = "Quest",
		rarity = "Legendary",
		stackable = false,
	},
	gold_coin = {
		name = "Gold Coin",
		slot = "Currency",
		rarity = "Common",
		stackable = true,
	},
}

function ItemConfig.Get(id)
	return ItemConfig.Items[id]
end

return ItemConfig
