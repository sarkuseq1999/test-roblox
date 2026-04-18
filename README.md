# Dragons of Freeport

An EverQuest-inspired Roblox RPG. Players are born in the city of **Freeport**,
team up to fight monsters, collect loot, level up from **1 to 50**, and form
**raids** to bring down dragons. Currently supports **one race: Human**.

## Build & run

This project uses [Rojo](https://rojo.space) to sync filesystem source into
Roblox Studio.

```bash
rojo serve default.project.json
```

Then in Studio: install the Rojo plugin, click **Connect**, hit **Play**.

To build a place file directly:

```bash
rojo build default.project.json -o DragonsOfFreeport.rbxlx
```

## Project layout

```
src/
  shared/                     ReplicatedStorage.Shared (ModuleScripts)
    Config/
      LevelConfig.lua         XP curve + per-level stats (1..50)
      ItemConfig.lua          Items: weapons, armor, potions, dragon loot
      LootConfig.lua          Weighted loot tables
      MonsterConfig.lua       Monsters from giant rats to Vexrothan
      ZoneConfig.lua          Zones, level ranges, spawn lists
    CombatMath.lua            Damage / XP scaling / group-share math
    Remotes.lua               Centralized RemoteEvent / RemoteFunction registry
  server/                     ServerScriptService.Server (Scripts)
    PlayerDataService         Profiles, persistence, XP, inventory
    MonsterService            Monster rigs + AI + spawns + kill rewards
    CombatService             Validates player attacks
    PartyService              Party (1–6) + Raid (up to 4 parties = 24)
    DragonBossService         Vexrothan three-phase raid encounter
    WorldSetup                Builds Freeport + zone pads + roads
  client/                     StarterPlayerScripts.Client (LocalScripts)
    HUD                       Character panel, XP bar, notifications, boss bar
    InventoryUI               Inventory + equip / consume (toggle: I)
    PartyUI                   Party roster + invite popups (toggle: P)
    CombatClient              Click monsters to attack
```

## Gameplay loop

1. Spawn at the **Freeport** obelisk in the city's town square.
2. Walk through the north gate to the **Freeport Outskirts** (lvl 1–8).
   Click on rats and boars to attack.
3. Loot drops automatically into your inventory (`I`). Equip weapons & armor.
4. Form a party (`P`, invite by name) — XP & loot are shared with a small
   group bonus.
5. Progress through the zone chain:
   - Outskirts (1–8) → Highwayman's Road (8–16) → Greenscar Hills (16–25)
     → Bone Crypt (25–33) → Ember Caves (33–42) → Dragon's Reach (42–49)
     → **Vexrothan's Lair** (50, raid).
6. At 50, party leaders type `/joinraid <id>` in chat to combine into a raid
   of up to 24. The raid leader steps onto the activation pad in
   Vexrothan's Lair to start the three-phase fight.

## Controls

| Key | Action |
|-----|--------|
| Click | Attack target |
| I | Toggle inventory |
| P | Toggle party panel |
| Chat: `/joinraid <id>` | Join an existing raid as a party leader |

## Extending

- **Add a monster:** entry in `src/shared/Config/MonsterConfig.lua`, then add
  it to a zone's `spawns` in `ZoneConfig.lua`.
- **Add an item:** entry in `ItemConfig.lua`; reference it from a loot table
  in `LootConfig.lua`.
- **Add a zone:** entry in `ZoneConfig.lua`; `WorldSetup` builds the pad and
  sign automatically.
- **Add a race:** the data layer already keys off `profile.race`. Add per-race
  stat modifiers in `LevelConfig.GetStatsForLevel` and an option at character
  creation.
