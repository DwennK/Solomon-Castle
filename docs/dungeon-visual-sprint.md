# Sprint visuel du donjon — 7 octobre 2026

Cette passe complète les intérieurs V3 sur les cinq axes demandés.

- Éclairage : exposition du sol réduite vers les bords, suppression du voile lumineux uniforme des salles, sources chaudes/froides plus localisées, scintillement désactivé avec les effets réduits.
- Identité : six compositions déterministes — chapelle, bibliothèque brûlée, prison, crypte, laboratoire et ruines. Les mosaïques sont réservées aux chapelles et cryptes ; les salles de gardien restent cérémonielles.
- Architecture : mobilier mural, niches, arches brisées, murs effondrés, piliers de hauteurs différentes et seuils décoratifs. Les gros décors sont placés sur les cellules solides, avec vérification des ouvertures avant placement.
- Sols : poussière, éclats, suie, flaques, papiers et mousse en périphérie. Le placement évite les coffres, urnes, entrées et sorties ; les décors n’ajoutent ni collision ni interaction.
- Personnages : ombres de pied resserrées, ombre douce opposée à la lumière dominante, teinte ambiante interpolée et léger éclairage du contour. Le flash de coup, le gel, la combustion et la dissolution restent indépendants. Les nouveaux contacts sont limités aux personnages du donjon ; le village conserve son éclairage antérieur.

La grille, la génération, les collisions, les sauvegardes et le HUD sont conservés. `DungeonDressing` prépare les compositions et les traces sans modifier les données de partie ; sa référence au renderer parent est faible pour éviter un cycle de références. `DungeonInterior.sample_light` fournit une teinte locale aux acteurs, actualisée toutes les 120 ms puis interpolée. Les textures ne sont pas régénérées par frame.

## Assets et provenance

Création avec l’outil intégré ImageGen, alpha conservé. Les deux originaux sont consommés directement par régions d’atlas dans Godot, sans retouche bitmap :

- `assets/art/dungeon_v4/room-decor.png` — 1774 × 887, huit éléments architecturaux.
- `assets/art/dungeon_v4/floor-decals.png` — 1536 × 1024, six textures superposables au sol.

## Vérification

```sh
./tools/godot.sh --headless --path . --editor --import --quit
./tools/godot.sh --headless --path . tests/tests.tscn -- --test
./tools/godot.sh --path . --resolution 1440x900 tests/dungeon_sprint_qa.tscn -- --qa
./tools/godot.sh --path . --resolution 1440x900 tests/visual_v2.tscn -- --qa
./tools/godot.sh --headless --path . -- --qa --qa-playthrough
```

Le runner du sprint utilise `qa_dungeon_sprint.json`, crée son dossier de sortie, couvre les six styles, trois étages, les passages, les coffres, l’éclairage des acteurs, les effets réduits et les tailles 1440 × 900 et 960 × 600. Le jeu reste une application desktop ; le format compact n’est pas un test mobile.

Résultats confirmés : 94 791 contrôles, 1 300 étages générés, 15 captures et contrôles du sprint sans erreur ; 16 captures de régression des sorts, états visuels et mort des ennemis sans erreur. Mesure native sur Apple M4, scène figée à l’étage 13 avec animations et lumières actives : médiane 8,06 ms, p95 10,02 ms sur 180 frames. Cette mesure courte ne constitue pas un benchmark de combat dense ni une garantie sur d’autres machines.

Captures et journaux : `outputs/dungeon-v4/`. Les captures de régression des sorts sont produites par le runner existant dans `outputs/visual-v2/`.

Le parcours automatisé des 13 étages passe sans erreur en 69 secondes, avec les aides QA existantes (rangs, invulnérabilité, régénération de mana et simulation accélérée). Les journaux finaux d’import, de rendu, de parcours et d’export ne signalent aucune erreur ni alerte.

Archive locale : `outputs/dungeon-v4/La-Tour-des-Cendres-Sprint-Visuel-macOS.zip`. Export macOS universel, signature ad hoc vérifiée, démarrage du binaire exporté vérifié en headless QA. Les captures de jeu proviennent de Godot natif sur les sources, pas de l’archive. Aucun nouvel export Windows, aucune notarisation, aucun commit, push ou déploiement dans ce sprint.

## Correction d’intégration après retour visuel

Le découpage régulier 4 × 2 ne correspondait pas aux contours de la planche générée : le mur ruiné dépassait sa cellule et une partie apparaissait dans la bannière voisine. `DECOR_REGIONS` définit maintenant huit rectangles mesurés sur l’alpha, avec marges transparentes. Les sprites V3 sont également recadrés par leurs contours visibles. Les fichiers PNG d’origine sont conservés sans retouche.

Les éléments de 170–183 px étaient trop hauts pour les façades de 106 px. Les hauteurs sont maintenant adaptées au support : fenêtre 80 px, niche 94 px, mobilier 108–118 px, piliers jusqu’à 120 px. Les pieds du mobilier reposent légèrement devant la jonction mur/sol, tandis que fenêtres et bannières restent sur la façade. L’origine des faisceaux suit les fenêtres. Le placement contrôle chaque cellule traversée par la largeur du décor ; les grandes arches ajoutées automatiquement aux seuils ont été retirées pour ne pas déborder sur les ouvertures.

`DungeonDecoration` place chaque sprite et son ombre de contact dans le même parent trié par Y que les acteurs. Les décors debout ne sont plus dessinés dans le sol : un acteur passe devant ou derrière selon la position de ses pieds. La génération, les collisions et les sauvegardes ne changent pas.

Validation dédiée : `./tools/godot.sh --path . --resolution 1440x900 tests/decor_integration_qa.tscn -- --qa`. Le test inspecte les bords alpha des huit régions, les hauteurs et l’appartenance au tri Y ; il vérifie aussi l’occlusion par lecture des pixels réels avec une sonde devant et derrière une bibliothèque. Neuf captures couvrent l’étage 2, les six styles, une vue rapprochée et le format 960 × 600. Rapport et captures : `outputs/decor-fix/`. Les tests généraux repassent avec 94 791 contrôles et 1 300 étages générés sans échec.

La version corrigée est exportée séparément dans `outputs/decor-fix/La-Tour-des-Cendres-Decors-Corriges-macOS.zip`. Un jeu déjà lancé doit être relancé pour charger ces scripts ; aucune partie joueur n’est réinitialisée par la correction.

## Prompts exacts

### Architecture

Use case: stylized-concept. Asset type: modular wall set-dressing sprite atlas for original dark fantasy action RPG La Tour des Cendres. EXACT 4 columns by 2 rows of EQUAL cells, wide 2:1 canvas, transparent background, eight isolated objects. Each complete object INCLUDING all ornaments entirely within central 75% of its cell. Large transparent gutters; nothing crosses a cell edge. No text, no labels, no grid, no ground plane or background. Hand painted pre-rendered gothic architecture, highly crafted realistic stylization, aged ash limestone, tarnished bronze, desaturated midnight teal, warm ivory highlights, upper left lighting, three quarter overhead camera looking down 40 degrees, fronts toward viewer. Row1 left to right: 1 a ruined chapel altar with low carved stone table, ivory candles and a broken winged stone relief rising behind it, muted crimson hanging cloth; 2 a charred oak bookcase FULL of dusty ochre leather books, leaning shelves, small scrolls, gothic outline, very clear library silhouette; 3 a recessed iron-barred prison niche built into a rough pointed stone frame, hanging broken chains inside, no prisoners; 4 a wide carved tomb embedded in a stone wall niche with a reclining stone knight effigy, dark sepulchral recess. Row2 left to right: 5 an alchemist workbench with antique copper alembic, curved tubing and small glowing jade green glass bottles on a dark oak table, a narrow stone backing; 6 a broken gothic arch with one tall pillar, a jagged remaining curved arch and crumbled stone base, no complete lintel spanning the cell; 7 a fractured wide chunk of stone wall with broken battlement edges, exposed masonry, a compact rubble base, broad low silhouette; 8 a tattered long muted wine-red fabric banner hanging from an antique bronze horizontal rod, embroidered pale gold abstract sun sigil, torn asymmetrical lower edge. Clear varied silhouettes at 140 pixels height, no magic particle clouds, no halos, no cast shadow beyond silhouette. Genuine alpha background.

### Traces au sol

Use case: stylized-concept. Asset type: production FLOOR DECAL atlas for overhead gothic dungeon game. EXACT 3 columns by 2 rows, SIX equal SQUARE cells in wide 3:2 canvas. Real transparent background, not black. Each subject must remain within central 70% of its cell with wide empty transparent margins, no grid lines, text, labels or scenery. Strict orthographic TOP DOWN view, all subjects flat on ground, soft hand painted photorealistic game textures with finely feathered irregular transparent edges. Muted dark fantasy palette; subtle readable details, not busy. Top row: 1 scattered pale limestone dust and tiny worn stone chips, an irregular crescent shaped accumulation at a floor edge, transparent holes between specks; 2 irregular dark charcoal soot stain with tiny burnt embers and charred splinters, diffuse feathered alpha; 3 shallow irregular dark blue grey puddle on transparent ground, very faint cold reflected light along one edge, no bright white gloss. Bottom row: 4 flat broken stone floor slabs and a few thin cracks, worn ash grey rubble pieces spread sparsely, transparent gaps; 5 scattered yellowed loose parchment pages and two closed battered books lying FLAT on floor, no readable lettering; 6 sparse patches of desaturated dark green moss and tiny roots following a stone joint, no flowers. Completely isolated decals on actual alpha, ready to overlay on game floors without any rectangular backing or borders. No large rocks or standing objects, no deep craters, no horror gore, no ground square, no decorative frames.
