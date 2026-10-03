# Reef Rush

An ocean-themed collect → cash in → upgrade game for Roblox (low-poly blocky style).

## How it plays
- Swim near glowing **coral** to collect shells into your satchel (capacity-limited).
- Cash in shells for **coins** at the **Dive Station** (hub).
- Spend coins at the **Reef Shop** (or the side menu) on:
  - **Eggs** → hatch sea creatures that follow you and auto-collect shells
  - **Upgrades** → satchel capacity, collection power, swim speed, creature slots
  - **Zones** → Sunny Shallows (free), Kelp Forest, Deep Trench (richer coral)
- **Captain Finn** (hub NPC) gives an endless chain of quests with coin rewards; the HUD tracks the active one.
- **Buff bubbles** float around the zones: Swift Current (+50% speed), Shell Frenzy (x2 collection), Pearl Burst (instant coins).
- **Ascend**: reset for a Pearl that permanently boosts cash-in coins (+25% each).
- Progress (coins, shells, upgrades, zones, creatures) saves with DataStore.

## Setup
1. Install [Rojo](https://rojo.space) and the Rojo Studio plugin.
2. In this folder run `rojo serve`, open a new Baseplate place in Studio and click **Connect**.
3. In Studio: *Game Settings → Security → Enable Studio Access to API Services* (needed for saving while testing).
4. Press Play.

## Build a place file
`rojo build -o ReefRush.rbxl` then open it in Studio (or publish it via Open Cloud).

## Layout
- `src/shared/Config.lua` – zones, creatures, eggs, upgrades (tune the economy here)
- `src/server/Data.lua` – DataStore load/save and attribute replication
- `src/server/World.lua` – builds the map, coral nodes, Dive Station, Reef Shop
- `src/server/Quests.lua`, `Buffs.lua`, `Remotes.lua` – quest progression, buff bubbles, remotes/notify
- `src/server/Game.server.lua` – collection loops, cash-in, shop, teleports
- `src/client/Main.client.lua` – HUD, menu, creature visuals, pickup popups
