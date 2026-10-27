# NEBULA BRAWL — Combat Demo

A sci-fi, turn-based RPG battle demo in the spirit of Earthbound and Pokémon,
built as a playground for **combat music and sound design**.

Built with **Godot 4.7**. All pixel art is drawn in code, so there are no image assets.

## Running it

1. Open Godot and **Import** this folder (pick `project.godot`).
2. Press **F5** (or the ▶ button).

Or run it from a terminal:

```
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

## Controls

| Key | Action |
|---|---|
| Arrows / WASD | Move cursor |
| Z / Enter / Space | Confirm, and speed up text |
| X / Esc / Backspace | Back |
| Gamepad | D-pad, A, B |

### Test shortcuts (in battle)

These let you jump straight to any musical moment.

| Key | Does |
|---|---|
| **F1** | Toggle the audio cue HUD (works anywhere) |
| **F2** | Instant victory |
| **F3** | Instant defeat |
| **F4** | Drop the whole crew to low HP, which turns on the danger layer |
| **F5** | Boss battle: drop the boss to 50% HP. Phase 2 starts after the next action |
| **F6** | Quit to the title |
| **F7** | Auto-battle. The crew picks their own moves, so you can sit back and listen |

## Adding audio (for the composer)

The game plays everything **by cue name**. Drop a file with a matching name into:

- `audio/music/<cue>.ogg` (or `.wav` / `.mp3`)
- `audio/sfx/<cue>.ogg` (or `.wav` / `.mp3`)

That's it: no code changes needed. If the Godot editor is open, it imports the file
automatically.

The **HUD** (top right, F1) shows every cue the moment it fires:
**green** means a file was found and is playing, **gray** means there's no file yet.
The title screen also has an **AUDIO CUE LIST** page for auditioning every cue.

### Music rules

- Anything with `_loop` in its name **loops automatically**.
- `battle_intro` plays once and then hands off to `battle_loop`. The same goes for
  `boss_intro` → `boss_loop` and `victory` → `victory_loop`. If there's no intro
  file, the loop starts right away.
- **Danger layers:** `battle_loop_danger` starts at the *same moment* as
  `battle_loop`, muted, and fades in while any crew member is under 30% HP. Make it
  the **same length and tempo** as its loop, like a vertical layer or stem.
- **Boss phase 2:** when the boss drops below 50% HP, the music crossfades
  (1.5 s) from `boss_loop` to `boss_phase2_loop`.

### Music cues

| Cue | When |
|---|---|
| `title_loop` | Title screen |
| `battle_intro` | Normal battle starts (one-shot) |
| `battle_loop` | Normal battle |
| `battle_loop_danger` | Layer over `battle_loop` at low HP |
| `boss_intro` | Boss battle starts (one-shot) |
| `boss_loop` | Boss, phase 1 |
| `boss_loop_danger` | Layer over `boss_loop` |
| `boss_phase2_loop` | Boss below 50% HP (crossfade) |
| `boss_phase2_loop_danger` | Layer over `boss_phase2_loop` |
| `victory` | You won (one-shot) |
| `victory_loop` | Optional loop after the fanfare |
| `defeat` | Whole crew KO'd |
| `flee` | Escaped successfully |

### SFX cues

`menu_move`, `menu_select`, `menu_back`, `menu_error`, `text_blip`, `encounter`,
`timing_start`, `timing_perfect`, `timing_great`, `timing_good`, `timing_weak`,
`timing_miss`, `attack_swing`, `attack_hit`, `critical_hit`, `miss`, `enemy_attack`, `player_hurt`,
`enemy_defeat`, `boss_defeat`, `party_ko`, `guard`, `heal`, `energy`, `revive`,
`tech_laser`, `tech_overdrive`, `tech_zap`, `tech_shield`, `tech_psi`, `stun`,
`drain`, `enemy_heal`, `item_use`, `grenade`, `duck_squeak`, `run_away`, `run_fail`,
`boss_roar`

Descriptions for each are in `scripts/audio.gd`. Volume can be mixed on the `Music`
and `SFX` audio buses.

## How the battle works

- **Crew:** NOVA (pilot, damage), BOLT (robot, tank/shields), ZIGGY (psychic
  botanist, healing).
- Choose a command for each crew member, then everyone acts in speed order.
- **BASH timing bar** (Deltarune-style): a marker slides across a bar. Press Z as
  it crosses the zone: PERFECT (a SMAAAASH!! critical), GREAT, GOOD, or WEAK if you
  press outside it. Don't press at all and you miss. Each crew member's marker
  moves at a different speed (NOVA fast, BOLT slow). The grades, zone sizes and
  speeds are in `scripts/data.gd`.
- **Rolling HP meters** (Earthbound-style): damage ticks the meter down over time.
  A crew member hit with "mortal damage" only goes KO when their meter reaches 0,
  so heal them fast and they survive.
- **Standard battle:** a random group of 2–3 enemies. **Boss battle:** OVERMIND.EXE,
  a haunted CRT monitor with two phases.

## Where things live

| File | What |
|---|---|
| `scripts/data.gd` | All stats, moves, items, enemies and battle text. Tweak freely |
| `scripts/sprites.gd` | Pixel art, drawn as letters. Edit to redraw characters |
| `scripts/battle.gd` | Battle flow, effects and UI |
| `scripts/audio.gd` | Audio cue system and HUD |
| `scripts/title.gd` | Title screen and cue list |
| `shaders/` | Wavy battle backgrounds, sprite flash/dissolve, transition swirl |

## Credits

Created by **Jim DeWitt**, Rochester Music Lab.

This demo is for **non-commercial use only**.
