# Distribution du butin

Le but est de donner du poids aux découvertes, de limiter le tri d'inventaire et de permettre plusieurs constructions de personnage. Les chiffres sont une base mesurée, pas une preuve de rétention ou d'équilibre de tous les builds.

## Budget d'un étage neuf

- Étages 1–3 : 2 coffres et 3–4 vases. Étages 4–13 : 2 ou 3 coffres (50/50) et 3–6 vases.
- Aucun contenant dans la salle d'entrée ou l'arène du boss. Le coffre à clé est obligatoirement conservé avant le sceau.
- Un coffre garantit un équipement. Le deuxième donne une potion de vie et une de mana ; hors étage de boss, il a aussi 25 % de chance de contenir un équipement. L'éventuel troisième coffre donne uniquement de l'or.
- Chaque coffre contient 12–20 pièces + 2 × numéro d'étage, avant bonus d'équipement.
- Les vases ne donnent jamais d'équipement : 30 % quelques pièces (2–5 + étage / 3 arrondi), 5 % une potion, sinon rien. Au maximum une potion issue des vases par étage ; les tirages excédentaires sont vides.
- Deux ennemis ordinaires tirés au sort portent respectivement une potion de vie et une de mana. 35 % des ennemis ordinaires portent de l'or (8 + 2 × étage). Aucun ne donne d'équipement.
- Chaque boss d'étage donne un équipement rare ou épique et 35 + 5 × étage pièces. Le gardien intermédiaire du dernier étage donne de l'or, sans équipement supplémentaire.

Une exploration complète fournit donc quatre potions garanties (deux de chaque type), parfois une cinquième via un vase. Les vases ne sont pas nécessaires à ce minimum. En dehors des boss, on découvre un ou deux équipements par étage ; aux étages de boss, un dans les coffres et un sur le boss. Les piles d'or proches et sans mur entre elles sont regroupées.

## Progression de la qualité

| Étages, difficulté normale | Enchanté | Rare | Épique |
| --- | ---: | ---: | ---: |
| 1–3 | 90 % | 10 % | 0 % |
| 4–7 | 75 % | 23 % | 2 % |
| 8–10 | 60 % | 34 % | 6 % |
| 11–13 | 50 % | 40 % | 10 % |

Chaque difficulté supplémentaire déplace 5 points de probabilité vers Rare et 3 vers Épique. Les boss ont 20 % d'Épique avant l'étage 8, puis 35 %, avec 5 points supplémentaires par difficulté ; le reste est Rare. Le marchand utilise la courbe ordinaire lors du renouvellement de son stock. Le stock existant est conservé.

Les récompenses alternent bâton / anneau / anneau pour correspondre aux trois emplacements équipables. Les quatre dernières recettes obtenues sont écartées du tirage lorsque des alternatives de même emplacement et rareté existent. Cela évite les doublons immédiats sans garantir une amélioration à chaque découverte. Les achats ne consomment pas cette séquence. La séquence et l'historique sont sauvegardés pendant l'ascension et réinitialisés au lancement de la difficulté suivante.

Le tirage des ressources est fixé par graine, étage et difficulté. L'ordre des éliminations ne change pas les ressources. Le tirage d'équipement dépend également de la séquence/historique enregistrés ; recharger le même état et reproduire la même ouverture rend le même objet. Revenir dans un étage ne repeuple rien.

## Vases et sauvegardes

Les vases se cassent au contact d'un projectile allié, d'un rayon, d'un cône ou d'un effet de zone offensif. Ils ne proposent plus d'action d'interaction. Les murs protègent les vases, les attaques ennemies ne les récoltent pas, et chaque vase ne paie qu'une fois. Les sorts utilitaires sans dégâts ne cassent rien. Les coffres restent des objets à ouvrir par interaction.

Les étages des anciennes sauvegardes sont normalisés à leur chargement : les contenants inutilisés excédentaires disparaissent, les contenants déjà ouverts restent ouverts, la clé reste accessible et le butin déjà gagné est conservé. La limite de contenants visibles peut donc être dépassée par les anciens coffres déjà ouverts. Aucun inventaire ou stock de potions existant n'est amputé. Les objets laissés au sol survivent à un aller-retour au village.

## Validation et prochains réglages

Sur 100 campagnes complètes (1 300 étages, graines 0–99, difficulté normale), les budgets donnent 19,11 équipements en moyenne, boss compris, contre 108 dans les seuls coffres auparavant. Moyennes par campagne : 31,11 coffres, 56,01 vases, 27,27 potions de vie, 27,28 potions de mana et 6 417,36 pièces avant bonus et revente. Ces chiffres supposent tout explorer et vaincre ; les équipements achetés sont exclus.

Commandes reproductibles :

```sh
./tools/godot.sh --headless --path . res://tests/loot_test.tscn -- --test
./tools/godot.sh --path . res://tests/loot_test.tscn -- --test --visual
./tools/godot.sh --headless --path . res://tests/tests.tscn -- --test
./tools/godot.sh --headless --path . res://tests/skills_test.tscn -- --test
./tools/godot.sh --headless --path . res://tests/environment_qa.tscn -- --test
```

Le test dédié vérifie les budgets, les clés, la rareté normale/NG+, les doublons, les dix sorts principaux/fusions, les zones, les attaques ennemies, les murs, l'unicité des récompenses et la persistance. Le mode natif capture les vases intacts/cassés et l'ouverture d'un coffre à 1440 × 900.

Pour les prochains ajustements en parties humaines : mesurer les potions trouvées/consommées par famille de sorts, les décès par étage, les équipements réellement équipés, les retours pour vider le sac et l'or dépensé. Ajuster les réserves si un build est systématiquement à sec ; ajuster la qualité avant d'augmenter le nombre d'objets. Les bonus économiques déjà présents sur l'équipement restent inchangés et doivent être inclus dans cette mesure. La topologie des maps ne change pas dans cette passe.
