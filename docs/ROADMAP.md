# THE MOBILE PUSH — Roadmap

**Started:** November 26 2026
**Status:** v0.2.0. Flight (M.1–M.3 mostly), soul pass (audio + CRT + backdrop), raiders/drones, and terminals (M.4 core) are in. **Delivery tunnels (M.5) are next**, per Chris: terminals and tunnels are half the game.
**North star for all agents working in this repo (Ded Drift).**

Each phase ends with a playable APK on a real device. One PR per phase
(split a large phase into sub-PRs if needed). Tick boxes here only.

---

## M.0 — Foundation
- [x] Godot 4.x stable pinned. `project.godot`: 1280×720, `canvas_items` + `expand`, `sensor_landscape`, `gl_compatibility`
- [~] Folder layout per ARCHITECTURE.md. `RunState` autoload exists; `Events`/`Settings`/`SaveService` arrive when needed
- [x] Headless test runner (in-house, no deps). Save-validation tests passing
- [x] CI: headless test run and a debug APK export on push, published as a GitHub Release. Secret check script
- [x] CI end-to-end smoke test drives the real screens (title → flight → jump → next sector → pause → death → title) under Xvfb. A tap that does nothing fails the build
- [x] `.gitignore` covers keystores, `export_presets` credentials and `.godot/`
- [x] Title-screen APK runs on Chris's phone (Galaxy S26). Feedback: "no game started". Fixed in v0.1.0

## M.1 — Flight core
- [x] `ShipBody` fixed-tick Newtonian integration (forces accumulated, `dt` only in `integrate`)
- [x] Gravity wells, slingshot detection, overdrive cap
- [x] Gun (auto-fire assist), debris that splits, salvage + patch pickups. Five named sectors (palette/themes still shared)
- [~] Barge state machine: patrol → chase → clamp (harpoon tether, hull drain) → stunned. Tether snap and shoot-to-break. Aim/torch-module beats not yet
- [ ] Tuning pass at 1280-wide (MAX_VELOCITY, overdrive). **Needs Chris's phone feedback**

## M.2 — Touch controls and HUD
- [~] Floating AIM stick, THRUST, RETRO, FIRE, JUMP. Classic scheme option not yet
- [x] Safe-area anchoring. Top-bar HUD. Bax pill with event lines. Off-screen barge arrows
- [~] Haptics on hits, clamps, slingshots, jump (VIBRATE permission). Settings toggle not yet
- [x] Diegetic flicker/scramble with the "never scramble actionable text" rule. CRT post shader with hull-driven tearing
- [ ] Device test: latency feels good, no accidental gesture-edge triggers

## M.3 — Run loop and saves
- [~] Title → 5 sectors → chapter-complete stub → death invoice (retry same sector). Loadout draft not yet
- [x] Meta state: debt, clones, chapters, stepped death fees (persisted to `user://meta.json`)
- [~] JSON saves: schema-validated, atomic writes for meta. App switch auto-pauses. 3 slots + mid-sector autosave not yet
- [ ] Kill the app mid-sector and resume into pause at the same spot (device test)
- [ ] Save-fuzz tests: corrupt, oversized or hostile JSON loads a fresh state without crashing

## M.4 — Terminal core (offline)
- [x] TerminalScreen layout. CRT keyboard with code row. System-keyboard toggle. Scan chips insert text. Terminal every 3rd jump (Chris, Nov 26)
- [x] Rule engine: normalize, negation, path matching, patience, outcomes. Economy rules (EXPLOIT 5k / RELEASE 2.5k / dual ledger / broke counter-offer). Hardening not yet
- [x] NPC data (GDScript dictionaries for now) + schema tests (≥15 keywords, ≥3 paths, ≥1 systems path, every path reachable by a scripted playthrough, bribe label)
- [~] Shell mode (whitelisted commands over the NPC filesystem). SQL matcher. REPL with structural danger detection + own arithmetic parser (no eval, ever). TAB complete and history not yet
- [x] Security ladder: alarm on the 3rd failed attempt; next sector's barges hunt from second one
- [x] Port **Gary**, **TK-9**, **Kress** (rotating). Toll terminals mid-sector not yet

## M.5 — Delivery
- [ ] Dock: align beat (ring line bonus) and land beat (ALIGN + hold BURN, graded)
- [ ] Corridor controller (coyote, buffer, variable jump, sprint, ladders, ACTION context button)
- [ ] Room system plus Ch1 rooms (6–7), checkpoints, chip chains, stars, tally screen
- [ ] Payout card and debt adjustment

## M.6 — Full loop systems
- [ ] Shops (after sectors 2 and 4, dual-ledger display)
- [ ] Kress call (K), barge intercept comms with Gary, toll terminals mid-sector
- [ ] All 8 sector themes
- [ ] Cargo mechanics: Ch1 (with visual twin), Ch2 (telegraphed inversion), Ch3 clipboard, Ch4 hold-to-peek, Ch5 trace, Ch6 upload and chase room

## M.7 — LLM voice layer (opt-in)
- [ ] Spike: cost and latency per turn with the smallest fast Claude model. Go/no-go with Chris (set a budget cap)
- [ ] Serverless proxy: key server-side only, install tokens, rate limits, spend cap and kill switch, fixed server-side prompt, response validation, no content logging
- [ ] Client: 1.5 s budget with authored fallback, output filter (length, digits, leak check), opt-in screen with privacy text, Settings toggle
- [ ] Deterministic jailbreak detector, plus a SOCIAL-ENGINEERING path on TK-9 and the Toll AI
- [ ] Red-team pass: 50+ injection attempts. Confirm zero state changes from model output

## M.8 — Full roster and campaign
- [ ] All remaining NPCs ported in the CONTENT.md order, all passing schema tests
- [ ] Chapters 2–6 corridors. Full campaign playable start to finish
- [ ] Bax full line banks, harmonica heal, BAX'S TAPES unlock

## M.9 — Audio
- [x] Procedural soundtrack + SFX rendered at startup on a background thread (no audio files)
- [~] Bus layout and DSP: hull low-pass, tape hum. Ch1 crush not yet
- [~] Music director: bed / pulse / tension / terminal layers crossfaded by danger mood. Recorded-stem slots not yet
- [ ] Visual and haptic twins for all critical cues

## M.10 — Polish and performance
- [ ] Performance budget met on the low-end device (frame time, start time, APK size, battery)
- [ ] Button layout editor, handedness mirror, all accessibility settings
- [ ] Full playthrough on 2+ devices (16:9 and 20:9)
- [ ] Distribution decisions revisited with Chris (monetization, analytics, store listing)
