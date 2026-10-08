# Provenance des ressources

Toutes les ressources de jeu sont locales. Aucune image, table d’objets, voix, musique ou police provenant de Solomon’s Keep n’est distribuée.

## Illustrations réellement intégrées

Création avec l’outil **ImageGen intégré**, le 7 octobre 2026. Pas de CLI OpenAI, pas de clé API locale utilisée. Les planches transparentes possèdent un canal alpha mesuré de 0 à 255 ; elles ont été inspectées sur fond uni. Aucun damier peint.

| Source générée | Fichiers dérivés utilisés | Provenance |
|---|---|---|
| `assets/art/source/characters.png` | mage, skeleton, archer, zombie, ghoul, sorcerer, knight, imp, ghost, king, plague, demon, lich, merchant, teacher, healer | ImageGen `exec-72ed6ff5-0010-49a3-9445-e1d1d1e509aa` ; révision de la planche initiale pour supprimer les débordements |
| `assets/art/source/props.png` | chest, chest_open, torch, urn, portal, stairs, gold, health, mana, staff, ring, book, missile, fire, lightning, ice | ImageGen `exec-5bff7f7f-7898-419c-8552-9d786adc5bf8` |
| `assets/art/source/materials.png` | floor_stone, wall, floor_village, floor_crypt | ImageGen `exec-04b36a2d-9923-4183-b0d2-8118d5851e49` |
| `assets/art/menu.png` | Fond de menu | ImageGen `exec-1896eeed-50d9-4633-9437-bb0faf61f550` |
| `assets/art/village.png` | Cour du village | ImageGen `exec-fc2fc868-f498-4272-ba24-943a330a0f33` |

Les personnages sont découpés, recadrés selon leur alpha, réduits et placés dans un canevas 256×256 avec pivot commun. Les matériaux sont ramenés à 512×512. `tools/prepare_art.py` effectue uniquement ces opérations techniques autorisées. L’ancienne planche présentant des morceaux de personnages voisins a été remplacée, puis la planche de contact vérifiée. Les sources ImageGen sont les créations originales du projet ; elles ne sont pas présentées comme des ressources CC0 d’un tiers.

Les six prompts et la charte sont conservés dans `docs/art_prompts.md`. Le mouvement et les attaques complètent les silhouettes dans `ActorVisual`. Effets de sort, signaux de boss, ombres et vignette : code original Godot.

## Audio

`assets/audio/` contient 268 ressources dérivées de 16 collections gratuites : musiques composées, voix enregistrées, matières, effets et ambiances. Licences CC0, CC BY 3.0 et CC BY 4.0 ; aucun achat, compte ou service distant n’est nécessaire pendant le jeu.

Les crédits, sources, licences et adaptations figurent dans [Audio-Attribution.txt](licenses/Audio-Attribution.txt) et dans le jeu, **Credits → Audio credits**. Les crédits intégrés sont compilés dans chaque export. `assets/audio/sources.json` fixe les URL et SHA-256 des téléchargements ; `audio_manifest.json` relie chaque fichier livré à ses fichiers sources. Les musiques sont de Marcelo Fernandez, cynicmusic, yd, Matthew Pablo, tcarisland et Tsorthan Grove. Les effets et ambiances proviennent de Little Robot Sound Factory, rubberduck, ArcadeParty, TinyWorlds, PagDev, LEGIT Audio, IgnasD, Augmentality / Brandon Morris et Thimras.

Le générateur synthétique précédent a été remplacé par `tools/import_free_audio.py`. Les sources brutes restent dans le cache ignoré `outputs/audio-sources/`. Voir [audio.md](audio.md) pour les traitements, le mixage et la validation.

## Moteur et dépendances

- [Godot Engine 4.7.2](https://github.com/godotengine/godot/releases/tag/4.7.2-stable), licence MIT ; notice dans `docs/licenses/Godot-MIT.txt`. Notices des composants embarqués dans `docs/licenses/Godot-COPYRIGHT.txt`. Les polices Cinzel et Lato ont été ajoutées par la refonte de l’interface présente dans le dossier partagé ; leurs notices SIL Open Font License 1.1 sont dans `assets/fonts/Cinzel-OFL.txt` et `assets/fonts/Lato-OFL.txt`. Sources indiquées : [Cinzel](https://github.com/google/fonts/tree/main/ofl/cinzel) et [Lato](https://github.com/google/fonts/tree/main/ofl/lato). Aucune police personnelle n’est copiée.
- Python 3 est utilisé uniquement pour les outils. Pillow est utilisé pour le traitement technique des images ; pas de dépendance Python dans le jeu exporté. Aucun code Pillow n’est redistribué dans l’archive source.
- Les images Steam et l’image extraite de la bande-annonce sont des références de recherche, exclues du jeu et de l’archive source.

## Charte

Fantasy sombre légèrement malicieuse ; caméra de dessus inclinée, lumière chaude en haut à gauche, silhouettes peintes/précalculées, sans pixel art. Palette : bleu-noir `#101b26`, ardoise `#35434a`, or vieilli `#c6a66c`, cyan `#66c8d2`, braise orange. Personnage courant ≈ 83–96 pixels de hauteur à la taille logique 1440×900, boss 145 pixels. Cases du donjon : 64 pixels. Le texte reste intégralement du texte Godot.

## Interface intégrée à la livraison

La refonte présente dans le dossier partagé ajoute `assets/ui/orb-frame.png` autour des jauges animées par `vital_orb.gdshader`. Son manifeste `assets/ui/orb-frame.prompt.txt` indique ImageGen, le 7 octobre 2026, avec transparence réelle et conserve le prompt complet. Les ornements, cases de sorts et contrôles restent des éléments Godot interactifs. Les petits SVG de contrôles sont fournis dans `assets/ui/`. Cette refonte a été conservée et incluse dans les vérifications et exports finaux.
