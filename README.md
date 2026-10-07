# Deep Mine

Solo-first Roblox mining progression game. See `CLAUDE.md` for the full design.

**Status:** Phases 1–5 are done. All five mines are playable end to end: Abandoned Coal Mine → Crystal
Caverns → Lava Depths → Ancient Depths → Unknown Depths. Each has its own objectives and ascension, and the
game ends at the Last Seal with the Heart of the Deep. Phase 6 (replayability) is done: achievements, the Journal
(per-mine completion, collection, overall %) and random events. Phase 7 (polish) is done: a procedural
swing, ore chunks that fly to the player, camera shake, creature legs and outlines, cave motes, onboarding
hints, a Settings menu and a performance pass. Phase 8 is done: prestige ("Collapse the Mines") as the endgame
loop, plus optional monetization (game passes, timed boosts and pickaxe skins). Next: the Endless Abyss
(procedural Mine 6) and daily rewards are now in too.

## Workflow

Source of truth is `src/`. Studio is the runtime. The bridge talks to Roblox Studio through
its built-in MCP server (`StudioMCP.exe`, run through Vinegar/Wine).

```sh
python3 tools/studio.py sync                       # push src/ into the open place
python3 tools/studio.py build                      # (re)build the whole map
```

`build` runs `tools/build/{lib,world,mine1..mine5,camp}.luau` as one chunk (lib holds the shared
helpers). It wipes and regenerates `Workspace.Camp`, `Workspace.Mines` and terrain from a fixed seed.
Don't hand-edit those in Studio. Change the builders instead, or the edits will be lost.

File mapping (`src/` → DataModel): `X.luau` = ModuleScript, `X.server.luau` = Script,
`X.client.luau` = LocalScript, folders = Folders.

## Layout

```
src/
  ReplicatedStorage/Shared/
    Config/       Resources, Equipment (pickaxes/backpacks), Mines (zones/gates/requirements/lifts/lighting), Sounds, GameConfig
    Util/         Signal, Format, Targets (resolve ore/gate from a part, reach check), ZoneLocator
    Progress.luau mine completion objectives + lift unlock rules (shared by server and client)
    Remotes.luau  all RemoteEvents/Functions (server creates, client waits)
  ServerScriptService/Server/
    Main.server.luau        boots services in order
    Services/
      DataService           DataStore load/save, session locking, autosave, BindToClose
      StateService          pushes player state snapshots to the client
      InventoryService      backpack add / sell
      OreService            spawns ore nodes on map spawn points, respawns them
      GateService           per-player rubble gates between zones
      MiningService         validates every swing (reach, cooldown, tool, hardness, zone, space)
      ShopService           sell prompt, upgrade bench prompt, Purchase remote
      ToolService           builds the pickaxe Tool per tier, headlamp
      ProgressService       records zones reached / mines visited from character position
      AscensionService      Sealed Wall prompt (checks objectives), portal to the next mine
      TravelService         lifts + teleports with client screen fades
      DrillService          drill ticks, heat/overheat, splash damage (reuses MiningService.HitOre)
      HazardService         damage inside "Hazard"-tagged volumes unless the suit protects
      ArtifactService       artifact pedestals (tag "Artifact"): one-time pickup, reward, saved collection
      MechanismService      glyph plates (tag "Glyph") that open Mechanism doors when all are pressed
      CreatureService       hostile creatures (tag "Creature"): wander/aggro/chase/bite AI, damage, rewards, respawn
      AchievementService    awards Config/Achievements on data changes (retroactive), pays rewards
      EventService          random events every 5-9 min: Meteorite Strike, Rich Seam, Ore Frenzy, Lucky Hour
      SettingsService       validates and saves per-player client settings
      DebugService          Studio-only BindableFunction ServerStorage.DeepMineDebug
  StarterPlayer/StarterPlayerScripts/Client/
    Main.client.luau
    Controllers/  State, Mining (input/targeting/feedback), Effects, Sound, Gate, Zone (banners/ambience/lighting),
                  Ascension (wall-breaking sequence), Travel (fades, arrival intros),
                  Drill (hold-to-drill, heat bar), Dark (hides ore in dark zones), Hazard (warnings),
                  Relic (artifact visibility + discovery card, glyph lighting), Creature (alerts/bites)
    UI/Ending.luau  final "bottom of the world" screen
    UI/Journal.luau mines / collection / achievements + game completion % (J or Y)
    Controllers/EventController  event banners, HUD event timer, achievement pop-ups
    Controllers/CameraShake      impact shakes through Humanoid.CameraOffset (respects settings)
    UI/Settings.luau, UI/Hints.luau  settings menu (volume buses, toggles) and onboarding tips
    UI/           Theme, Hud, Shop, Toasts, Objectives (mine progress panel), LiftMenu
tools/
  studio.py          sync/run bridge
  build/            map builders (lib, world, mine1, mine2, camp)
```

## Design notes

- **Server authority.** The client only sends "I swung at this instance". Rewards, currency,
  upgrades and gates are decided on the server. Purchases also require being at the bench.
- **Progression gates.** Each pickaxe has a `Hardness`. Copper needs 2 and iron needs 3. The rubble
  gates between zones need the same hardness, so a new pickaxe physically opens the next area.
  Gates are per-player and saved, and the client hides the gates you've broken.
- **Data.** Saved as `{ Data, Lock }`. The lock prevents two servers writing the same player.
  A lock older than 10 min is treated as stale. Without DataStore access (Studio API access off),
  the game still runs and the HUD shows a "not saving" warning.
- **Lighting.** Caves don't rely on shadows to be dark, because many devices render without them.
  `ZoneController` turns off sun and sky light underground, so lanterns and the headlamp do the lighting.
- **Hidden chambers** are gates with `Hidden = true` (Config/Mines). They look like plain rock at the
  end of a dead-end crawl, and breaking one plays a discovery banner.
- **Rich veins.** Each zone has a `RichChance`. A rich node sparkles, has 1.6x health and yields 3 units.
- **Decorative crystals** are non-colliding and click-through, so they never trap players or block
  clicks on ore behind them.
- **Equipment categories** (Config/Equipment): Pickaxe, Backpack and Lamp start at tier 1. Suit and Drill
  start at 0, meaning not owned. Items can have `Requires` (a pickaxe tier or a visited mine). The shop is
  generic over the categories.
- **Dark zones.** A zone's `Dark = n` means you need lamp tier n to see its ore (the client hides it)
  and to mine it (the server rejects with `TooDark`).
- **Hazards.** Builders place parts tagged `Hazard` with Type/Level/DamagePerSecond attributes. The Heat
  Suit stays locked until the Lava Depths (Mine 3) exists.
- **Artifacts** (Config/Artifacts) are unique pickups, one or more per mine, saved in `data.Artifacts`.
  The HUD shows the collection count, and a mine can require some of them (`Type = "Artifacts"`).
- **Mechanisms.** A gate with `Mechanism = true` can't be mined. `Mines.Mechanisms[door]` lists its
  glyphs, and pressing all of them opens the door for that player (saved in `data.Gates`).
- **Creatures** (Config/Creatures) are anchored models the server steps at 10 Hz along the terrain,
  so they stay out of the physics engine. Pickaxe and drill hits on them go through CreatureService:Damage.
  They never follow players into the `Final`/`Heart` zones, so the seal hall is safe. Kills count
  towards the `CreaturesDefeated` stat, which Mine 5 requires (`Type = "Stat"`).
- **The ending.** A mine with `Ending = true` has no next mine. Completing it plays the wall sequence,
  then the client's Ending screen. The Heart of the Deep artifact has `RequiresCompleted = "Mine5"`.
- **Achievements** are data-driven (`Progress(data) -> current, target`). The same functions drive the
  server award and the Journal progress bars. `Shared/Completion.luau` computes mine and game completion %.
- **Random events** publish timed modifiers as ReplicatedStorage attributes (`SellMultiplier`,
  `RichMultiplier`, `EventName`, `EventEnds`). Only one event runs at a time.
- **Swing animation** is procedural. MiningController rotates the right shoulder's `Motor6D.Transform`
  in `PreSimulation`, after the Animator has run, so no animation assets need uploading. Other players
  don't see it.
- **Sound buses.** Every sound goes through the `SFX` or `Ambience` SoundGroup, and the Settings menu
  controls their volumes.
- **Performance.** About 4.2k map parts and about 190 lights, and only about 11 lights cast shadows
  (lanterns and braziers don't).
- **Replayability hook.** Ore spawn points outnumber live ores about 2:1, and the resource on
  each one is rolled from the zone's weights every time, so every trip looks different.
- **Ascension.** Each mine lists `Requirements` in `Config/Mines`. The Sealed Wall's prompt checks them
  on the server and marks the mine `Completed`. The client then plays the wall-breaking sequence, and
  the portal behind the wall takes you to the next mine's `Arrival` point. Like gates, the wall is
  per-player.
- **Mines are one place.** Each mine sits deeper than the last in the same place (Mine 2 around y=-260,
  Mine 3 around y=-530), so travel is a server-side teleport and data stays in one DataStore.
  `Workspace.FallenPartsDestroyHeight` is set to -5000 by the world builder; the default -500 would
  kill players in Mine 3.

## Prestige and monetization

- **Prestige.** After the final mine is completed, the camp obelisk ("The Deep Calls") or the ending
  screen opens the prestige dialog. Prestige resets cash, the backpack, every gear tier, gates and mine
  completion. Artifacts, achievements, stats, skins, passes, boosts and settings are kept. Each level
  multiplies sell value by 1.25 and mining power by 1.1, and gear prices by 1.4. After a prestige,
  "mine N ore" objectives count `RunMined` (this run only) rather than lifetime stats.
  Prestige skins unlock at levels 1/3/5/10.
- **All multipliers live in `Shared/Modifiers.luau`** (prestige × pass × boost × event), used by the
  server for authority and the client for display.
- **Robux items.** Game passes are VIP Miner, Remote Seller, Big Pockets and Lucky Miner
  (`Config/Store.luau`). Developer Products are three 15-minute boosts (buying again adds time) and
  three premium skins (`Config/Skins.luau`). Cash skins are bought with in-game money through a
  validated remote. `StoreService` handles `ProcessReceipt` idempotently: receipt ids are saved in
  `data.Purchases`, the save is forced, and only then is `PurchaseGranted` returned.
- **Setting up the ids.** On the Creator Dashboard (experience, then Monetization), create the 4 Game
  Passes and 6 Developer Products, then paste each id into `GamePassId` / `ProductId` in
  `Config/Store.luau` and `Config/Skins.luau`. Until then those items show "Coming soon". Prices are
  read from the dashboard, so set them there. Once real ids exist, Studio test purchases don't charge
  Robux.

## Endless Abyss and daily rewards

- **Endless Abyss** (`Config/Abyss.luau`, `AbyssService`). It unlocks after completing Mine 5 (or any
  prestige) and you reach it from the camp lift. Each player gets private, generated floors in a
  slot far below the map (x≥6000, y≈-2600). Each slot has two levels, so the next floor is built
  before the old one is removed. A floor is a random walk of 4–8 terrain chambers joined by
  tunnels, lit by crystals, with one-off ore owned by that player. Mining 60% of it opens the
  Descent Shaft in the last chamber.
  - Bands set the ore and look, and gate progress by gear: Heat Suit from floor 11, Magma Suit from 16,
    Void Suit and creatures from 21, Abyss Suit from 31, repeating forever.
  - Rock health, units per break and creature health grow with depth.
  - `data.Abyss.Best` is the record. Every new record pays a bonus, and runs start at the last
    checkpoint (every 5 floors).
  - Leaving: the Exit Rope by the start, or dying (both remove the floor).
  - Run state reaches the HUD through player attributes (`AbyssFloor`, `AbyssMined`, `AbyssQuota`,
    `AbyssOpen`).
- **Daily rewards** (`Config/Daily.luau`, `DailyService`) use a 7-day looping streak by UTC day,
  judged by the server clock. Cash scales with mines completed (or prestige). Days 3, 5 and 7 add a
  short free boost. The calendar opens on join when a reward is waiting.

## Controls

| Action | Keyboard | Gamepad |
|---|---|---|
| Journal | J | Y |
| Store | B | D-pad up |
| Settings | (gear button) | D-pad down |
| Remote Sell (pass) | G | D-pad left |
| Daily rewards | (DAILY button) | D-pad right |
| Close any window | Esc | B |

## Hardening

- Every client-callable remote validates types, ownership, distance and prices on the server.
- `Server/Util/RateLimit.luau` throttles the store, shop, lift and prestige remotes per player.
- Settings reject NaN, which would break DataStore saves.
- If another server takes over a player's session lock, this server stops saving and kicks the
  player instead of silently dropping progress.
- A Robux receipt is only reported as granted after the save succeeds. Otherwise Roblox retries, and
  the stored receipt id prevents a double grant.

## Testing in Studio

From the server command bar during a playtest (Studio only):
`ServerStorage.DeepMineDebug:Invoke(cmd, ...)` with `Get`, `SetCash n`, `Reset`, `SetMined "Iron" n`,
`SetTier p b`, `SetEquip "LampTier" n`, `SetGate "Id" true`, `SetStat "CreaturesDefeated" n`, `Event "Meteorite"|"RichSeam"|"OreFrenzy"|"LuckyHour"`, `OpenGates`, `SetMineDone "Mine5" true`, `SetPrestige n`,
`SetAbyssBest n`, `AbyssOpen` (opens the current shaft), `SetDaily streak daysAgo`,
`GrantPass "VIP" [false]`, `GrantProduct "MiningFrenzy"|"VoidReaper" ["receiptId"]` (same grant path as a real
receipt; reuse a receipt id to check it isn't granted twice), `Snapshot` / `Restore`. Use `Snapshot` and `Restore` before destructive
tests on a real save.
