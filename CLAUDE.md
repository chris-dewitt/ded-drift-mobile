# DED DRIFT — Agent pointer

This repo (`ded-drift-mobile`) is **Ded Drift**, a **separate, Android-only game** based on
Dead Drift (repo `chris-dewitt/Dead-Drift`).

1. **Never copy code from, or depend on, the original Dead Drift game.** Read
   it for lore and tone only.
2. **North star:** [docs/ROADMAP.md](docs/ROADMAP.md). Update checkboxes there.
3. **Locked decisions:** [docs/DECISIONS.md](docs/DECISIONS.md). Don't
   re-litigate them; raise a question instead.
4. **Terminal rule:** *the rules decide, the model talks.* No LLM output may
   change game state, credits, hull or outcomes. See [docs/TERMINAL.md](docs/TERMINAL.md).
5. **Builds:** every push builds an APK in GitHub Actions and publishes it as a
   GitHub Release (`build-N` on main, `pr-N` on PRs). Chris installs from there.
6. **Security:** no secrets in the repo or the APK, no `Expression`/eval on
   player text, JSON-only saves. See ARCHITECTURE.md § Security baseline.

## Git identity — always use this

```
git config user.name "Chris-dewitt"
git config user.email "chnodewi@unc.edu"
```

Never commit as Claude. Never add co-author lines.
