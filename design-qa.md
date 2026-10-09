# Codex : validation visuelle et fonctionnelle

Date : 2026-10-07. Cible : menus natifs Godot de La Tour des Cendres.

## Référence et intention

Référence choisie : `/Users/dwenn/Documents/Codex/2026-10-07/le/outputs/01-codex-de-cuir.png`, 1536 × 1024 pixels. Le choix utilisateur demande le style de cette image et une organisation plus pratique, puis autorise directement l'implémentation.

Comparaison complète : référence et `outputs/codex-ui/native-inventory-1536x1024.png` ouverts ensemble, au même format. Deux pages, cuir, laiton vieilli, parchemin, encre brune et sélection violette sont conservés. L'organisation est adaptée volontairement aux fonctions réelles : bâton et deux anneaux, sac de 48 objets, fiche compacte avec détails dépliables, quatre disciplines dans le grimoire. Les objets, robes et catégories inventés dans la maquette ne sont pas ajoutés au jeu.

## Surfaces vérifiées

- Typographie : Cinzel pour les titres et Lato pour les contrôles et le corps. Les noms d'objets longs sont limités à deux lignes dans les cases, avec nom complet dans la fiche et l'infobulle. Corps de fiche 14–17 unités logiques. Les intitulés et statistiques ont été lus dans les captures natives 1440 × 900 ; ces vues sont assez lisibles pour vérifier ces régions sans recadrage supplémentaire.
- Mise en page : une seule navigation au-dessus du livre, équipement et recherche sur la page gauche, fiche et action sur la droite. Défilement indépendant du sac et de la comparaison ; action d'équipement fixe. Les statistiques du personnage restent sous l'équipement porté.
- Couleurs : texture réelle assombrie, texte brun foncé sur papier, ivoire sur les boutons, gains verts et pertes rouges avec signes +/− ; les pertes de pouvoirs sont explicitement nommées. Les cases à cocher gardent un contraste lisible sur le papier.
- Images : deux textures ImageGen réellement intégrées dans `assets/ui`, avec les illustrations d'objets et de sorts déjà présentes dans le jeu. Aucun changement d'illustration du monde ni d'équilibrage.
- Contenu : informations réelles issues de State, EquipmentPreview et SkillDetails. Les rituels sont consultables avec leurs raccourcis ; la sélection d'une fiche n'active pas une magie. Les règles de disponibilité des rituels et de fusion restent inchangées.

## Historique des corrections

1. P1 : recherche vide ne retournant aucun objet. Correction du prédicat pour accepter explicitement une requête vide. Parcours natif équipement et codex repassés.
2. P2 : bouton Fermer trop étroit, augmentant la hauteur de la navigation. Largeur minimale explicite ; les captures finales montrent la barre sur une ligne.
3. P1 : ancien placement du focus faisant défiler les menus avant la fin du calcul de leur géométrie. Suppression des prises de focus multiples, attente du placement des conteneurs puis défilement vers le contrôle réellement ciblé. Achat chez le marchand vérifié ; première option visible, vérifiée dans les quatre résolutions.
4. P2 : contraste des cases à cocher et densité du menu principal. Fond transparent pour les cases sur papier, espacement et taille du titre principal ajustés. Captures finales des options et du menu relues.
5. Fiabilité du runner : fenêtre maximisée et coordonnées non transformées dans le test historique. Le runner fixe désormais le mode fenêtré, transforme les coordonnées et force le rendu des captures lorsque le jeu est en pause.

## Fiche compacte — ajustement demandé après la première implémentation

Une fiche unique, sans onglets ni ligne « Remplace ». Illustration réduite à 72 unités, nom et bonus sans répétition pour les noms générés du catalogue. Le sélecteur Anneau 1 / Anneau 2 et l’action fixe restent explicites.

Le résumé présente l’impact réel sur la magie active puis les statistiques du personnage. Les quatre premières métriques sont prioritaires ; toute métrique négative supplémentaire reste affichée. Les effets montrent les chaînes, explosions, projectiles, braises, ralentissements et interruptions de la magie active, ainsi que les pouvoirs et les rituels prêts. Les détails complets conservent tous les changements, notamment les autres magies et les calculs intermédiaires. Les chiffres exacts sont accessibles au survol ou au focus clavier. Les coûts plus élevés sont des pertes, même si leur delta numérique est positif.

Les synergies utilisent le profil de combat et son snapshot de fusion. Les rangs figés, pouvoirs non cumulables, plafonds atteints, emplacements de rituels occupés et pertes de sorts sont expliqués seulement lorsqu’ils concernent l’objet. Le retrait d’un objet affiche « Si tu le retires ». Aucun bonus de combat ni comportement d’équipement n’est modifié.

Tests ciblés : Éclair et chaînes, spécialisation d’une magie inactive, explosion et braises, fusion figée et bonus généraux, Méditation et non-cumul, perte de Concentration mentale sans répétition par rituel, plafonds, rituels bloqués, perte d’une magie temporaire et maintien des pertes malgré la limite des gains affichés. Les tests de parité de prévisualisation couvrent toujours chaque recette et les deux emplacements d’anneaux.

## Preuves finales

- `outputs/equipment-ui/report.json` : aucun échec. Clics pour équiper les deux anneaux, retirer, acheter, vendre ; sac de 48 objets, filtres, conservation de sélection/focus/défilement, comparaison réelle et retour au jeu.
- `outputs/codex-ui/report.json` : 70 contrôles sans échec. Recherche au clavier, combinaison filtre/recherche, tri, chapitres, activation explicite, états vides, consultation des rituels et navigation. Fiche compacte : ouverture/fermeture des détails à la souris, état conservé en parcourant le sac, valeurs exactes au focus clavier, équipement explicite, retrait, action fixe et cas simple sans défilement.
- `outputs/ui-redesign/report.json` : aucun échec. Menu, nouvelle partie, choix initial au clavier, HUD, inventaire, grimoire, marchand, pause, options, niveau, mort et victoire.
- `outputs/codex-ui/resolution-report.json` : 28 captures exactes, aucune erreur de dimensions ou de débordement contrôlé. Rendu GPU natif dans un SubViewport à 1536 × 1024, 1440 × 900, 960 × 600 et 1920 × 1080. Le minimum 960 × 600 reproduit la mise à l'échelle du canvas logique 1440 × 900 du jeu ; les images ne sont pas agrandies après capture. Les contrôles souris/clavier sont testés séparément dans une vraie fenêtre.
- Tests de calculs : EquipmentPreview, 606 contrôles sans erreur ; synthèse compacte, 33 contrôles sans erreur ; compétences, 101 contrôles sans erreur.
- Import Godot 4.7.2 et `git diff --check` sans erreur.

Captures finales : `outputs/codex-ui/native-inventory-1536x1024.png`, `native-skills-1440x900.png`, `native-options-1440x900.png`, `native-initial-1440x900.png`, `native-menu-1440x900.png` et variantes 960 × 600 / 1920 × 1080.

CSS et densité navigateur : non applicables, interface native Godot. Vérification sur macOS ; pas de test Windows ou de manette physique. Les sauvegardes utilisées sont exclusivement des fichiers QA. Aucun export de distribution ni déploiement. La publication Git de tout le diff est autorisée par l’utilisateur ; son résultat est vérifié séparément après les contrôles locaux.

## Contrôles reproductibles

```sh
./tools/godot.sh --headless --path . --editor --import --quit
./tools/godot.sh --headless --path . tests/equipment_preview_test.tscn -- --test
./tools/godot.sh --headless --path . tests/equipment_summary_test.tscn -- --test
./tools/godot.sh --headless --path . tests/skills_test.tscn -- --test
./tools/godot.sh --path . tests/equipment_ui.tscn -- --qa
./tools/godot.sh --path . tests/codex_ui.tscn -- --qa
./tools/godot.sh --path . tests/ui_redesign.tscn -- --qa
./tools/godot.sh --path . tests/codex_resolution.tscn -- --qa
```

Ajouter `--preview` après `--qa` au runner `codex_ui.tscn` laisse l'aperçu ouvert sur l'inventaire après les tests, avec une sauvegarde de démonstration isolée.

Pas de défaut P0/P1/P2 restant dans les surfaces vérifiées. La maquette montrait davantage de variété d'objets que le catalogue graphique actuel ; les deux familles réelles d'équipements gardent leurs illustrations existantes.

final result: passed


## 2026-10-09 — Level-up tarot cards

Source visual truth: `outputs/level-up/selected-concept.png` (third displayed ImageGen concept, 1483×1061). The user requested its implementation with all existing combat information retained, clear current/next skill levels, and explicit skill categories.

Implementation: `outputs/level-up/reference-size.png`, exact native GPU SubViewport 1483×1061, density 1; no enlargement or normalization. Reference and implementation opened together, both level 3 with Flash Freeze / Chain Lightning / Ring of Fire and Chain Lightning selected. Actual gameplay behind the modal is the village rather than the illustrative dungeon in the concept.

Full-view comparison: three independent illustrated parchment cards, brass borders, dim game background, central confirmation and secondary reroll. Intentional changes: shorter illustrations and a denser detail area preserve the complete live statistics requested by the user; categories and compact current/next rank lines replace the mock's sparse summaries. Existing Cinzel and Lato fonts are retained. Actual skill icons identify abilities sharing an elemental illustration. Cards stay aligned rather than lifting the selected one, keeping comparative rows stable.

Required fidelity surfaces:
- Typography: Cinzel titles; Lato categories, compact 15-unit level comparisons, descriptions and complete combat details. Text checked at 1440×900 and 960×600. Long descriptions wrap inside their own scroll viewport; confirmation remains visible.
- Spacing: 48-unit side margins, 20-unit card gaps, fixed footer. Three and four choices fit the game's 1440×900 logical canvas. Screenshot requested at 1920×1080 was constrained by macOS to 1728×1080; report records the actual dimensions, not an assumed 1920 capture.
- Colors: ivory/gold on dark game backdrop, dark ink on warm parchment, a single discreet current/next rank line. Selection uses a brighter border/paper and the named confirmation button, without a redundant status footer.
- Images: six generated illustrations and one generated frame are integrated, preserving aspect ratio; provenance and final prompts are in `assets/ui/level-up/SOURCES.md`. No illustration placeholders.
- Content: `SkillDetails.text(id,true)` is reused in full. Learned ranks and equipment-adjusted ranks are differentiated, including binary effects granted by equipment. Fusion creation/refresh displays snapshot character levels instead of fictitious upgrade ranks. Category labels distinguish primary spells, active rituals, general/elemental/major passives and fusion spells.

Focused comparison: `outputs/level-up/equipment-fusion-passive.png` was read at native 1440×900 to inspect current/next ranks, equipment values, fusion snapshot explanation and full damage/DPS/mana comparisons. `four-cards-960x600.png` checks the fourth choice and fixed confirmation at minimum desktop size. No extra cropped image was needed because these regions were readable in the native images.

Correction history:
1. P1: inherited codex frame covered text with oversized leather edges. Replaced it with a dedicated generated narrow tarot border and corrected content margins; final captures show unobstructed text.
2. P1: inner paper intercepted card clicks. It now passes pointer events to the selectable card; native mouse tests select all four choices.
3. P2: bulky current/next rank panel. Replaced the entire panel and its headings with one compact line, such as `Lv. 2 → 3`; fusion snapshots and equipment adjustments remain explicit.
4. P2: image height reduced the useful detailed text area. Reduced illustration height and removed redundant new-knowledge copy, retaining the complete statistics.
5. Removed the redundant Select this knowledge / Selected footer, returning its height to detailed statistics.
6. QA runner: route mouse/keyboard events directly through the native viewport to avoid desktop focus/coordinate interference. Final run reports no failures or shutdown warnings.

Validation: 97 native UI checks, 101 skill/combat regression checks, 92 UX regression checks, all passed (290 total). UI coverage includes three/four choices, card selection without learning, explicit confirmation, keyboard confirmation, multiple pending levels, reroll cost/disabled state, equipment ranks, binary passives, fusion snapshots and exhausted-choice continuation. Save paths are QA-only. Windows and mobile were not tested; this is a desktop Godot surface. Git diff whitespace check passed.

Findings: no remaining actionable P0/P1/P2 findings. Long statistical descriptions intentionally scroll inside the card while its level header and the confirmation remain fixed. Native screenshot evidence is local. This report records source validation, not an export or release.

final result: passed
