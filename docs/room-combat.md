# Room-centred combat

Regular encounter packs now wait until the player is 1.5 tiles inside their room.
A deliberate hit alerts the entire pack immediately, with a 0.45-second reaction
window (0.9 seconds for the existing dormant ambushes). Optional trial statues
still require accepting the trial. Boss and legacy enemies without room metadata
retain their existing activation rules.

Archers, sorcerers and imps select interior firing positions with line of sight,
staying away from doors. Ordinary melee guards pursue up to 128 pixels outside
their room bounds; hunters can pursue up to 448 pixels. Guards walk back when
the player retreats farther. Returning does not heal enemies or reset encounters.
Players can still retreat, and existing boss seals remain the special locked fights.

New layout version 3 reserves two combat rooms of at least 12 by 12 tiles,
with open octagonal interiors. Other rooms retain varied shapes and pillars.
Some main links are five tiles wide instead of three; the optional branch and
boss seal retain their narrower approaches. The layout remains seeded and
mirrored/transposed. Existing saved geometry is never regenerated. Saved rooms
with encounter metadata receive the new combat behavior, with awakened state
restored on reload.

Validation:

- `tests/room_combat_test.tscn`: 1,300 generated floors, deep-entry and hit
  activation, warning idempotence, real movement and pursuit, defensive positions,
  unchanged health, save/reload and legacy activation. `--visual` also captures
  two generated combat rooms at 1440 by 900 in the native Godot application.
- `tests/tests.tscn`: 1,300 generated floors, entity/exit reachability, key access
  and closed boss seals, plus the existing gameplay regression checks.
- `tests/encounter_test.tscn`: 90 layouts, optional routes, trials, warnings,
  charges and persisted encounter state.
- `tests/loot_test.tscn`: reward budgets and actual spell/container interactions.

Run with `./tools/godot.sh --headless --path . res://tests/room_combat_test.tscn -- --test`
or omit `--headless` and append `--visual` for desktop captures. Test saves use
isolated QA paths; no campaign save is overwritten.
