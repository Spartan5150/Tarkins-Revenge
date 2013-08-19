--Automatically generated by SWGEmu Spawn Tool v0.12 loot editor.

rifle_bowcaster = {
	minimumLevel = 0,
	maximumLevel = -1,
	customObjectName = "",
	directObjectTemplate = "object/weapon/ranged/rifle/rifle_bowcaster.iff",
	craftingValues = {
		{"mindamage",61,122,0},
		{"maxdamage",124,217,0},
		{"attackspeed",9.6,6.2,0},
		{"woundchance",6.4,15.6,0},
		{"hitpoints",750,750,0},
		{"attackhealthcost",46,23,0},
		{"attackactioncost",46,23,0},
		{"attackmindcost",57,35,0},
	},
	customizationStringNames = {},
	customizationValues = {},

	-- dotChance: The chance of this weapon object dropping with a dot on it. Higher number means less chance. Set to 0 for static.
	dotChance = 10,

	-- dotType: 1 = Poison, 2 = Disease, 3 = Fire, 4 = Bleed, 5 = Random
	dotType = 5,

	-- dotValues: Object map that can randomly or statically generate a dot (used for weapon objects.)
	dotValues = {
		{"attribute", 0, 8}, -- See CreatureAttributes.h in src for numbers.
		{"strength", 10, 200}, -- Random type: set for disease. Fire will be x1.5, poison x2.
		{"duration", 30, 240}, -- Random type: set for poison. Fire will be x1.5, disease x5.
		{"potency", 1, 100},
		{"uses", 250, 9999}
	}

}

addLootItemTemplate("rifle_bowcaster", rifle_bowcaster)
