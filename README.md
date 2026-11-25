# Dragon Slate

A roguelite where you build a 3×3 rune slate, fuse dragons into lineages and fight auto-battles on three lanes.
Made with Godot 4.7 and GDScript. Screen text is Korean. The old working name was Wyrmslot.

## Where to look (for code review)

| Path | What it is |
|---|---|
| `godot/core/` | Game rules: deterministic, integer-only, no UI. `run.gd` (run state and commands), `battle.gd` (tick-based lane battle), `slot.gd` (rune slate spin), `fusion.gd`, `waves.gd`, `rng.gd` |
| `godot/ui/` | Screens and controls. `game.gd` (main game screen), `controller.gd` (sends commands to the core), `store.gd` (saves), `theme.gd` (all colors and layout values) |
| `godot/tests/` | Tests. Run: `godot --headless --path . --script res://godot/tests/run_tests.gd` |
| `godot/tools/` | `bot.gd` and `sim.gd`: bot players for balance measurement (`npm run sim -- --runs 300 --seed 1000`) |
| `data/*.json` | Every number in the game (dragons, waves, battle, relics, skills, stages) |
| `docs/superpowers/specs/` | Design documents. Latest direction: `2026-11-24-direction-b-design.md` |
| `CLAUDE.md` | Project rules (Korean): invariants, naming, layout rules |

Not maintained: `packages/`, `apps/`, `tools/sim`, `tools/parity`, `dist*` are the retired web (TypeScript/Phaser) version, kept for reference only.

## Rules the code must keep

- `godot/core` is deterministic: random numbers only through `Rng`, integers only, percentages as integers, division with floor.
- Numbers come from `data/*.json`, not from code constants.
- Elements: fire > ice > lightning > fire (135% strong, 75% weak).
- The lane preview shown before battle must match the real enemy layout (`Waves.lane_preview`, fixed by tests).
- Stepping a battle tick by tick must give the same result as simulating it at once (`test_stepper.gd`).

## Art

Dragon sprites were made with an AI image generator. Backgrounds and UI art are drawn by code (`tools/art/gen_backgrounds.py`).
Music and sound effects are synthesized by code (`tools/music/`), no recorded or AI-generated audio.
