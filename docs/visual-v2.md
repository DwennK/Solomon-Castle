# V2 graphique — 0.2.0

Refonte locale du 7 octobre 2026. Direction : pierre froide, bronze, ivoire et cyan, avec une couleur et un mouvement propres à chaque famille de magie.

## Livrables

- Application universelle macOS : `outputs/v2/macos/La Tour des Cendres.app` ; archive `outputs/v2/La-Tour-des-Cendres-V2-macOS.zip`.
- Windows x86-64 : `outputs/v2/La-Tour-des-Cendres-V2-Windows.zip`.
- Les archives V1 restent présentes. Aucun commit, push ni déploiement réalisé pour cette refonte.

## Changements

- Trois planches ImageGen originales, découpées en 48 images avec transparence : 16 personnages (mage, huit ennemis, quatre boss, trois habitants), 16 objets et éléments, 13 fusions/rituels et trois icônes supplémentaires disponibles. Sources et fichiers de jeu dans `assets/art/v2/`, prompts exacts dans `docs/art_prompts_v2.md`.
- Personnages plus détaillés, respiration, marche amortie, inclinaison d’incantation, flottement des spectres, liseré lumineux, réactions aux coups, cristaux de gel, braises de brûlure et dissolution progressive à la mort. Les morts sortent immédiatement du combat et perdent leurs collisions ; seule la silhouette disparaît progressivement.
- Missiles à traînées, feu incandescent, lances de glace, orbes électriques ; foudre ramifiée, fouet ondulant, vapeur visible, blizzard spiralé. Impacts avec halos, éclats et ondes, zones rituelles et avertissements ennemis distincts, bouclier runique, butin lumineux.
- Runes et incrustations au sol, fissures, débris décoratifs, relief et ombres des murs, lumière d’ambiance, poussières, portails et brasiers animés. Braises sur le menu. Les textures de fond du village, du menu et des matériaux existants restent utilisées.
- Icônes distinctes pour les six fusions et sept rituels dans les emplacements. Version affichée 0.2. Les animations d’interface existantes sont conservées.
- Tremblement d’impact limité à 3 pixels ; il est désactivé en mode de réduction des effets. Ce mode réduit aussi les particules, halos et flashs.
- Les traînées sont regroupées en deux polylignes par projectile et les halos utilisent une seule texture partagée. Effets transitoires plafonnés à 160.

## Vérifications

Godot 4.7.2 stable, moteur Compatibility natif, Mac Apple M4.

| Vérification | Résultat |
|---|---|
| Tests de gameplay | 94 791 vérifications, 1 300 étages générés, zéro échec |
| Parcours accéléré | 13 étages terminés, 47 choix de niveaux, zéro erreur ; rangs/mana/invulnérabilité de QA, pas une partie humaine sans aide |
| Galerie V2 | 16 captures natives, dix primaires/fusions, zones, bouclier, 12 silhouettes ennemies, libération des visuels de mort |
| Interface | Potions, changement de sort, raccourcis, cooldowns, inventaire, menus et pause validés par interactions |
| Résolutions | 1440 × 900 et 960 × 600 en fenêtre ; véritable rendu 1920 × 1080 dans un SubViewport, la fenêtre macOS étant limitée à 1728 pixels de large sur cet écran |
| Combat normal automatisé | Sept ennemis vaincus en 16,5 s, aucune mort, statistiques normales, navigation/visée automatisées |
| Charge dense | 80 ennemis avec IA, collisions, projectiles et éclairs ; médiane 64 FPS, moyenne 15,47 ms/image, p95 18,95 ms, 1440 × 900, mesure sur dix secondes |
| Export macOS | Signature ad hoc vérifiée, version 0.2.0 ; application exportée lancée et sauvegarde QA chargée, rendu du donjon et des nouveaux assets observé via Computer Use |
| Export Windows | Compilation réussie ; non exécuté sur Windows |

Preuves : `outputs/visual-v2/tests-final.log`, `playthrough-final.log`, `native-final.log`, `performance.json`, `ui-report.json`, `resolution.log` et captures PNG. Le contrôle des journaux finaux de gameplay/rendu ne signale aucune erreur Godot. Le premier arrêt forcé de l’export via `--quit-after` laisse deux ressources de musique OGG en cours d’utilisation à la fermeture ; la fermeture normale du jeu passe par `Sound.stop_all()`. Cette observation audio n’est pas une correction de cette refonte.

Le benchmark à 64 FPS porte sur les éclairs et projectiles ; le dernier ajustement visuel de densité vapeur/blizzard ne change pas ce scénario. Ce n’est pas une garantie de performance sur d’autres machines.

## Reproduction

```sh
./tools/godot.sh --headless --path . --editor --import --quit
./tools/godot.sh --headless --path . tests/tests.tscn -- --test
./tools/godot.sh --headless --path . -- --qa --qa-playthrough
./tools/godot.sh --path . --resolution 1440x900 tests/visual_v2.tscn -- --qa
./tools/godot.sh --path . --resolution 1440x900 -- --qa --qa-visual
./tools/godot.sh --path . tests/ui_redesign.tscn -- --qa
./tools/godot.sh --path . tests/resolution_qa.tscn -- --qa
```

Exécuter le benchmark seul. Les scènes QA partagent des sauvegardes de test ; ne pas lancer simultanément deux scénarios qui utilisent `qa_campaign.json`. Aucune sauvegarde joueur n’a été utilisée pour ces contrôles.

## Limites

Les animations utilisent des silhouettes peintes et des déformations procédurales ; ce ne sont pas des planches de marche dans huit directions ni des personnages 3D articulés. L’export macOS est signé localement, sans notarisation Apple. L’exécution Windows reste à vérifier. Le dépôt contenait de nombreuses modifications d’autres tâches : elles ont été conservées et la V2 a été ajoutée par-dessus.
