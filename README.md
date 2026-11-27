# DED DRIFT

> *Same debt. Same rusted ship. Now it fits in your pocket.*

**Ded Drift** is a new, **Android-only** game based on [Dead Drift](https://github.com/chris-dewitt/Dead-Drift),
built for phones from the ground up in **Godot 4**. Landscape, two thumbs:
Newtonian flight, NLP terminals, delivery corridors.

**Status:** v0.2.0: flight with soul, plus terminals. See [docs/ROADMAP.md](docs/ROADMAP.md).

### What you can play right now

- **5-sector chapter.** Survive each sector until the gate opens, then hit JUMP.
- **Touch flight.** Left thumb: floating AIM stick. Right thumb: THRUST, RETRO, FIRE (guns also auto-fire at whatever you aim at).
- **Gravity wells.** Dive close and slingshot out for overdrive and credits. Hitting the core hurts.
- **Local 404 repo barges.** They hunt you and harpoon you. Thrust hard to snap the tether, or shoot the barge.
- **Debris and salvage.** Shoot rocks for credits, grab scrap (credits) and patch kits (hull).
- **Death costs you.** Decanting invoice, debt goes up, retry the sector you died on. Debt, clones and chapters persist between sessions.
- **More hostiles.** Krellborn pirate raiders (sector 2+) circle and shoot; Nova Soma Compliance drones (sector 3+) chase and explode.
- **Terminals every 3rd jump.** Negotiate with Gary (Local 404), TK-9 (customs droid) or Kress (fixer) on a CRT keyboard with keyword chips, or hack them: shell (SH), SQL injection, Python (>>>), prompt injection. Dossier shows every win path. Honest numbers: exploit +5,000, release +2,500, bribes and purchases hit credits AND debt, 3 failed hacks sound the alarm.
- **Soul.** Procedural synth soundtrack (D minor, Blade-Runner-ish) that follows the danger, SFX, Bax voice blips, CRT post-process, corporate-hellscape backdrop with Nova Soma ads.
- **Not in yet:** shops, docking and delivery tunnels (next), loadout, settings menu.

## Playtest on your phone

1. Open this repo's **Releases** page on your phone (signed in to GitHub).
2. Newest build: tap the `.apk` under *Assets*. Builds from `main` are tagged
   `build-N`; builds from open pull requests are tagged `pr-N`.
3. Open the downloaded file. The first time, Android asks you to allow installs
   from your browser. Allow it for that app only.
4. **Updating:** until a fixed signing key is set up, every build has a new
   signature. Uninstall the old version before installing a new one.
   Test builds only, so there are no saves to lose yet.

Tap the version label in the bottom-left corner to show the debug panel (FPS,
resolution, safe area, device).

## Develop

- Godot **4.5.1-stable**. Open `project.godot` in the editor.
- Run tests headless: `godot --headless --path . --script res://tests/run_tests.gd`
- CI: `.github/workflows/android.yml` (tests → secret check → APK export → Release)

### Optional: fixed signing key (keeps installs updatable)

Add two repo secrets (Settings → Secrets and variables → Actions):
`DEBUG_KEYSTORE_B64` (base64 of a keystore whose key alias is `dd`) and
`DEBUG_KEYSTORE_PASS`. CI uses them automatically when they're present, and
generates a throwaway key otherwise. Never commit a keystore.

## Docs

| Doc | Covers |
|-----|--------|
| [docs/ROADMAP.md](docs/ROADMAP.md) | **North star.** Phases M.0 → M.10 |
| [docs/DECISIONS.md](docs/DECISIONS.md) | Locked decisions, pillars, open questions |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Engine, layout, saves, performance, security baseline |
| [docs/TERMINAL.md](docs/TERMINAL.md) | Terminals: input, rule engine, shell/REPL, LLM voice layer |
| [docs/CONTROLS_AND_HUD.md](docs/CONTROLS_AND_HUD.md) | Touch layouts, HUD, accessibility |
| [docs/CONTENT.md](docs/CONTENT.md) | Run loop, chapters, cargo redesigns |
| [docs/AUDIO.md](docs/AUDIO.md) | Audio plan |
