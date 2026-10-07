# Architecture

Godot **4.7.2**, GDScript typé, rendu **Compatibility** (OpenGL, Metal via le pilote macOS). Aucune dépendance réseau à l’exécution. Le moteur et ses modèles d’export sont des outils externes au projet.

- `scenes/main.tscn` : point d’entrée F5/F6 ; contrôleur de menus dans `scripts/main.gd`, thème et HUD séparés. `scenes/world.tscn`, `player.tscn`, `enemy.tscn` sont réutilisables. Pour F6, démarrer la scène principale ; les sous-scènes de personnage demandent leur contexte de partie.
- `resources/` : 65 définitions `.tres` éditables (sorts, rituels, passifs, fusions, ennemis, objets, affixes, campagne). `ContentDefinition` donne leur schéma. `Catalog` et son index explicite permettent un chargement fiable après export.
- `State` : données persistantes, éligibilité des compétences, file des niveaux gagnés, économie et statistiques recalculées depuis les bases. Les identifiants stables, jamais les noms affichés, sont enregistrés.
- `SaveStore` : enveloppe JSON version 1 avec empreinte SHA-256 ; écriture temporaire, flush, copie de secours valide, renommage. Une copie endommagée ne remplace pas un secours sain. Pas de pickle, code chargé ou désérialisation exécutable.
- `Dungeon` : générateur déterministe, grille, murs regroupés par bandes, AStarGrid2D, ligne de vue, révélation de carte. Les plans et états sont stockés dans la partie : aucun nouveau tirage lors d’un retour.
- `GameWorld` : transitions village/tour, portes, coffre, clé, butin, rencontre, capture de l’étage. `MagePlayer` : entrée, déplacement, vitalité ; `TowerEnemy` : rôles ennemis, signaux d’attaque, navigation plafonnée en fréquence.
- `CombatSystem` : profils, delta des sorts continus, fusions, cibles, rituels. `MagicProjectile` : trajectoire, poursuite, détection par segment et impacts. Les positions de collision sont des positions au sol ; elles ne dépendent pas du cadrage du sprite.
- `ActorVisual`, `WorldProp`, `SpellEffects` : rendu et mouvements. Les images de personnage restent des sprites ; seules les collisions et effets emploient des primitives. Les effets sont plafonnés et les voix audio limitées à douze avec limitation de cadence.
- `tests/tests.tscn` : runner sans dépendance externe. `tests/playthrough.gd` : parcours accéléré des systèmes réels, réservé au moteur éditeur et à `--qa`. Les exports publics excluent les tests.

Les données de sauvegarde vivent dans `user://campaign.json` et `user://options.json`. `checkpoint` contient l’état de reprise après mort normale ; `run` contient l’état de session courant. Les parties de test utilisent des fichiers préfixés `qa_`. Les entrées de niveau en attente et leurs propositions sont sauvegardées pour empêcher le relancement d’un tirage.

Le script `tools/create_content.py` décrit les données initiales et peut les régénérer : il écrase volontairement les définitions générées. Pour un ajustement manuel dans l’inspecteur, ne pas relancer ce script sans reporter le changement dans sa source.
