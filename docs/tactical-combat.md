# Tactical encounters and pacing

This pass changes enemy encounters and scenery, not player spell specializations,
spell profiles, mana costs, damage tables or the skill tree.

## New floors

Room order follows the entry-connected room graph. Smaller combat rooms alternate
between two-enemy skirmishes and three/four-enemy pressure groups. Five/six-enemy
set pieces occupy the spacious rooms (at least 12 by 12 tiles). Each floor also reserves one smaller room as a sanctuary, and keeps
the existing optional reliquary challenge. Branching routes remain freely usable;
the schedule does not lock doors or require visiting every room in order.

Crossfire archers begin on opposing firing lanes and favor their original positions
when repositioning. Warden guards stand in front of their protector relative to
the approach. Pursuit groups combine a charging hunter with an artillery caster.
Ambushers occupy the sides of a room. Higher difficulty retains its imp/ghost
composition substitutions. New enemies avoid overlapping props and one another.

Pressure groups and set pieces have one destructible brazier. Spacious combat
rooms may also receive one off-centre masonry pillar, with real collision and
projectile occlusion. Doors and the centre route remain clear.

## Counterplay and elites

- Missing a charge exposes the hunter for 1.2 seconds. A successful charge does
  not grant that window.
- Artillery and ritualist casts last 1.1 seconds and mark a fixed target area.
  Damage totaling 12% of their maximum health during the cast interrupts it.
  Freeze and fear also interrupt. An interruption cancels the attack and exposes
  the caster for 1.1 seconds. Sustained spell hits count toward the threshold.
- Exposed enemies show an `OPEN` marker and receive 50% more damage. Recovery
  and a cooldown prevent immediate recasting. Boss cast rules are unchanged.
- From floor 3, set pieces include one named elite: **Bulwark** reduces frontal
  damage by 75%, with a visible shield and limited turning speed; flanking,
  freezing or frightening it bypasses the shield. **Ritualist** uses the marked,
  interruptible area attack. **Brood** splits into two small weaker hunters once.
  Children have a spawn warning, never split again, and grant no extra XP/loot.

A spell hit lights a brazier's 0.7-second warning. Its 120-pixel explosion hurts
both monsters and the player (player damage is 40% of monster damage), respects
walls and fires only once. The spent prop remains spent across reloads. Leaving
the floor during its warning consumes the brazier without carrying its temporary
explosion into another floor, consistent with other temporary combat effects.

The sanctuary restores 20% of maximum health and 40% of maximum mana once.
It cannot be consumed at full resources or while active enemies are within 600
pixels. Its ordinary interaction prompt explains the amounts and restriction.

## Persistence and economy

Existing floor geometry, encounter records and earned rewards are preserved.
New layouts receive the room schedule, scenery and elite affixes. Existing hunters
also gain the miss-counter window. Split children and consumed props persist in
the floor's ordinary save records; dead parents never respawn on reload.

XP remains on the established floor budget, redistributed by threat rather than
monster count. Fragments have zero threat/reward even if a floor is migrated.
Chest/urn budgets remain unchanged. New tactical floors normalize enemy gold to
the former population's expected budget, so fewer monsters do not reduce the
campaign economy. Fragments are excluded from reward carriers.

## Validation

- `tests/tactical_combat_test.tscn`: 650 generated floors plus real damage,
  cast interruption, shield direction, projectile collisions, friendly fire,
  splits, normal sanctuary interaction, repeated-use and save/load checks.
- Core, loot, progression and room-combat suites: 1,300 floors each, including
  reachability, sealed boss access, reward bounds and legacy behavior.
- Encounter suite: optional routes/trials, warnings and actual charging behavior.
- Native `--visual` captures at 1440 by 900 cover all elite cues, the explosive
  warning, a generated set piece and a generated sanctuary.

Run `./tools/godot.sh --headless --path . res://tests/tactical_combat_test.tscn -- --test`.
For captures, omit `--headless` and append `--visual`. QA saves are isolated from
player saves. Native validation covers macOS; no Windows execution is claimed.
