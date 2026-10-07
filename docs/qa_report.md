# Rapport de validation — La Tour des Cendres 0.1.0

Date : 7 octobre 2026. Godot **4.7.2.stable.official.ed1daf0bf**, rendu Compatibility, macOS sur Apple M4. Aucun environnement Windows ni manette physique disponible.

## État livré

Le parcours nouvelle partie, village, treize étages, boss, victoire et difficulté suivante fonctionne dans les parcours vérifiés. Les illustrations ImageGen et sons originaux sont intégrés. La refonte de l’interface ajoutée en parallèle dans le dossier partagé a été conservée, inspectée et incluse dans les exports finaux. Aucun blocage connu dans ces parcours ; ce constat ne remplace pas une campagne humaine longue.

## Vérifications automatiques

- Import des scènes et ressources : réussi, sans erreur de script dans le journal final.
- Runner GDScript : **94,791 assertions**, zéro échec, **1 300 étages** (100 graines × 13), **60 combinaisons d’objets** observées.
- Connexion entrée/sortie, clé accessible avant porte fermée, porte réellement bloquante, ennemis/coffres accessibles, reproductibilité des graines et variation des étages.
- Quatre magies et six fusions : vrais impacts, dégâts et mana ; canalisations comparées à 30, 60 et 144 Hz. Sept secondaires, recharges, bonus et bornes statistiques.
- Équipement/retrait, achats et ventes sans duplication ; offres de niveaux multiples et prérequis ; sauvegarde, copie de secours et fichiers corrompus ; mort normale/hardcore, victoire et nouvelle difficulté.
- Entrées clavier et boutons manette injectés dans Godot ; cela ne constitue pas un essai matériel de manette.

L’archive source a ensuite été extraite dans un dossier propre : import réussi et runner complet de nouveau réussi, sans cache préalable.

Les résultats bruts sont conservés dans `docs/qa_evidence/`. Les scripts et commandes reproductibles sont dans le README.

## Parcours natifs

Le pilote de campagne parcourt les treize étages en utilisant AStar, le déplacement CharacterBody2D, les vrais sorts, dégâts, morts des boss, coffres, clés et portes. Dernière passe : 73,148 secondes, 47 choix de progression, treize jalons et zéro erreur. Il atteint l’écran de victoire, puis vérifie le passage à la difficulté suivante. Assistance explicite : rangs préaccordés, récupération de mana, invulnérabilité et simulation ×5. Les ennemis ne sont pas supprimés artificiellement pour franchir les étapes. **Ce n’est pas une campagne jouée entièrement sans assistance.**

Une session native supplémentaire de 16.5 secondes utilise les statistiques normales, la visée/navigation simulées et les potions ordinaires : sept ennemis tués, niveau 3 atteint, aucune mort. C’est un essai court de combat/exploration, pas une validation exhaustive de l’équilibrage.

Menus et interactions : nouvelle partie, choix initial au clavier, inventaire, marchand, grimoire, pause, options, niveau, mort normale/hardcore et victoire. Les tests de la nouvelle interface valident par clics réels les potions, changement de magie, navigation entre onglets, pause, raccourcis reconfigurés, jauges et recharges. Les captures ont été inspectées visuellement.

Fermeture/reprise : une sauvegarde QA distincte (graine 72931) avec un **Bâton d’os de la source équipé** a été enregistrée, puis chargée dans un processus séparé de l’exécutable macOS exporté. Inventaire et bonus conservés (régénération 13,3 mana/s, au lieu de 7,5 sans l’objet), y compris après fermeture et relance du dernier export. Une ancienne instance QA qui écrivait le même fichier a été fermée avant ce contrôle final ; ne pas ouvrir deux instances sur la même sauvegarde. Aucun fichier joueur n’est fourni dans les archives.

## Résolutions et performances

- Fenêtres natives **1440×900** et **960×600**, menus et jeu inspectés.
- Le système plafonne une demande de fenêtre 1920×1080 à **1728×1080**. Les premières captures portant cette demande dans leur nom ont cette taille réelle ; le rapport UI expose les dimensions mesurées.
- Vérification complémentaire **1920×1080 réels** avec un SubViewport GPU natif Godot : jeu et inventaire, sans agrandissement artificiel d’image. Ce contrôle vérifie la composition à cette taille ; ce n’est pas un essai de moniteur physique 1920×1080.
- Mesure finale avec le HUD refondu : **73 FPS médians**, 13.83 ms/image en moyenne, P95 **26.15 ms**, 725 images sur dix secondes. 1440×900, 80 ennemis, vrais chemins/collisions/projectiles/éclairs, physique 60 Hz, sans accélération. Mage QA immobile invulnérable ; ennemis à vie élevée pour maintenir la charge. Un export local a été lancé pendant cette passe. La médiane dépasse 60 FPS, mais des images dépassent 16,67 ms : **60 FPS constants ne sont pas garantis**.

## Exports et limites

- **macOS** : export universel arm64/x86-64 créé ; application exécutée sur Apple M4. Signature ad hoc locale vérifiée ; aucune identité de développeur et **aucune notarisation Apple**. Intel non exécuté.
- **Windows** : PE32+ x86-64 avec données embarquées, export créé ; **non exécuté sur Windows**, non signé. Compatibilité réelle à confirmer sur un PC Windows.
- Pas de manette physique testée. Seules les actions synthétiques et la configuration des commandes sont vérifiées.
- Animations de silhouettes peintes par transformations Godot, sans séquences directionnelles complètes. Audio synthétique original, boucle d’ambiance courte. Équilibrage des difficultés hautes à éprouver sur des parties humaines.
- Écarts volontaires à Keep documentés dans `reference_analysis.md` : variantes de règles de fusion, portail, génération et spécialisations tardives. Il s’agit d’une première version indépendante, pas d’une reproduction exacte de tous ses contenus.
- Aucun push, déploiement ou publication effectué par cette tâche. Un dépôt Git a été créé en parallèle durant le travail ; ses commits et changements ont été préservés.
