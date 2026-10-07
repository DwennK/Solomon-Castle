# HUD gothique — 7 octobre 2026

Le HUD utilisait `1 / get_final_transform().get_scale().x`, ce qui annulait l’agrandissement du canvas sur Retina. Le dock suit désormais l’échelle logique du jeu, avec adaptation aux petits viewports, et son bord inférieur coïncide avec celui du canvas. Les menus Inventaire, Grimoire, Village, Carte et Pause sont placés sous la minicarte, hors du dock.

Deux grandes orbes avec gargouilles encadrent le socle. Le sort principal a un emplacement plus grand, une double bordure bronze et un intitulé explicite. Les liquides ImageGen sont échantillonnés dans des régions mesurées de l’atlas ; le shader gère le remplissage réel, les faibles ondulations et l’arrêt du mouvement lorsque les effets réduits sont activés. Le mana reste bleu saphir sombre. Chiffres, raccourcis et états de recharge restent rendus par Godot.

## Ressources originales

Générées avec l’outil **ImageGen intégré**, en trois appels, avec `transparent_background: true`. Aucun CLI ni appel API externe. Les références fournies par l’utilisateur ont servi de direction artistique ; aucun pixel de ces captures n’est intégré au jeu. PNG copiés tels quels, alpha conservé ; régions, teintes et animation appliquées à l’exécution.

- `assets/ui/gothic-hud/orb-holder.png` — 1254 × 1254, RGBA.
- `assets/ui/gothic-hud/liquid-atlas.png` — 1774 × 887, RGBA.
- `assets/ui/gothic-hud/ability-rail.png` — 2172 × 724, RGBA.

### Prompt — orb-holder.png

Create a production-ready 2D game UI sprite on a transparent background, square 1024x1024. A single circular EMPTY orb holder for a dark gothic action RPG HUD: blackened iron, cold weathered steel and carved dark stone, thin concentric wrought-metal rims, subtle worn edges. The circular central opening must be truly transparent, centered at exactly image center and with diameter about 72% of image width. The outside ring occupies about 86% of image width. At the bottom left and bottom right, small crouching stone gargoyles cradle the circular frame, integrated into a low horizontal stone foot touching the bottom. Frame front-on, orthographic, perfect round opening with no perspective. Restrained realistic hand-painted AAA game UI material detail, muted cool charcoal metal, almost no gold. Clear silhouette and crisp edges at small display size. No liquid, no orb sphere, no text, no symbols, no labels, no background, no extra detached objects. This is an actual reusable game sprite, not a screenshot or mockup. Transparent alpha in the hole and everywhere outside the stone/metal holder.

### Prompt — liquid-atlas.png

Production game UI texture atlas, landscape 2:1 aspect ratio 1536x768, transparent background. EXACTLY TWO separate circular glossy magical liquid spheres, equal size, side by side, orthographic front view. Left sphere centered in the left half at 25% width 50% height, right sphere at 75% width 50% height. Each sphere diameter 42% of total width, substantial transparent gutter separating them and transparent outer margins. NO frames, rings, bases, stands, letters, interface, decorative objects or drop shadows outside circles. LEFT orb: deep blood-crimson liquid, beautiful intricate swirling cloudy clots and smoky filaments suspended inside, carmine highlights, dark burgundy edges, subtle glossy highlight upper right. RIGHT orb: deep sapphire and midnight cobalt BLUE mana, intricate luminous azure smoke currents suspended inside, dark navy edges, subtle cool steel-blue glossy highlight upper right. Blue must be rich and dark, not cyan, not pale blue, not purple. Both spheres feel like the moody textured life/mana globes of a high-end gothic action RPG, rich painted realism, fine detail readable in a 140px HUD. Filled entirely to the brim. Circular silhouettes perfectly round, same size and center height. No environment reflected, no starry sky, no sparkling particles around spheres. We will animate and dynamically clip these textures to the actual resource levels in game.

### Prompt — ability-rail.png

A standalone production 2D dark gothic action RPG HUD backplate sprite, wide landscape 3:1 aspect ratio, front-on orthographic. One long low rectangular slab of dark weathered charcoal stone with thin layered blackened iron bevels, silver worn edges, discreet engraved gothic tracery along the top edge and small iron rivets. Shape nearly rectangular, straight flat bottom designed to sit flush against screen bottom, subtle corner buttresses. Broad middle surface is very dark calm stone for overlaying ability icons in game. NO slots drawn, NO circles, NO globes, NO text, NO letters, NO symbols, NO icons, NO gold, NO UI mockup. The object fills 95 percent of canvas width and 85 percent of its height, with only a small transparent margin. Crisp hand-painted realistic material texture, low-contrast chipped stone grain, suitable behind readable game controls. Transparent background outside the slab. Matches a HUD with wrought black-iron orb rings held by stone gargoyles.

## Validation

```sh
./tools/godot.sh --headless --path . --editor --import --quit
./tools/godot.sh --path . tests/hud_v2.tscn -- --qa
./tools/godot.sh --path . tests/hud_scaling_qa.tscn -- --qa
```

- 392 contrôles d’interactions/layout réussis, aucun échec : potions, changement du principal, rituels, recharge, mana insuffisant, niveau 20, remappage clavier/manette, navigation, village et effets réduits.
- Captures natives à 960 × 600, 1440 × 900 et 1920 × 1080 ; inspection des états normaux et ressources faibles.
- Test distinct du **vrai canvas racine avec stretch**, indispensable pour reproduire le bug Retina : dock à 72,2 % de la largeur du canvas, collé au bas ; emplacement principal de 100 pixels à 1440 × 900, 198 pixels en fenêtre Retina agrandie et 204 pixels en plein écran.
- Rapports : `outputs/hud-gothic/scaling-report.json` et `outputs/hud-v2/report.json`. Capture Retina : `outputs/hud-gothic/retina-maximized.png`.
- Validation native macOS Apple M4 / Godot 4.7.2 Compatibility. Pas d’exécution Windows ni de test de manette physique.

## Archive livrée

`outputs/hud-gothic/La-Tour-des-Cendres-HUD-macOS.zip` a été exporté depuis `outputs/hud-gothic/build-snapshot/` : HEAD complété uniquement par les changements autorisés de décors, fenêtre et HUD. Une première archive capturait une édition parallèle inachevée de `main.gd` ; le test de démarrage l’a détectée, et l’archive a été remplacée. Les modifications parallèles d’inventaire et de combat sont exclues de cette livraison, sans modifier les fichiers de travail.

Les tests d’interactions et d’échelle ont été réexécutés sur cette copie isolée. Signature locale vérifiée avec `codesign --verify --deep --strict` ; démarrage headless du binaire exporté vérifié. Rapports définitifs : `snapshot-interactions.log`, `snapshot-scaling.log` et `verified-export-smoke.log` dans `outputs/hud-gothic/`.
