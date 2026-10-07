# La Tour des Cendres

Première version jouable d’un action-RPG natif Godot pour ordinateur, inspiré des mécaniques de **Solomon’s Keep classique**. Projet indépendant, sans ressources ni code de Raptisoft.

## V2 graphique (0.2.0)

Les nouvelles versions jouables sont dans `outputs/v2/`. Personnages, objets et icônes recréés avec ImageGen, effets élémentaires distincts, animations procédurales, portails, brasiers et ambiance du donjon enrichis. Voir [les changements et preuves de validation](docs/visual-v2.md).

## Jouer

- **macOS** : décompresser `outputs/La-Tour-des-Cendres-macOS.zip`, puis ouvrir `La Tour des Cendres.app`. Universel Apple Silicon / Intel ; exécuté et vérifié ici sur Apple M4. Signature ad hoc locale, sans notarisation Apple.
- **Windows** : décompresser `outputs/La-Tour-des-Cendres-Windows.zip`, puis lancer `La-Tour-des-Cendres.exe`. Binaire Windows x86-64 généré ; **pas exécuté sur Windows** dans cette session, non signé.
- **Sources** : importer `project.godot` dans **Godot 4.7.2 stable**. F5 lance le jeu ; F6 fonctionne depuis `scenes/main.tscn`. Aucun serveur, plugin, compte ou service obligatoire.

Le moteur utilisé est `4.7.2.stable.official.ed1daf0bf`, en rendu Compatibility. Les illustrations sont réellement générées avec ImageGen et intégrées. L’audio est une synthèse originale déjà rendue en WAV et Ogg Vorbis ; il n’est pas nécessaire de lancer les outils pour jouer.

## Parcours

Nouvelle partie → village → apprentissage d’un élément auprès d’Orme ou à l’entrée de la tour → treize étages avec salles et couloirs → gardiens → sommet → victoire → difficulté suivante.

Le marchand vend des potions et six équipements propres à l’ascension ; il rachète les objets non équipés. Orme vend des leçons. Ysée restaure gratuitement vie et mana au village. Le portail garde votre étage et votre position. Coffres, clé, boss, ennemis blessés, butin non ramassé et carte restent persistants lors des retours.

Quatre primaires, six fusions, sept rituels secondaires et vingt-quatre passifs/spécialisations : **35 compétences hors fusions** (plus une Résistance physique historique conservée dans les anciennes sauvegardes). Les rituels occupent deux emplacements, puis trois au niveau 20. Les fusions sont proposées aux multiples de cinq lorsque deux éléments sont connus ; une seule est conservée, avec les rangs figés au moment de son apprentissage. Le grimoire permet de choisir la magie active.

Un bâton, deux anneaux et un sac de 48 objets. Le catalogue comporte **95 recettes d’équipement** issues du wiki (55 bâtons, 40 anneaux), en trois raretés, avec des valeurs tirées dans les plages indiquées. Les nouveaux coffres, boss et stocks marchands utilisent ce catalogue. Chaque anneau peut être comparé puis placé dans l’emplacement 1 ou 2.

Les objets peuvent améliorer les rangs de sorts et savoirs, toutes les compétences acquises, les dégâts fixes, la cadence, la récupération de vie/mana, l’or trouvé, l’XP et les résistances. Télékinésie étend le ramassage, Méditation quadruple le mana régénéré au repos et Concentration mentale divise par deux la recharge des rituels. Les bonus disparaissent au retrait pour les sorts ordinaires ; une fusion conserve les rangs primaires et sous-compétences équipés au moment de sa création. Les rangs appris ne sont jamais augmentés définitivement par les objets. Un sort explicitement fourni par un objet devient utilisable temporairement ; les rituels respectent les deux/trois emplacements disponibles, après les rituels appris.

Les anciens objets, stocks et sauvegardes restent compatibles, sans remplacement forcé. Les prix, formules de combat et plafonds restent ceux de cette adaptation ; voir les différences détaillées dans `docs/reference_analysis.md`.

Les gardiens occupent les étages 4, 8, 11 et 13 ; le dernier étage contient aussi un gardien préalable. Chercher la clé dans les coffres pour lever le sceau. Les difficultés sont Apprenti, Sorcier, Archimage, Demi-dieu, puis Épreuve éternelle (hardcore).

**Mort normale** : retour à l’instantané pris à l’entrée d’un étage ou lors d’un portail ; les actions plus récentes sont annulées. **Hardcore** : la partie morte ne peut plus être continuée. Les options sont séparées de la campagne.

## Commandes par défaut

| Action | Clavier / souris | Manette |
|---|---|---|
| Déplacer | WASD, ZQSD, flèches | Stick gauche |
| Viser et tirer | Souris + clic gauche maintenu ; Espace également | Stick droit incliné |
| Interagir | E | A |
| Changer de magie | Tab | B |
| Rituels 1 / 2 / 3 | 1 / 2 / 3 | LB / RB / X |
| Potion de vie / mana | R / F | Croix gauche / droite |
| Portail du village | T | Croix bas |
| Inventaire | I | Y |
| Grimoire | K | Retour / Select |
| Carte | M | Croix haut |
| Pause | Échap | Start |

Menus : souris ou flèches/Tab + Entrée ; manette avec croix/stick et A, B pour revenir. Les touches et boutons d’action sont reconfigurables dans les options. Les deux sticks ont une zone morte. La manette physique n’a pas été testée sur cette machine. Volume général, ambiance musicale, effets sonores, luminosité, plein écran et réduction des flashs sont disponibles.

## Sauvegardes

Godot utilise `user://` :

- macOS : `~/Library/Application Support/Godot/app_userdata/La Tour des Cendres/`
- Windows : `%APPDATA%\Godot\app_userdata\La Tour des Cendres\`

`campaign.json` est une enveloppe versionnée avec empreinte d’intégrité ; `.bak` est la copie de secours. Écriture temporaire puis renommage. Sauvegarde automatique toutes les 15 secondes, aux transitions et à la fermeture normale ; commande manuelle dans Pause. En cas de corruption, récupération du secours valide ou message permettant une nouvelle partie. Ne pas déplacer une sauvegarde pendant que le jeu tourne.

Les fichiers `qa_*.json` sont exclusivement des sauvegardes de développement. Une nouvelle partie joueur ne lit pas ces fichiers. Il n’y a aucune sauvegarde de joueur préinstallée dans la livraison.

## Vérifications reproductibles

Depuis la racine du projet, sur macOS/Linux :

```sh
./tools/godot.sh --headless --path . --editor --import --quit
./tools/godot.sh --headless --path . tests/tests.tscn -- --test
./tools/godot.sh --headless --path . tests/equipment_test.tscn -- --test
./tools/godot.sh --path . tests/equipment_ui.tscn -- --qa
./tools/godot.sh --headless --path . -- --qa --qa-playthrough
./tools/godot.sh --path . --resolution 1440x900 -- --qa --qa-playthrough
./tools/godot.sh --path . --resolution 1440x900 -- --qa --qa-visual
./tools/godot.sh --path . tests/ui_redesign.tscn -- --qa
./tools/godot.sh --path . tests/resolution_qa.tscn -- --qa
```

`GODOT_BIN` peut pointer vers un autre emplacement du binaire 4.7.2. Sur Windows, remplacer `./tools/godot.sh` par le chemin de `Godot_v4.7.2-stable_win64.exe` (ou sa variante console). Un test réussi sort avec code 0 et produit un rapport JSON dans `outputs/`.

Le runner couvre 100 graines × 13 étages, sorties et positions accessibles, magie réelle, invariance 30/60/144 Hz, objets, achats/ventes, sauvegarde, corruption, mort et nouvelle difficulté. Le parcours accéléré accorde explicitement des rangs, de la récupération et l’invulnérabilité, puis utilise les vrais déplacements, sorts, ennemis, coffres, portes et boss. Ce n’est pas une partie complète jouée sans aide.

QA rapide : `-- --qa --qa-floor 8` charge un étage avec une graine déterministe. Les scripts QA sont exclus des exports et leurs points d’entrée exigent le moteur éditeur. Ne pas exécuter simultanément deux parcours utilisant le même fichier QA.

Les captures natives sont dans `outputs/screenshots/`. Les résultats et limites sont détaillés dans [docs/qa_report.md](docs/qa_report.md).

## Exports et archive

Installer les modèles d’export officiels **4.7.2.stable** via Godot ou depuis la release officielle. Puis :

```sh
./tools/export.sh
python3 tools/package.py
```

Les presets sont dans `export_presets.cfg`. Le projet utilise aussi l’option d’import ETC2/ASTC exigée par Godot pour l’export macOS ARM/universel, tout en gardant Compatibility et des textures 2D ordinaires.

`tools/package.py` rassemble les notices, compresse Windows et crée l’archive source sans `.godot`, environnement Python, sorties, anciens fichiers de recherche ou exécutables de référence. Aucun push, aucune publication ni installation distante.

## Modifier le projet

- [Analyse des sources et écarts](docs/reference_analysis.md)
- [Audit et corrections des compétences](docs/skills_audit.md)
- [Architecture](docs/architecture.md)
- [Assets, provenance et licences](docs/asset_manifest.md)
- [Prompts ImageGen](docs/art_prompts.md)
- [Rapport QA](docs/qa_report.md)

Les définitions se modifient dans l’inspecteur (`resources/**/*.tres`). `tools/create_content.py` peut les régénérer mais écrase ces fichiers : reporter d’abord les changements manuels. Les libellés et descriptions sont regroupés dans les définitions et le catalogue source français `resources/localization/messages.csv`, régénérable avec `tools/extract_translations.py`. Le français est la seule langue fournie ; une traduction future doit également adapter les gabarits de phrases dynamiques.

Les animations sont des silhouettes peintes animées par Godot, sans planches directionnelles complètes. L’équilibrage est original et reste à affiner sur des parties humaines longues ; les différences précises avec Keep sont documentées, notamment les coefficients propres à cette adaptation et l’absence du coffre entre personnages. Les quatre spécialisations majeures, Créativité et les pouvoirs à rang unique sont détaillés dans [l’audit des compétences](docs/skills_audit.md).
