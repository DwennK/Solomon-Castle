# Compétences — audit et corrections du 7 octobre 2026

## Verdict

La version inspectée possédait les quatre primaires, les sept secondaires et les six fusions, mais ne reproduisait pas toutes les mécaniques des compétences de Solomon’s Keep. Les quatre sous-compétences majeures, Créativité et Résistance au poison manquaient. Méditation, Concentration mentale et Télékinésie étaient des passifs progressifs différents des pouvoirs accordés par les objets. Les fusions réappliquaient l’équipement courant au lieu de conserver les rangs équipés lors de leur apprentissage.

La version corrigée propose **35 compétences hors fusions** : quatre primaires, douze sous-compétences, sept secondaires et douze passifs généraux. La Résistance physique de l’ancienne adaptation reste lisible et active sur les sauvegardes existantes, mais n’est plus proposée : le catalogue contient donc 36 définitions hors fusions, dont cette entrée historique.

Il s’agit d’une adaptation fonctionnelle, pas d’une reproduction numérique exacte. Les dégâts de base, points de vie, coûts de base, délais et dimensions du jeu existant sont conservés sauf mention ci-dessous. Les valeurs non établies par les sources sont signalées comme choix locaux.

## Référence et arbitrages

Page demandée : [Skills](https://solomons-keep.fandom.com/wiki/Skills). Les catégories [Primary Skills](https://solomons-keep.fandom.com/wiki/Primary_Skills), [Sub Skills](https://solomons-keep.fandom.com/wiki/Sub_Skills), [Secondary Skills](https://solomons-keep.fandom.com/wiki/Secondary_Skills), [Other Skills](https://solomons-keep.fandom.com/wiki/Other_Skills) et [Welded Skills](https://solomons-keep.fandom.com/wiki/Welded_Skills) établissent les familles et règles. Certaines pages Fandom refusent la lecture directe ; leur contenu indexé a été consulté. Ce n’est pas une vérification du jeu original en exécution.

Le wiki se contredit sur le niveau des sous-compétences majeures : 30 dans la catégorie, 25 dans certaines fiches. Le seuil **30** est retenu, corroboré par les tables historiques [SK v1.72](https://github.com/JayMcArthur/Raptisoft-Solomon/tree/master/Solomon%27s%20Keep/SK_v1.72_Merged/assets/data). Ces tables communautaires servent aux prérequis/plafonds, pas à transcrire tout l’équilibrage. Aucun code ou média du jeu original n’est intégré.

Sources de comportements complémentaires : [Harden](https://w.atwiki.jp/solomonskeep/pages/52.html), [guide des compétences](https://homhom.nekonikoban.org/skill.html), [Ether Charge](https://solomons-keep.fandom.com/wiki/Ether_Charge), [Immolation](https://solomons-keep.fandom.com/wiki/Immolation), [Explode](https://solomons-keep.fandom.com/wiki/Explode), [Chaining](https://solomons-keep.fandom.com/wiki/Chaining), [Potent Missiles](https://solomons-keep.fandom.com/wiki/Potent_Missiles).

## Correspondance et corrections

| Famille | Compétences | Comportement vérifié/corrigé |
|---|---|---|
| Primaires | Magic Missile → Projectile astral ; Fireball → Boule de feu ; Lightning → Éclair ; Frost Jet → Jet de glace | Deux projectiles et deux jets continus ; plafonds appris 12 avant niveau 25 puis 20 ; bonus équipés jusqu’à 25. |
| Astral | More Missiles → Projectiles multiples ; Potent Missiles → Projectiles véloces | Salves, vitesse issue de la table du wiki ; seul Potent autorise une nouvelle cible après perte de la première ; aucun bonus de vitesse aux boules de feu. |
| Feu | Explode → Explosion ; Embers → Braises | Explosion progresse en rayon et puissance ; Braises requiert Explosion. Les braises ne réémettent jamais d’autres braises et n’explosent pas simplement grâce à un bonus d’équipement. |
| Éclair | Chaining → Chaîne électrique ; Stun → Étourdissement | Rebond sans toucher deux fois le même ennemi. L’Orbe électrique et le Blizzard héritent maintenant de Chaîne ; les pulsations de l’orbe héritent d’Étourdissement. |
| Glace | Cone of Ice → Cône de glace ; Chill Wind → Vent glacial | Portée/largeur, recul et ralentissement ; déviation des tirs hostiles dans le jet. Le Missile de givre hérite du rayon et du ralentissement. Ralentissement borné pour éviter une vitesse négative. |
| Majeures | Immolation ; Ether Charge → Charge d’éther ; Hurricane → Ouragan ; Harden → Armure de glace | Niveau 30 et élément + deux sous-compétences requis ; effets détaillés ci-dessous. Jamais transmis aux fusions. |
| Secondaires | Teleport, Magic Shield, Magic Circle, Flash Freeze, Ring of Fire, Acid Rain, Turn Undead | Sept rituels ; deux emplacements, puis trois au niveau 20, équipement inclus. Les améliorations augmentent le mana sauf Téléportation/Bouclier ; recharge indépendante du rang. Bouclier : plafond appris 4 avant niveau 25, puis 6. Les morts-vivants apeurés interrompent aussi leurs attaques. |
| Mana/vie | Battle Mage, Channel Mana, Life Up, Mana Up | Effets existants conservés ; Mage de bataille réservé aux sorts offensifs, dont les rituels offensifs. Les autres coûts peuvent recevoir les anciens affixes génériques de réduction. |
| Autres | Rush, Resist Poison, Siege Mage, Faster Caster | Résistance au poison distincte de la résistance physique et combinée multiplicativement aux objets ; Mage de siège et Incantation rapide accessibles au niveau 25. Cadence +10 %/rang, sans effet sur les jets continus. |
| Rang unique | Mental Focus, Meditation, Telekinesis, Creativity | Recharge des rituels ÷2 ; mana régénéré ×4 après une seconde sans agir ; ramassage à 260 unités ; quatre choix au niveau suivant. Les pouvoirs appris et équipés ne se cumulent pas. |
| Fusions | Fire Missile, Flame Lash, Steam Jet, Ball Lightning, Frost Missile, Blizzard Beam | Les six couples existants sont conservés. Instantané des rangs effectifs primaires/sous-compétences, équipement inclus, au moment de la fusion ; les passifs généraux et bonus numériques restent dynamiques. Les éléments fournis par un objet permettent une fusion. Réapprendre renouvelle l’instantané. Les jets de feu déclenchent Explosion/Braises à la mort de leur cible. |

Chaque sous-compétence normale ajoute maintenant du mana uniquement à son élément et ses fusions. Les coûts supplémentaires restent adaptés : +1/rang pour Potent, +2/rang pour chacune des autres normales. Immolation ajoute +10 mana/rang/tir ; Ouragan et Armure de glace +6 mana/rang/seconde.

## Majeures : effets et conventions locales

- **Immolation** : une braise explose après 0,6 seconde, rayon 65 unités. Son explosion inflige les dégâts de la braise multipliés par `1 + 0,2 × rang`. Une collision avant expiration annule cette explosion. Le délai, le rayon et cette formule sont locaux ; la fiche wiki ne donne pas le délai.
- **Charge d’éther** : une charge par seconde sans tirer avec Projectile astral actif ; le prochain tir payé libère une onde de 320 unités. Chaque charge retranche 10 % de la vie maximale initiale, jusqu’au nombre de charges permis par le rang (cinq appris, huit avec équipement). On conserve le plus fort affaiblissement reçu : des impulsions répétées ne le multiplient pas. La réduction persiste avec l’ennemi lors des retours de portail. Le déclenchement, le rayon et la règle de non-cumul sont des conventions locales ; le wiki ne les précise pas.
- **Ouragan** : pendant Éclair, zone de 520 unités, dégâts continus, ralentissement et poussée tangentielle ; les projectiles hostiles tournent. La zone traverse les obstacles. La table historique de dégâts est utilisée comme DPS local : l’unité exacte des pulsations originales n’est pas établie. Le rayon et la déviation sont locaux.
- **Armure de glace** : pendant un Jet de glace effectivement payé, construction progressive d’une armure, selon la table historique (rang 1 : 8/s, maximum 25 ; rang 5 : 30/s, maximum 125). Absorbe aussi le poison, avec débordement éventuel vers bouclier/vie. L’arrêt du jet, le manque de mana ou le changement de sort la supprime. Le bouclier magique permanent reste indépendant.

Les temporisations/visuels des effets sont originaux. Le comportement historique exact d’Étourdissement, l’éventuel sort faible lorsque le mana manque, les probabilités d’offres de fusion et toutes les tables de dégâts/coûts originales ne sont pas reproduits. Le jeu conserve son interruption courte, son refus de lancer sans mana, son offre de fusion garantie lorsqu’elle est éligible et ses valeurs locales. Cela évite de présenter les zones non documentées comme une parité vérifiée.

## Sauvegardes et interface

Aucune sauvegarde joueur n’est réécrite par les tests. Les fichiers QA ont leur propre nom. Les rangs appris et les anciens objets sont conservés. Les anciens rangs multiples des quatre pouvoirs binaires restent stockés mais donnent désormais un seul effet ; le grimoire l’indique. Les anciennes valeurs numériques apprises au-delà des nouveaux plafonds restent effectives pour les passifs progressifs.

Les anciennes fusions ne contenaient pas les bonus de l’équipement de l’époque : ces bonus sont irrécupérables. Leurs rangs stockés deviennent fixes ; une nouvelle fusion capture tous les rangs équipés courants. L’instantané et les nouveaux effets sont sauvegardés sans modifier le format de campagne.

Les fiches françaises montrent coûts, effets conditionnels, explosions par projectile et prévisualisations actualisées. Les quatre choix de Créativité utilisent deux colonnes, avec défilement. Vérification native en 1440×900 et 960×600 ; aucune interface mobile n’est ciblée par ce jeu natif PC/Mac.

## Vérification reproductible

```sh
./tools/godot.sh --headless --path . --editor --import --quit
./tools/godot.sh --headless --path . tests/skills_test.tscn -- --test
./tools/godot.sh --path . --resolution 1440x900 tests/skills_test.tscn -- --test
./tools/godot.sh --headless --path . tests/equipment_test.tscn -- --test
./tools/godot.sh --headless --path . tests/tests.tscn -- --test
./tools/godot.sh --path . --resolution 1440x900 tests/ux_features.tscn -- --test
./tools/godot.sh --headless --path . -- --qa --qa-playthrough
```

Résultats : **101 contrôles ciblés** sans affichage, **103 avec rendu natif et clic réel**, **299 contrôles d’équipement**, **93 contrôles UX**, et **94 791 vérifications générales sur 1 300 étages générés**, sans échec. Le parcours QA a terminé les treize étages (47 choix de niveau) sans erreur. Le catalogue régénéré a également été comparé sans différence.

Rapports, journaux et captures dans `outputs/skills-audit/`. Les tests ciblés utilisent de vrais ennemis, projectiles, collisions/impacts, canalisations et entrées souris. Ils couvrent aussi les coûts et effets à 30/60/144 Hz, sauvegardes et bonus équipés. Le parcours complet utilise explicitement l’assistance QA ; il ne valide pas l’équilibrage d’une partie humaine sans aide.

Modifications locales uniquement. Aucun commit, push, nouvel export Windows/macOS ou déploiement réalisé pour cette correction ; les archives déjà présentes ne sont pas mises à jour.
