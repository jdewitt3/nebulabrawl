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
**green** means a file was found and is playing, **blue** means a generated fill-in
is playing (see below), and **gray** means there's no sound yet.
The title screen also has an **AUDIO CUE LIST** page for auditioning every cue. It
uses the same colors.

### Setting cue volumes

On the **AUDIO CUE LIST** page, pick a cue and press **Z**. It plays, and a small
mixer opens:

- **VOLUME:** left/right adjusts the cue's level in 1 dB steps, from −30 to +12 dB.
  Music changes live while it plays. Sound effects replay on each change so you
  can hear the difference.
- **PLAY AGAIN** restarts the cue, and **RESET TO 0 DB** clears its adjustment.
- **DONE** (or X) saves your settings.

Settings are saved to `audio/volumes.cfg`, so the mix stays with the project and
applies everywhere the cue plays in-game. In the cue list, a yellow dot marks cues
with a custom volume. The setting is a trim on top of everything else, so fades,
crossfades and the danger layer all still work.

### Fill-in sounds

Want to play the demo before every sound effect exists? The game can generate a
rough **fill-in** for any SFX cue that has no file. Each fill-in is made in code
from a recipe that suits its cue: a punchy thud for `attack_hit`, a rising sparkle
for `heal`, a squeak for `duck_squeak`, a crackly digital roar for `boss_roar`, and
so on. They're placeholders to fill the silence, not finished sounds.

On the **AUDIO CUE LIST** page, the first row of the SFX column is
**[FILL-IN SOUNDS...]**. Press **Z** on it to open a panel with:

- **GENERATE FILL-INS FOR N MISSING CUES:** makes one for every SFX cue with no
  file and no fill-in yet.
- **NEW TAKES FOR ALL:** swaps every fill-in for a variation on the same recipe.
- **CLEAR ALL:** removes every fill-in, so those cues go silent again.

New takes and clear-all replace takes you may have picked, so they ask you to press
**Z** a second time.

You can also work on one cue at a time. Pick a cue and press **Z** to open its mixer:

- A cue with no sound has a **MAKE FILL-IN** row.
- A cue with a fill-in has **NEW TAKE**, which rolls a variation, and
  **CLEAR FILL-IN**.
- The mixer and the bottom line of the cue list show where the sound comes from.
  For example: `FILE: ATTACK_HIT.WAV`, `FILL-IN, TAKE 2` or `NO FILE YET`.

Volume trims work on fill-ins just like on files.

**Your files always win.** Fill-ins are rendered in memory while the game runs.
Nothing is ever written to `audio/sfx/`, so a supplied file can't be overwritten.
Drop in a file named after a cue and it plays instead of that cue's fill-in, starting
the next time you open the cue list, or at the next launch. If you delete the file
again, the fill-in comes back.

The list of cues using a fill-in, and which take each is on, is saved to
`audio/fillins.cfg`. Each take always sounds the same, so the set you chose comes
back on every launch. Rendering happens in the background, which takes about half a
second for all 39 cues. The recipes are in `scripts/sfx_synth.gd` if you want to
tweak one.

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
| `scripts/sfx_synth.gd` | Fill-in sound effect recipes and the synth that renders them |
| `scripts/title.gd` | Title screen, cue list and fill-in panel |
| `tests/fillin_test.gd` | Checks for the fill-in sounds (see below) |
| `shaders/` | Wavy battle backgrounds, sprite flash/dissolve, transition swirl |

## Checks

```
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -- --test=fillin_test
```

This checks that:

- every SFX cue has a recipe that renders to an audible, unclipped sound
- generate, new take and clear all work, including from the menu
- a supplied file always beats a fill-in
- nothing is written to `audio/sfx/`

It prints `ok` or `FAIL` for each check and exits non-zero if anything fails. It works
in a scratch folder, so it never touches your `audio/sfx/`, `audio/fillins.cfg` or
`audio/volumes.cfg`.

## Credits

Created by **Jim DeWitt**, Rochester Music Lab.

This demo is for **non-commercial use only**.
