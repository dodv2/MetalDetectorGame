# Handoff: Beach Detecting Simulator (Roblox)

Written 4 Nov 2026 for the next Claude session. The code lives in GitHub **dodv2/MetalDetectorGame** (branch `main`, one commit = the project as of Update 17). This file covers everything that is *not* obvious from the repo: history, decisions, the unbuilt Update 18+19 plan, known problems, and how the owner works.

---

## 0. The project in one paragraph

A coastal treasure-hunting simulator. The player sweeps 7 beaches with a metal detector, digs treasures out in a click-against-the-sand tug of war, collects them into a backpack, then sells them at the Pier or displays them in a personal treasure shop (displays give Shop Luck). Cash buys better detectors and shovels and unlocks the next beach. Rarities run Common → Uncommon → Rare → Epic → Legendary → Mythical → Secret. Inspired by *Mine a Mountain* (feel only, no copied assets). PC and mobile.

Owner: Roblox account **EvilAzrie**, UserId **98951116**, Windows PC, timezone Asia/Singapore.

---

## 1. Update history

The owner numbers sections of one long master spec 1–17. Code comments use older internal labels: "Update 2" = sections 1–12, "Update 3" = section 13, "Update 4" = sections 14–15, then "Update 16" and "Update 17".

| # | What it added |
|---|---|
| (base) | First full build: detectors, levels, rarity + Luck, personal treasure shop, equipment shop, 7 beaches, collection index, quests, achievements, leaderboards, DataStore saving with session locks. |
| 1 | Detector UI moved to a compact vertical panel on the right: small circular radar, distance in metres, signal strength, 5-level proximity gauge, minimisable. |
| 2 | Radar fixed: sweep and pulses centred, feedback strengthens as you close in, a clear "dig here" state; visual first, sound optional. |
| 3 | NPC shopkeepers with storefronts, floating names, face-the-player, idle animation (later cut to two shops in #11). |
| 4 | Backpack + bottom hotbar (icons, counts, rarity borders, "new" highlight) and backpack tiers (tiers later removed in #14). |
| 5 | Discovery presentation: dig animation, sand particles, reveal card with name/rarity/value, bigger effects for rarer finds. |
| 6 | General visual polish: beach, water, lighting, shops, models, particles, consistent UI. |
| 7 | Feel and progression polish: level-up animation, shop feedback, rare-find announcements. |
| 8 | Technical rules: server-authoritative generation, inventory, rewards; modular services/controllers; validated remotes. |
| 9 | "[E] Start Digging" prompt, left-click to dig, compact bar, 7 shovel tiers (rarity locks were later removed in #13). |
| 10 | Resistance-based digging: resistance by rarity and depth, progress decays when you stop clicking. |
| 11 | Only two physical NPC shops (Sell, Equipment), Return to Base teleport, one expandable ☰ menu, personal treasure shop with Shop Luck. |
| 12 | Quick Sell (rarity filters; never sells locked, favourited or displayed items) and Place Best Items (preview, swaps weaker displays back to the backpack). |
| 13 | Test-run fixes A–N: terrain fix, radar pinned, top HUD bar, any shovel digs any rarity, hidden resistance, dial UI, custom ProximityPrompt style, rounder models, sharks added, held-treasure info, **additive Luck**, menu cleanup, Treasure Shop teleport. |
| 14 | Refinements A–P: physical dig animation, bar with no numbers, no teleport cooldowns, **fixed 10-slot backpack**, coils merged into detectors, shop upgrades bought inside the personal shop, keyboard shortcuts and "Visit" removed, price + Luck shown on items, empty shelves invisible, beach unlock stations, compact two-stage level-up notices. |
| 15 | Auto-collect: finds go straight into the backpack; no sell/display choice at the moment of discovery. |
| 16 | Shovel became passive (no hotbar slot, appears in hand only while digging); realistic detector/shovel/treasure models; coastal scenery (lifeguard hut, vegetation, each beach its own ground and lighting mood); sand pit, mounds, settling sand, treasure "peek"; difficulty = beach × rarity × depth with a hidden recommended shovel tier; grace period + pull-back; full price rebalance; server click checks. |
| 17 | Held treasure fixed (welded per shape, info card); 184 treasures (88 new); permanent dig failure ("TREASURE LOST IN THE SAND"); no grace, continuous decay on every beach; Base renamed **Pier** and rebuilt as a timber pier with jetty and T-head; dev tools on F1/F2/F3 (UserId-locked, sandboxed); sharks chase and bite, custom health bar, respawn on the Pier; living world (gulls, boats, crabs, foam, footprints, swaying plants) and per-place ambient sound. |

Update 18+19 was received but **not started** (no files changed): see section 2.

---

## 2. Update 18+19 plan

The owner's spec has 16 items. Below is the full plan, including the Case Shop design proposed for item 8–11. Nothing here is built yet. Items marked **(owner)** were requested verbatim; items marked **(proposal)** are design choices still open to change.

### 2.1 Order of work (agreed with the owner)

1. Fixes: event Luck multiplier (#1), close buttons (#2), Roblox default health bar (#6), dig bar ghost removal (#15), lost-treasure notice (#14), shorter jetty (#7).
2. Backpack upgrades (#3) and event notifications (#13).
3. Case Shop, cases, cosmetics, Robux cases (#8–11).
4. Spawn plate (#4), shark redesign (#5), world polish (#12).
5. Build, Studio test (#16), guide, deliver, give Step 1.

### 2.2 Small items

- **#1 Event Luck multiplier (owner).** Events get a `LuckMult` (×2, ×3, ×5) instead of the flat `LuckBonus`. Effective Luck = (permanent + boost) × multiplier, applied only at roll time on the server, never saved. Touches Config/Events, EventService (add `GetLuckMult`), GameMath.ComputeLuck (signature change), LuckService, LeaderboardService (calls ComputeLuck with event 0; must pass 1), LuckController (breakdown line "×2 Golden Tide").
- **#2 Close buttons (owner).** Every menu window already built with UIKit.Window has an ✕ drawn from Frames (the ☰/✕ glyphs are missing from Roblox fonts). Audit the windows not made with UIKit.Window (NPC dialogs, confirm/preview popups, level-up card) and give them the same button with hover/press/close tweens. No ✕ on permanent HUD.
- **#6 Default health (owner).** Remove the Update 17 heart + bar row from HUDController and the `SetCoreGuiEnabled(Health, false)` call. Keep the red damage flash in SharkController (it isn't a health bar).
- **#7 Shorter jetty (owner).** Edit `map/Map.rbxmx`, folder Hub > Pier: drop the far section of JettyPlank / Piling / CrossBeam / Brace / JettyRail / Stringer / JettyLantern rows and move the whole T-head group (THead*, Ladder, BaitShack, boats, bollards, LifebuoyT, PierFlag, CrateStack*) back along the jetty axis. SharkService has a carve-out keeping Starting Beach's shark clear of the jetty; re-check it.
- **#14 Lost-treasure notice (owner bug).** In DigController the lost card's background fades behind an invisible layer while its text stays visible. Fix: build the card inside a CanvasGroup, fade with one GroupTransparency tween, high DisplayOrder, destroy everything when done.
- **#15 Dig bar (owner).** Remove the striped red "Loss" ghost frame added in Update 16 (`ui.Loss`). One fill only, smoothly lerped toward the predicted progress both ways.
- **#4 Spawn plate (proposal).** Replace Hub > SpawnLocation + SpawnRing with a round weathered-plank platform, brass trim ring, compass-rose inlay, four rope-linked bollards with small lanterns, soft warm SurfaceLights. SpawnLocation stays a flat invisible-top part 0.2 studs above the deck so characters never spawn inside geometry.
- **#5 Sharks (proposal).** Rebuild SharkModels: torpedo body from ellipsoids, countershading (dark top, white belly), proper dorsal/pectoral/caudal fins, gill slits, black eyes, a row of teeth visible on the lunge, a slight S-curve tail sway, bubbles and a wake while chasing. Variants per beach: grey reef (Starting/Rocky), tiger stripes (Tropical), great white (Shipwreck), hammerhead (Secret Island). Behaviour code in SharkService stays as is.
- **#12 World polish (proposal).** Highest value first: storefronts (unchanged since Update 16: give them real roofs, windows, signs, interiors), personal shops as small galleries, dunes and softer terrain transitions (EnvironmentService already turns Ball/Cylinder parts with a TerrainMaterial attribute into terrain), better NPC outfits. Keep part counts modest; the place is already ~10,100 map instances and an 11.3 MB file.

### 2.3 Backpack upgrades (#3)

Owner's tiers: 10 → 12 → 15 → 18 → 21 → 23 → 25, bought in order with Cash in a new Backpack section of the Equipment Shop.

| Tier | Slots | Price (proposal) | Level (proposal) |
|---|---:|---:|---:|
| Starter | 10 | free | 1 |
| Tier 2 | 12 | $1,500 | 3 |
| Tier 3 | 15 | $12,000 | 6 |
| Tier 4 | 18 | $90,000 | 10 |
| Tier 5 | 21 | $600,000 | 15 |
| Tier 6 | 23 | $3,500,000 | 22 |
| Maximum | 25 | $15,000,000 | 30 |

Why these prices: each tier lands next to a detector upgrade at a similar level, so it reads as a milestone without competing with gear. Touches: Config/Equipment (new Backpacks list), GameConfig.BackpackCapacity (becomes the base), InventoryService (a capacity-from-data helper), every hard-coded "10" (TreasureService full-backpack messages, HotbarController capacity chip, InventoryController, LuckController "fixed size" text), EquipmentShopService (BuyBackpack, sequential check, server-side), EquipmentShopController (Backpack tab), DataService (new saved field and a v3 → v4 migration), StateService (send capacity).

### 2.4 Event notifications (#13) and new events

- **Server:** EventService moves from one event to a list. It publishes a JSON list of {Id, EndsAt} on a ReplicatedStorage attribute (keep the old `EventId`/`EventEnds` attributes, pointing at the newest event, so WorldController's night lighting keeps working). Clients count down from `EndsAt` with `Workspace:GetServerTimeNow()`, never their own timer, and drop an icon the moment the server removes it. Deduplicate announcements by Id + EndsAt so respawns and late joins don't replay them; late joiners get the icon with the correct time but no big pop-up.
- **Client (new EventNoticeController):** a centre-top announcement (logo, title, one-line description, time left) for ~4 s, then it shrinks and flies to a stack of icons at the bottom-right. Hover (PC) or tap (mobile) shows a compact panel with title, description and live countdown; tap elsewhere closes it. Semi-solid dark panel with a thin border, soft shadow and a restrained glow in the event colour. Remove the old HUD event banner so there's only one system.
- **Logos:** every event gets its own badge built from layered emoji plus a shaped backing and a multiplier tag (no shared generic icon). Open question: whether the owner wants uploaded decal logos instead.

| Event | Effect | Logo idea |
|---|---|---|
| Golden Tide (exists) | Luck ×2 | 🍀 on a gold coin |
| Lucky Storm (new) | Luck ×3 | ⚡ + 🍀, storm-blue badge |
| Rainbow Tide (new, rare, short) | Luck ×5 | 🌈 with "×5" |
| Treasure Rush (exists) | 2× buried treasures, 1.5× dig speed | 🧰 overflowing with 💰 |
| Double Cash (new) | Sell prices ×2 (hook in InventoryService selling) | 💰 stack with "×2" |
| Shark Frenzy (new) | Sharks faster and hunt wider (multiplier read by SharkService) | 🦈 fin on red water |
| Moonlit Night (exists) | Moon-only treasures, night lighting | 🌙 |
| Relic Hunt (new) | Every buried treasure is Rare or better | 💎 with sparkles |

Moonlit Night currently has a flat LuckBonus of 0.25; under the multiplier rule it either becomes ×1.5 or has no Luck effect (open question).

### 2.5 Case Shop (#8–11): design

**Building.** The bait shack at the end of the (shortened) jetty becomes **"Shell & Case Co."**. It gets an illuminated hand-painted sign with warm neon-tube trim, lit windows, glass display cabinets with the case models on velvet shelves, and SurfaceLights per shelf. Rarity glow grows with case value. One Robux cabinet gets gold trim, a slow-turning case with a Trail and a few sparkle particles, and a Robux-symbol price billboard. NPC: **Marina, the Case Keeper**, with a "Browse Cases" prompt (same NPC system as the Sell and Equipment shops). Effects stay restrained (warm, coastal, few particles); the building must also read well at night (Moonlit Night).

**Cases (all prices are proposals).**

| Case | Currency | Price | Level | Common | Uncommon | Rare | Epic | Legendary | Mythical |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Driftwood Crate | Cash | $2,500 | 3 | 60% | 28% | 9% | 2.5% | 0.5% | 0% |
| Tidepool Chest | Cash | $25,000 | 8 | 45% | 30% | 16% | 6.5% | 2.2% | 0.3% |
| Captain's Coffer | Cash | $250,000 | 15 | 30% | 32% | 22% | 11% | 4.2% | 0.8% |
| Sunken Vault | Cash | $2,500,000 | 24 | 15% | 27% | 28% | 18% | 9% | 3% |
| Golden Doubloon Case | Robux | 49 R$ (or 129 R$ for 3) | any | 20% | 30% | 27% | 15% | 6.5% | 1.5% |
| Kraken's Hoard | Robux | 149 R$ (or 399 R$ for 3) | any | 0% | 0% | 45% | 33% | 17% | 5% |

- Within a rarity, every eligible item is equally likely. The odds panel shows both the rarity % and each item's own %.
- Player Luck never affects cases (the disclosed odds must stay exact).
- Pools: Cash cases contain every non-exclusive item of the rarities they can drop. Robux cases contain those plus the **Kraken Collection** (one Legendary or Mythical exclusive per category), which never appears in Cash cases.

**Duplicates (proposal).** No Cash refunds, because Cash from Robux cases would be pay-to-win. Duplicates give **Sea Glass**, a cosmetic-only currency: Common 5, Uncommon 12, Rare 30, Epic 80, Legendary 250, Mythical 800. A **Sea Glass Exchange** tab sells any non-exclusive cosmetic outright: Common 60, Uncommon 150, Rare 400, Epic 1,000, Legendary 3,000, Mythical 9,000. This doubles as pity protection.

**Cosmetic catalogue (proposal, ~70 items).** Cosmetic only: no stats, no Luck, no dig changes.

| Category | Common | Uncommon | Rare | Epic | Legendary | Mythical |
|---|---|---|---|---|---|---|
| Detector finishes | Sandy Beige, Seafoam, Driftwood Grain | Sunset Stripe, Rope-Wrapped, Lifeguard Red | Brass & Mahogany, Coral Pink, Tortoiseshell | Pirate Gold (sparkle), Deep-Sea Glow (bioluminescent pulse) | Aurora (colour shift) | Abyssal Pearl; *Kraken's Eye (Robux-exclusive, tentacle coil)* |
| Shovel skins | Red Plastic Pail, Pastel Spade | Ship's Oak, Rusted Iron | Coral-Carved, Bronze Anchor | Pearl Inlay, Molten Copper (embers) | Trident Spade | Sea-Glass Spade; *Leviathan Bone (Robux-exclusive)* |
| Shop cosmetics | String Bunting, Shell Wind Chime | Hand-Painted Sign, Striped Awning | Lantern Row, Ship's Bell, Surfboard Rack | Glass-Tube Sign (soft glow), Aquarium Window | Lighthouse Beacon (rotating roof light) | Coral Palace Facade; *Sunken Galleon Facade (Robux-exclusive)* |
| Pets | Hermit Crab, Sand Crab | Seagull, Starfish | Baby Sea Turtle, Puffin | Pelican, Octopus | Golden Crab, Baby Dolphin | Crystal Seahorse; *Ghost Kraken Pup (Robux-exclusive)* |
| Hats & accessories | Sunglasses, Bucket Hat | Sand-Bucket Hat, Fishing Hat | Straw Sun Hat, Captain's Cap, Snorkel Mask | Pirate Tricorn, Lifeguard Visor | Coral Crown | Pearl Diadem; *Kraken Captain's Hat (Robux-exclusive)* |
| Outfits | Board Shorts, Striped Tee | Hawaiian Shirt, Lifeguard Shorts | Tropical Outfit, Sailor Outfit | Pirate Outfit, Neon-Trim Wetsuit | Admiral's Coat | Tide-Weaver Robes; *(Robux-exclusive: Kraken Diver Suit)* |

**How each category is applied.**
- *Detector finishes:* ToolService passes the equipped finish to DetectorModels. Finishes override colours, material and effect; the "CoilGlow"/"SignalLight" part names must survive.
- *Shovel skins:* ShovelModels.BuildTool gets an optional skin.
- *Shop cosmetics:* PersonalShopService builds them on the owner's plot in four slots (Exterior, Sign, Lighting, Decor).
- *Pets:* the server sets an attribute naming each player's pet; a new client PetController builds and animates every player's pet locally (follow with smoothing, idle bob, hop). There is no server physics, so it stays cheap in multiplayer. Reduced Motion makes pets static.
- *Hats:* the server builds Accessories from parts with a standard attachment and uses Humanoid:AddAccessory (works on R6 and R15).
- *Outfits:* needs a decision (see open questions): either Shirt/Pants clothing templates the owner uploads, or part-built overlays.

**Case opening UX.** The server decides the result first; the client only animates to it.
1. The case model shakes and the lid opens.
2. A horizontal reel of item cards spins and slows over 3–4 s onto the result, with a rarity-coloured burst. Epic and up get more particles; Mythical adds a screen-edge glow and a server-wide announcement.
3. A result card shows **NEW!** + "Equip now", or "Duplicate → +N Sea Glass".
4. A **Skip** button jumps straight to the result. A "Skip animations" setting is remembered.

**Case Shop window.** Case cards on the left, each with a 3D viewport. Cash price chips are green with "$". Robux chips are gold with the Robux glyph (character 0xE002 in Roblox fonts), a ROBUX ribbon and a soft animated glow, so they can't be mistaken for Cash prices. The right side shows "Contents & odds" grouped by rarity, with Open ×1 (and ×3 for Robux bundles).

**Wardrobe** (new ☰ menu entry). Tabs: Detector, Shovel, Shop, Pets, Hats, Outfits. A grid with rarity border **and** glyph (never colour-only), a preview viewport, Equip/Unequip, and an "Owned x / y" count.

**Robux rules (must-haves).**
- Robux purchases are Roblox **developer products**. The owner must create them in the Creator Dashboard for the published experience and paste the product IDs into the case config. Until then the Robux buttons show "Coming soon".
- MarketplaceService.ProcessReceipt on the server grants the opens idempotently. Store recent PurchaseIds in the save, and save before returning PurchaseGranted.
- Check PolicyService (`ArePaidRandomItemsRestricted`) per player. Where paid random items are restricted, hide the Robux cases (Cash cases stay available).
- Odds must be shown before buying (Roblox policy for paid random items).
- In Studio every purchase is a free test purchase.

**Files for #8–11.**
- New: Config/Cases, Config/Cosmetics, shared CosmeticModels (hats, pets, shop decor builders), server CaseService (Cash buys, receipts, rolls, duplicates, Sea Glass, equip validation), client CaseShopController (window + opening animation), WardrobeController, PetController.
- Modified: DataService (Cosmetics {Owned, Equipped}, SeaGlass, Receipts; v4 migration), StateService, Remotes (case open and equip remotes), Main ORDER and ClientMain lists, Config/NPCs + NPCController (Case Keeper), HUD menu (Wardrobe), ToolService, DetectorModels, ShovelModels, PersonalShopService, map (bait shack → Case Shop).

### 2.6 Open questions for the owner

1. Case prices, odds and the item list above are proposals. Confirm or adjust.
2. Duplicates as Sea Glass + Exchange (proposal) or a Cash refund (only safe for Cash cases)?
3. Outfits: will the owner upload Shirt/Pants templates (best look), or are part-built overlays acceptable?
4. Should case finishes share the detector "Skin" slot with the existing shop-bought skins (Ocean Blue … Galaxy), or be a separate layer?
5. Should events ever overlap automatically (e.g., a 10% chance of a bonus event), or only through the dev tools?
6. Moonlit Night's Luck under the multiplier rule: ×1.5, or none?
7. Event logos: built from emoji/shapes (proposal) or uploaded images?
8. Robux product IDs (owner must create the products).

---

## 3. Design decisions and the reasons behind them

**Luck formula.**
- Luck points are additive: (level − 1) × 0.01 + detector Luck + shovel Luck + trinkets + Shop Luck from displays, plus any active boost. The UI shows points × 100 (0.21 = "+21 Luck").
- The roll multiplier is Total = 1 + points, then × depth Luck (1 / 1.3 / 1.7 for shallow, medium, deep).
- Each rarity's zone weight is multiplied by Total ^ LuckPower. LuckPower is Common 0, Uncommon 0.45, Rare 0.75, Epic 1.0, Legendary 1.2, Mythical 1.35, Secret 1.5.
- Common can never drop below 8%.
- Why: the owner asked for additive Luck in #13. A rising LuckPower makes Luck help the rarest tiers most without ever boosting Common, and the 8% floor keeps cheap finds flowing so backpacks don't fill only with rares.

**Shop Luck.**
- Each displayed treasure gives DisplayLuck × Quality × (1 + 0.12 × (beach index − 1)).
- DisplayLuck by rarity: Common 0.005, Uncommon 0.012, Rare 0.03, Epic 0.07, Legendary 0.16, Mythical 0.35, Secret 0.75.
- Quality rolls 0.80–1.60 (Worn / Fine / Pristine / Flawless), skewed upward by Luck.
- Why: it makes the personal shop a real choice against selling, and finds from later beaches are worth displaying.

**Beach weights.** Starting Beach is Common 620 / Uncommon 270 / Rare 85 / Epic 20 / Legendary 4 / Mythical 0.45 / Secret 0.05. Each beach shifts weight up the table, ending at Secret Island: 400 / 300 / 185 / 80 / 26 / 4.0 / 0.4.

**Beaches.**

| Beach | Price | Level | Value × | XP × |
|---|---:|---:|---:|---:|
| Starting Beach | free | 1 | 1 | 1 |
| Rocky Shore | $750 | 4 | 3 | 1.5 |
| Tropical Island | $6,000 | 8 | 9 | 2.2 |
| Abandoned Pier | $35,000 | 13 | 25 | 3.2 |
| Shipwreck Coast | $250,000 | 19 | 70 | 4.6 |
| Ancient Ruins | $1,500,000 | 26 | 200 | 6.5 |
| Secret Island | $7,500,000 | 34 | 600 | 9 |

Why: income per dig runs from about $40 (Starting Beach) to about $89K (Secret Island). Prices were set so early upgrades take ~4–15 digs, mid-game ~20–90 and late game ~100–350 (Update 16 rule: gradual early, bigger mid gaps, steep late game). The same curve applies to all equipment.

**Equipment prices.**
- Detectors: $250, $1.2K, $7.5K, $60K, $400K, $2.5M, $15M (Luck 0.05 → 1.02; range 27 → 160 studs).
- Shovels: $150, $600, $4K, $45K, $650K, $6M (Power 1 → 6.5, Speed 6 → 12 clicks/s, DecayMult 1 → 0.45).
- Boosts: Lucky Charm $750 (+50 Luck for 10 min), Four-Leaf Clover $15K (+100 for 15 min), Pirate's Blessing $250K (+200 for 10 min).
- Shop levels: 6 → 48 slots, $2K to $7.5M.
- Detector skins: $1K to $6M.
- Shop themes: $5K to $4M.
- Trinkets (earned from achievements): +5 to +30 Luck.

**Digging (Config > GameConfig > Dig; all hidden from players).**
- Resistance = beach (1, 1.5, 2.2, 3.1, 4.4, 6.2, 9) × rarity (1 … 5.5) × depth (1, 1.2, 1.45).
- Base gain is 0.125 per click (8 clicks for a shallow Common at Starting Beach with the right shovel).
- Recommended shovel tier = beach tier + rarity bonus (0,0,1,1,2,2,2) + depth bonus (0,0,1).
- Each tier under the recommendation divides gain by (1 + 0.25 per tier) and adds +50% pull. Each tier over adds +10% gain (capped at ×1.5) and −20% pull.
- The pull is continuous with no grace (Update 17). It is about 1.1 clicks' worth per second with the right shovel, grows up to 2× after 1.2 s idle, and is capped at half the shovel's top click speed (never above 3 clicks/s), so every dig is always winnable.
- Permanent loss only counts after a "foothold" (1.5 clicks' worth, 10–30% of the bar), so a dig can't fail instantly at 0%.
- Examples: Starting Beach Common with the Starter = 10 clicks; Shipwreck Coast Epic with Diamond = 19, with Gold = 33, with the Starter = 301.
- Other values: 10-stud dig range, 12 s idle cancel, +1 XP per 3 counted clicks, server ignores clicks faster than 0.8 × the shovel's minimum interval.

**Progression.**
- XP to the next level = 45 × L^1.5 + 30; level-up Cash = 40 × L^1.35; max level 100.
- A free Lucky Charm every 5 levels and a Clover every 10.
- First discovery of a treasure type gives +50 XP.

**Backpack.** Fixed at 10 since #14, so players keep returning to sell or display. #18 reopens it to 25 with sequential tiers (section 2.3).

**Sharks.**
- Chase speed 30 vs. swim 22.
- They give up after 4 s without closing in, with a 30 s chase cap and a 2.5 s breather.
- Bite 18 HP within 6.5 studs. A player can only be bitten once per 1.7 s however many sharks are near, and each shark recovers for 1.1 s after a bite.
- Swimmers north of z = −38 (the shallows) are never hunted.
- Why: the shark is a real threat in deep water but escapable and never unfair on sand or the Pier. Death is a normal Roblox respawn on the Pier (RespawnTime 3) and nothing is lost.

**Events.** The first event starts 3 min after server start, then one every 12 min, each lasting 4 min, and never the same event twice in a row.

**Developer tools.** Allowed only for UserIds in DevService (98951116), or the place owner if the place belongs to a user rather than a group. Every command is re-checked on the server and only touches the caller's own data. A sandbox switches on at the first use: that session is never saved and never reaches leaderboards. Why: the owner wanted safe live testing.

**Saving.** DataStore `BeachDetectingData_v1`, data version 3, session locks, autosave every 120 s; leaderboards prefixed `BeachLB_v1_`. Update 18 will need version 4 (backpack tier, cosmetics, Sea Glass, receipts) with a migration that keeps existing saves.

---

## 4. Known bugs, TODOs and unbuilt ideas

**Bugs / unverified.**
- **Lost-treasure notice layering** (owner-reported, U18 #14) and the **ghost loss bar** (U18 #15) still need fixing.
- **Clicks may be dropped when digging fast.** In the last Studio test only about 1 of 3 clicks spaced 0.2 s apart seemed to count, even though the Starter shovel's rate limit is 0.17 s. Possibly a test artefact (the Claude window kept stealing focus), but check the client gate in DigController (`MinInterval`, `pendingClick`) and the server gate in TreasureService.Click (`LastAccepted`, 0.8 × MinInterval).
- After the Studio dev hook `Shovel` swapped to Diamond, the next dig still behaved like the Starter. Check that the hook really changes the equipped shovel the dig profile reads.
- Permanent treasure loss was never seen happening live (logic reviewed only), and there has been no two-player test (Test > Clients and Servers).
- In Studio, F1 opens Studio Help, so the dev panel opens with F2/F3 and the Edit tab. Live games are unaffected.
- Studio sometimes opens the place read-only ("file in use by another Studio instance"); close every Studio window first.
- The custom health bar is still in HUDController (to be removed by U18 #6).

**Tech debt.**
- `tools/gen_map_u16_legacy.py` is the old Update 16 generator. The live map is `map/Map.rbxmx` (taken from the Update 17 build), so map edits must go to that file (or be built at runtime). Never regenerate from the legacy script.
- luau-lsp 1.53 reports false positives ("Type 'UICorner' could not be converted into 'Instance'…", unknown types, controller argument counts). `tools/check.sh` output is filtered; anything else that shows up is real.
- Only one event at a time today (U18 #13 changes this).

**From Update 17's world spec, only partly done.**
- No dunes or softer terrain transitions.
- Storefronts unchanged since Update 16.
- Personal shops aren't galleries yet.
- No camera intro.
- Day/night is only a ±20-minute sun drift plus the Moonlit Night event.

**Ideas raised but not built.** Sea Glass Exchange, a daily login reward, seasonal/weekend events, overlapping bonus events, a short camera fly-in on first join, more beaches.

---

## 5. What is not in the GitHub repo

**Owner's working style (important).**
- Inspect the project before changing anything. Never duplicate systems. Modify existing scripts.
- Provide complete revised scripts where needed and an exact Explorer hierarchy.
- Guide the owner **one step at a time** and wait for confirmation. Every delivery ends with "Step 1".
- Preserve all previously working systems unless the owner explicitly removes them.
- Test in Studio before calling something done.
- **Never touch the owner's published game** ("Detect Some Metal"; Studio's recent list now also shows a place called "Detector"). The owner publishes over it themselves.

**The guide document (Claude Docs artifact).** https://claude.ai/artifact/HT58pPGgvveAyzX8W7M53a
- Project id `85361acf-4c3e-49c4-8fcc-af3f68ebad85`, node `1898dd1c-d118`.
- It holds the step-by-step implementation guide, a controls table, a "What's new" section per update (17, 16, 4, 3, 2, newest first, inserted after the Quick start), testing checklists and the script/Explorer tables.
- New update sections go right after the Quick start block.

**Delivery workflow.**
1. Build with Rojo 7.4.4 to an `.rbxlx` (about 11.3 MB).
2. Copy it to a uniquely named file (e.g. `…-u18a.rbxlx`). Reusing a name once delivered a stale file.
3. Write it to the owner's PC at `C:\Users\azrie\Documents\BeachDetectingSimulator.rbxlx` (overwrite).
4. Also send the `.rbxlx` and a source zip in the chat.
5. `.rbxlx` files are git-ignored. Commit each update to `dodv2/MetalDetectorGame`, branch `main`; the owner linked GitHub and installed the Claude app on 4 Nov.

**Toolchain (not committed).**
- Rojo 7.4.4, Lune 0.8.9, and luau-lsp 1.53.0 plus its `globalTypes` definitions from the luau-lsp repo at tag 1.53.0, all installed under `~/tools`.
- Tests: `tests/config_test.luau` and `tests/shop_test.luau` (both pass as of Update 17).

**Studio testing notes.**
- The owner's Studio is reached via the desktop app's computer-use bridge.
- A `BeachDev` BindableFunction in ServerStorage (Studio only) accepts these commands in the server command bar: Give (cash, level), XP, Rarity (re-roll nearby treasures), Event, Items (n), Nearest (teleport onto the closest treasure), Shovel (id), Zones (unlock all beaches).
- Switch the command bar's context with the Client/Server tabs at the top of the viewport.
- The Claude desktop window can jump in front of Studio mid-test and swallow clicks; close the built-in browser pane before testing and re-check focus.
- DataStores don't work in Studio for this unpublished file (expected).

**Ambient sound IDs** (Roblox's licensed Pro Sound Effects library, verified to load on 3 Nov; already in SoundController):

| Sound | ID |
|---|---|
| Surf | 9120621776 |
| Waves | 9119676058 |
| Wind | 9114057128 |
| Gulls | 9112870701 |
| Beach promenade | 9112747323 |
| Jungle | 9112805592 |
| Dock lapping | 9120571336 |
| Harbour life | 9112792352 |

**Budget note.** The owner's Claude usage was at ~87% of the weekly limit on 3 Nov, so work in priority order (section 2.1) and keep a working build after each stage.
