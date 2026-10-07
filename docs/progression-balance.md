# Ascent progression

Every new ascent starts at level 1, including unlocked difficulties. Victory unlocks the next difficulty; the explicit fresh-ascent button clears skills, fusion snapshots, equipment, gold, lessons, potions, cooldowns and floor state. Difficulty unlocks and preferences remain. The fifth difficulty still forces hardcore. Repeating that final difficulty starts another fresh ascent at the same difficulty. Death/checkpoint rules are unchanged.

Loading an existing save never resets the character or its earned XP. Existing NG+ characters retain the old statistical difficulty scaling until they begin a fresh ascent. A failed new-ascent save restores the completed character in memory.

## XP budgets

`ProgressionRules` owns both the unchanged level threshold and the new floor budgets. A complete regular clear targets these cumulative levels:

| Floor | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Target | 4.4 | 6.7 | 8.8 | 11 | 13.8 | 16.5 | 19 | 22 | 25 | 28 | 31 | 33.5 | 36 |

The floor budget is the difference between successive cumulative XP totals, rounded up. Layouts larger than eight rooms add 1% per extra room, capped at 4%. Ordinary enemies share the regular budget according to a fixed threat weight; elites count 35% more. On boss floors, 24% is reserved for the boss. The final floor divides that share 2:1 between the final boss and guardian. Optional sentries add 8% of the floor budget, alongside their existing rare reward. Skipping enemies forfeits their XP; player level does not change rewards or enemy strength.

Rewards are stored on each enemy record during generation. Legacy floors receive the same allocation once when loaded, including dead records in the calculation. No XP is retroactively awarded, no killed enemies respawn, and remaining enemies never inherit rewards from dead ones. Saved floors retain their allocations after kills, portal visits and reloads. Newly generated floors have no legacy per-kill formula.

Across 20 seeds and all five difficulties (1,300 floors), full regular clears reach levels 4 / 11 / 22 / 31 / 36 at floors 1 / 4 / 8 / 11 / 13. Completing every optional trial finishes at level 37. These are progression checks, not proof every build can clear every combat.

## Power outside XP

One purchasable lesson is available initially, with another unlocked on reaching floors 5, 9 and 13: four maximum per ascent. Lessons keep the existing gold cost and grant an eligible upgrade without changing level or XP. Both the UI and the State purchase function enforce availability. Existing learned lessons are not removed, even if they exceed the new limit. Equipment continues to affect effective ranks without learning skills; all equipment and its reward history reset between ascents.

## Difficulty

Fresh ascents use +12% enemy health and +10% damage per difficulty step (maximum +48% / +40%). Elite pack leaders gain a further 25% health and 15% damage, with increasing frequency from difficulty 1 through 4, and a gold rune marker plus persistent health bar. Difficulty 2 mixes imps into pursuit groups; difficulty 3 adds ghosts to ambushes. Bosses add a delayed hazard every other attack from difficulty 1 and another every third attack from difficulty 3. Existing attack telegraphs and movement speeds are preserved. After floor 4, regular-enemy health adds a quadratic depth term (+0.03 per squared floor beyond 4), reaching a 5.35 multiplier on floor 13 instead of 2.92. Later bosses gain 7% health per floor beyond 4, reaching 1.63 on floor 13; this follows the acquired build strength within an ascent.

## Reproducible verification

Use `-- --test` to isolate all save writes. Run `tests/progression_test.tscn` for generated budgets, migration invariants, fresh ascents, save failures and lessons. Add `--visual` for native victory/initial-spell/teacher UI checks at 1440×900 and 960×600. `tests/progression_campaign_audit.tscn` runs 12 continuous attempts (four spells, difficulties 0/2/4) with natural offered upgrades, finite earned supplies and movement. Run it with `--headless --disable-render-loop --fixed-fps 60`; no invulnerability or stat injection is used. The bot knows layout for navigation, uses simple kiting and hazard avoidance, and omits village services and optional trials. It stops at death or navigation timeout. Automated results do not establish human enjoyment or perfect balance.
