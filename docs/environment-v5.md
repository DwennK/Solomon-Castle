# Environnements V5 — maçonnerie, sols et mobilier

## Direction visuelle et intégration

Les pièces utilisent une palette commune de pierre calcaire, d’ardoise et de pierre brune. Trois pavages remplacent les anciennes textures : grandes dalles régulières, carrés d’ardoise et chevrons. Les joints suivent une grille mondiale de 64 unités, avec une période de 256 unités ; une bordure d’ardoise continue relie les pièces aux couloirs. Les chapelles et cryptes reçoivent une marqueterie encastrée de 4 × 4 cases. Les anciens décalques aléatoires ont été retirés.

Les murs sont reconstruits depuis les limites réellement fermées de la grille : façade nord en assises, corniches, plinthes, retours latéraux et murs sud en coupe basse. Les ouvertures restent dégagées. Les six ambiances (chapelle, bibliothèque, prison, crypte, laboratoire, ruines) emploient des travées de mobilier définies ; les emprises incompatibles sont omises. Les pieds des objets, leurs ombres de contact et le tri vertical des acteurs partagent le même repère.

Coffres fermés/ouverts, urnes, braseros et escalier ont été régénérés dans la même perspective. Les coffres gardent la même largeur dans les deux états. Les objets interactifs utilisent leur position visuelle réelle ; leurs identifiants et états sauvegardés restent identiques. L’escalier conserve sa position de gameplay. La géométrie de collision et la génération des étages ne changent pas.

Les lumières chaudes des braseros et froides des fenêtres utilisent des maillages mis en cache, limités aux cases de sol visibles depuis leur source. Elles ne colorent plus le vide extérieur ni une autre salle à travers un mur. Le mobilier reçoit la teinte ambiante locale ; les effets réduits stabilisent l’intensité des nappes lumineuses.

## Assets

Neuf images originales ont été générées avec l’outil ImageGen intégré le 7 octobre 2026. Les fichiers livrés par l’outil sont copiés intacts dans `assets/art/dungeon_v5/`. Aucun détourage ou repeint programmatique : les zones alpha sont sélectionnées à l’exécution via `AtlasTexture`, avec une marge transparente vérifiée. Aucun asset de jeu tiers n’est incorporé.

| Fichier | Usage |
| --- | --- |
| limestone-floor.png | Pavage calcaire |
| slate-floor.png | Ardoise, bordures et couloirs |
| brick-floor.png | Pierre brune en chevrons |
| inlay-floor.png | Marqueterie géométrique intégrée au pavage |
| wall-masonry.png | Assises de mur |
| furniture.png | Autel, bibliothèque, grille, tombeau, établi, banc ruiné |
| architecture.png | Pilastre, fenêtre, niche et bannière ; niche réservée, non utilisée |
| interactables.png | Coffre fermé/ouvert, urne, brasero |
| stairs.png | Escalier de pierre |

## Validation reproductible

```sh
./tools/godot.sh --headless --editor --path . --import
./tools/godot.sh --path . tests/environment_qa.tscn -- --qa
./tools/godot.sh --path . tests/decor_integration_qa.tscn -- --qa
```

- QA native macOS à 1440 × 900 et 960 × 600 : six ambiances, étages 2/8/13, jonction de couloir, coffre ouvert/fermé, urne brisée, rechargement et effets réduits. Captures et rapport dans `outputs/environment-v5/` (ignorés par Git).
- QA environnement : 40 811 contrôles sans erreur, dont 18 combinaisons graine/étage, limites alpha, emprises, frontières des murs, cases éclairées, déterminisme et préservation des données sauvegardées.
- QA d’occlusion existante : neuf captures, aucune erreur ; contrôle effectif du passage du joueur devant/derrière les meubles.
- Suite gameplay : 94 791 vérifications, 1 300 étages générés, aucune erreur.
- Parcours automatique des 13 étages : aucune erreur. Parcours assisté par les rangs QA, invulnérabilité, récupération de mana et simulation ×5 ; ne constitue pas une partie humaine non assistée.
- Sonde locale sans VSync, même scène étage 13 à 1440 × 900, 240 images après échauffement : intervalle médian 8,78 ms (avant 7,70 ms), p95 10,04 ms (avant 9,26 ms). Mesure ponctuelle sur Apple M4, sans garantie de performances sur d’autres machines.
- Export macOS universel reconstruit, signature ad hoc vérifiée et exécutable lancé nativement sans erreur de chargement. Archive locale : `outputs/environment-v5/La-Tour-des-Cendres-Environnements-macOS.zip`. Export non notarié ; Windows n’a pas été testé dans cette passe.

## Prompts ImageGen exacts

### limestone-floor.png

```text
Production game environment texture, square seamless tileable albedo, strict orthographic TOP DOWN flat plane, no perspective. A carefully laid medieval abbey floor made of ash-grey limestone rectangular paving slabs in a regular running-bond pattern. Exactly four horizontal courses across the image, each course has two long rectangular slabs across the width, every other course offset by half a slab. Straight aligned joints, narrow charcoal grout 1 percent width, subtle bevels, smooth worn walking surfaces, lightly chipped corners. Restrained desaturated warm-grey limestone with faint natural mineral grain, low contrast. Uniform soft ambient lighting with no illumination hotspot, no cast shadows, no vignette. The paving continues seamlessly through all four edges: repeating tile suitable for a large dark-fantasy dungeon room. AAA hand-painted realistic game material, clean deliberate architecture, understated fine weathering. No moss patches, no scattered objects, no random rubble, no gold, no markings, no room border, no medallion, no extruded blocks. FULL BLEED opaque texture, not a photograph of a floor patch on a background.
```

### slate-floor.png

```text
Production game environment texture, square seamless tileable albedo, strict orthographic TOP DOWN flat plane, no perspective. A carefully laid medieval crypt floor of dark desaturated blue-grey slate SQUARE paving slabs. Exactly a 4 by 4 grid of evenly sized square stone slabs, narrow deep charcoal joints, subtle softened bevels and naturally worn broad surfaces. Orderly straight parallel grid. Rich fine slate grain and subtle scratches but very low contrast and no distracting cracks. Uniform ambient lighting, no hotspot, no vignette, no cast shadows. The paving continues seamlessly through all four edges, repeating texture for a large gothic dungeon. AAA realistic hand-painted material, coherent architectural scale. No objects, debris, moss, runes, border, medallion, gold or decorative inset. Full bleed opaque texture, every pixel is this paving material, not a floor patch against a background.
```

### brick-floor.png

```text
Seamless tileable square game material texture, full bleed opaque, exact orthographic TOP DOWN with no perspective. A medieval monastery floor of SMALL narrow rectangular charcoal-brown fired stone pavers laid in an orderly herringbone parquet pattern. Warm desaturated umber-grey, subtly varied pavers, very narrow soot-grey mortar, smooth worn surfaces with fine grain, no deep cracks. Approximately eight paver widths across the image so the pattern is delicate rather than chunky. Uniform ambient illumination, no vignette, no shadows, no highlighted center. Carefully crafted AAA hand-painted realistic dungeon floor, clean elegant geometric organisation. Pattern continues across all four edges. No objects, no debris or moss, no border, no medallion, no runes, no background. Architectural paving albedo only.
```

### wall-masonry.png

```text
Full bleed seamless horizontally tileable architectural texture for a gothic stone dungeon WALL, not a floor. Wide landscape 2:1 ratio. Straight orthographic FRONT elevation with zero perspective, uniform diffuse light, desaturated warm grey ash limestone masonry matching medieval cathedral walls. Exactly four horizontal courses of regularly dressed rectangular ashlar blocks, staggered vertical joints, each block about twice as wide as high, narrow dark mortar. Modest hand-carved bevels and fine grain, subtle variations, quiet polished realistic game material, medium-dark value. NO arches, windows, pillars, reliefs, ornaments, strong lighting, moss, dirt patches or dramatic damage. Top and bottom courses continue beyond image edges, and left/right edges connect seamlessly. This is a uniform repeating stone material, no border, no trim and no background.
```

### furniture.png

```text
Production 2D sprite atlas for an original gothic dungeon. EXACTLY 3 columns x 2 rows, six separate complete objects, landscape 3:2 image, each object entirely within central 75 percent of its equal cell, wide transparent gutters. Camera: orthographic elevated FRONTAL view looking downward 35 degrees, front edges HORIZONTAL, left and right edges symmetric, NOT isometric and NOT rotated in plan. Same camera and diffuse upper-left ambient light for every object, no hard cast shadow. Restrained desaturated warm ash limestone and dark aged oak, muted copper, charcoal, dusty ivory, low saturation. Fine AAA realistic hand-painted game assets, consistent material values matching dark medieval ashlar walls. Top row left to right: 1 low broad carved limestone altar table with simple sun relief, plain flat rectangular top, two small ivory candles at the back, no tall backing; 2 broad dark oak bookcase with three shelves of aged muted brown books, rectangular flat-backed silhouette, no elaborate spire; 3 rectangular recessed prison grille, matte iron bars, thick simple grey stone surround, dark empty interior; Bottom row: 4 low wide limestone sarcophagus with a worn flat lid, subtle carved crosses and rounded short stone feet, no effigy and no elaborate backing; 5 dark oak alchemy bench, sparse aged copper alembic and three small dark jade flasks, flat back, no bright glow; 6 low broken limestone bench and a compact cluster of its broken stone pieces immediately at the foot. The feet of all furniture sit on the same projected ground plane, no floor tiles or ground rectangles. NO scenery, no rooms, no halos, no bright gold, no symbols outside objects, no text, no grid lines, no labels. Genuine transparent background. Precise rectangular silhouettes, quiet restrained architecture designed to be seated against an actual game wall.
```

### interactables.png

```text
Production sprite atlas for a gothic action RPG. EXACT 2 columns by 2 rows, four distinct assets with huge transparent gutters, each object within central 70 percent of cell. Square image. Elevated FRONTAL orthographic camera looking down 35 degrees, all front edges horizontal, no isometric rotation. Same soft upper-left diffuse illumination, no hard external shadows. Top left: closed medieval storage chest of dark weathered oak, broad rectangular body, flat slightly curved lid, matte black iron bands, small aged brass lock, no gold ornament. Top right: THE EXACT SAME chest in the same orientation and scale, with its lid hinged open toward the back, dark empty interior, same base width and feet. Bottom left: a single humble dark terracotta storage urn, wide body, short neck, a worn grey cloth tied around its neck, restrained ash brown clay, no bright copper shine. Bottom right: a sturdy compact medieval iron standing brazier, simple round bowl on short tripod with a small warm amber flame, not a tall column. Fine hand-painted realistic AAA game prop art, muted dark charcoal-brown palette, reads clearly at 50-80 pixels tall, coherent with grey medieval masonry. All objects complete, no cropped feet. NO floor, no tile, no rectangle behind sprites, no glow clouds, no loot piles, no text, no labels, no cell lines. Alpha transparent background.
```

### architecture.png

```text
Production 2D gothic dungeon architectural sprite atlas, EXACT 2 columns x 2 rows, square image, four complete isolated objects with large transparent gutters and no overlap. Consistent orthographic elevated FRONTAL camera looking down 35 degrees, front edges horizontal, NEVER isometric or tilted. Grey ash limestone with modest bevels, matte dark iron, restrained realistic hand-painted game style. Top left: a narrow sturdy rectangular square-section wall pilaster, simple bevelled stone base and capital, three large ashlar blocks in shaft, no ornate carvings, top visible slightly, 3:1 height to width, square rather than round column. Top right: a pointed gothic recessed window surrounded by a restrained ash-grey stone frame, dark desaturated blue glass and a few thin black iron mullions, no glow, no light beam outside. Bottom left: a shallow rectangular stone wall shrine with small hooded stone statue, simple recessed frame, quiet worn carving, 2:1 height to width. Bottom right: a narrow worn dark burgundy banner with very simple faded grey sun emblem hanging from dark iron rod, straight symmetrical flat hanging cloth, no perspective rotation. Uniform soft upper-left ambient light. Stone objects match plain ashlar block walls, no shiny gold, no surrounding wall segment, no ground plane or floor, no external cast shadows, no halos, no labels or grid lines, no text. Genuine transparent alpha outside each isolated object, no backdrop.
```

### inlay-floor.png

```text
Production game floor texture: one SQUARE gothic abbey stone inlay panel, strict orthographic TOP DOWN, flat uniform ambient light, full bleed opaque square. A precisely constructed 4 by 4 flagstone module that can replace sixteen limestone paving tiles. Wide outer border of plain warm ash-grey limestone, edge joints spaced at quarters to align with neighboring floor grid. Inside this border a quiet intricate geometric opus sectile compass rose, eight-point interlocking star formed from grey limestone and muted dark blue slate pieces, concentric square and diamond geometry, thin worn antique bronze seams only as subtle accent. Desaturated stone colors, NOT shiny, NOT glowing. Moderate wear, faint mineral grain, tiny chipped joints, clean legible balanced composition, hand-painted realistic AAA dungeon material. Lower contrast than a UI icon; architectural ornament physically cut into the SAME flat floor. Absolutely no raised platform, pedestal, cast shadow, perspective, bevelled outer floating tile, words, letters, glowing runes, debris, grass, objects, or background. At all four image edges plain limestone continues as a tiled floor, no black outline.
```

### stairs.png

```text
Single production game sprite for a gothic dungeon stair exit, transparent background, square canvas, object isolated with generous transparent margin. An understated grey ash-limestone stairway of five broad shallow worn steps rising to a dark narrow pointed arched doorway, only two simple block piers and a modest stone arch. Elevated frontal orthographic view looking down 35 degrees; stairs and front edges exactly HORIZONTAL, symmetrical, no isometric rotation. The bottom step forms a broad flat contact edge, no floating slab, no floor tile or ground plane around it. Restrained realistic hand-painted game art, same regular dressed stone masonry as a medieval abbey, charcoal shadow inside doorway, low saturation, gentle uniform upper-left diffuse illumination. NO gold trim, no torches, no candles, no flames, no smoke, no glow, no ornate roof, no skulls, no excessive cathedral ornament. Compact clearly readable grounded architectural silhouette at 125px height. Every part fits within central 80 percent of the image, true transparent alpha everywhere outside the stairs and doorway.
```
