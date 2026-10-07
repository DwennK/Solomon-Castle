# Analyse de référence — 7 octobre 2026

Cible : Solomon’s Keep classique, pas Solomon’s Boneyard ni Solomon Dark. Le titre indépendant de cette réalisation est **La Tour des Cendres**. Code, illustrations, dialogues, personnages et équilibrage sont nouveaux.

## Sources consultées et limites

- [Raptisoft, site officiel](https://www.raptisoft.com/solomonskeep/) : présentation historique.
- [Steam, Dreadful Retro Edition](https://store.steampowered.com/app/3347090/Solomons_Keep_Dreadful_Retro_Edition/) : déplacement et visée indépendants, expérience, apprentissage, enseignants, achat et butin ; familles de morts-vivants et démons. La fiche présente 21 compétences et plus de 50 objets. Deux captures officielles (village et accès à la tour) ont été inspectées. La bande-annonce officielle a été consultée par extraction d’une image à 10 s ; pas de visionnage intégral ni d’inférence sur des timings à partir de cette seule image.
- [App Store, historique du développeur](https://apps.apple.com/fi/app/solomons-keep/id365183754) : les notes 2.0 annoncent 13 étages, les difficultés Wizard/Archmage, les fusions après le niveau 10, le troisième secondaire après le niveau 20. Des versions ultérieures ajoutent froid, Demigod et un adversaire avant le boss final. Le froid est devenu inclus, et l’historique documente plusieurs révisions des sauvegardes et du système d’achat.
- [Dépôt JayMcArthur](https://github.com/JayMcArthur/Raptisoft-Solomon) : arbre distant inspecté par l’API GitHub avant tout téléchargement. Seuls sept fichiers texte de `Solomon's Keep/SK_v1.72_Merged/assets/data/` ont été lus : fireball, magicmissile, lightning, coneofice, teleport, items et items_1. Aucun APK, exécutable, smali ou script du dépôt exécuté ou intégré. Aucune licence générale identifiée ; aucune ressource de ce dépôt n’est distribuée avec le jeu.
- [Documentation Godot stable](https://docs.godotengine.org/en/stable/) et [démos officielles](https://github.com/godotengine/godot-demo-projects) : documentation et organisation, sans copie de code de démo. Version effectivement installée : **4.7.2.stable.official.ed1daf0bf**, depuis la release officielle.
- [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds) et [catalogue](https://kenney.nl/assets) inspectés : licence CC0 annoncée. Finalement aucun son Kenney utilisé ; tout l’audio livré est une synthèse originale reproductible.

Les pages Fandom ont refusé l’ouverture directe ; leurs extraits indexés ont permis la lecture des règles ci-dessous. Leur fiabilité est communautaire, pas celle d’une spécification du développeur.

## Règles retenues

| Sujet | Confirmation et source | Mise en œuvre |
|---|---|---|
| Primaires | [Primary Skills](https://solomons-keep.fandom.com/wiki/Primary_Skills) : missile et feu par tir ; éclair et glace par seconde ; rang 12 avant niveau 25, puis 20 | Quatre comportements distincts ; coût et dégâts canalisés en delta temporel ; caps 12/20 |
| Sous-compétences | [Sub Skills](https://solomons-keep.fandom.com/wiki/Sub_Skills) : spécialisations conditionnées par l’élément | Salves, vitesse/poursuite, explosions, braises, chaînes, interruption, largeur du cône et recul |
| Secondaires | [Secondary Skills](https://solomons-keep.fandom.com/wiki/Secondary_Skills) : sept sorts, deux emplacements puis trois au niveau 20 | Sept rituels fonctionnels ; pas de remplacement arbitraire permettant d’apprendre les sept sur le même personnage |
| Cercle | [Magic Circle](https://solomons-keep.fandom.com/wiki/Magic_Circle) : régénération, ralentissement des ennemis et projectiles | Zone fixe de 18 s, rayon selon rang, régénération de vie/mana et ralentissement |
| Fusions | [Welded Skills](https://solomons-keep.fandom.com/wiki/Welded_Skills) : deux primaires, multiples de cinq, une fusion, capture des rangs au moment du choix | Une seule fusion remplaçable ; instantané des primaires et sous-compétences. Passifs généraux et bonus numériques d’équipement restent dynamiques |
| Boss | [Bosses](https://solomons-keep.fandom.com/wiki/Bosses), corroboré pour l’étage 4 par [guide de parcours](https://www.speedrun.com/solomonskeep/guides/z80dj) | Gardiens aux étages 4/8/11 ; gardien préalable et boss final au 13. Clé dans un coffre avant le dernier sceau. Dessins, noms et attaques originaux |
| Équipement | [Equipment](https://solomons-keep.fandom.com/wiki/Equipment), [témoignage du forum](https://www.raptisoft-forums.com/discussion/924/inventory-bug-save-corruption) | Un bâton et deux anneaux ; 6 bases × 10 affixes, trois raretés ; inventaire, comparaison, achat, vente |
| Mort et suite | [description communautaire des modes](https://dark.namu.moe/w/Solomon%27s%20Keep), historique App Store | Normal : retour au point de reprise, actions ultérieures annulées. Hardcore : partie marquée définitivement morte. Apprenti → Sorcier → Archimage → Demi-dieu → Épreuve éternelle, cette dernière en hardcore |

Les six couples sont feu/missile (missiles guidés explosifs), feu/éclair (arc brûlant en chaîne), feu/glace (large vapeur), missile/éclair (orbe pulsante), missile/glace (salves gelantes), éclair/glace (rayon pénétrant). Cette liste et la capture des rangs suivent le wiki Welded Skills ; les coefficients de notre réalisation sont originaux.

## Données douteuses et différences de version

`items.txt` et `items_1.txt` débutent par plusieurs répétitions d’objets à 100 or ayant notamment +1000 % d’or ou +350 % de récupération de mana. Ces entrées sont incompatibles avec les prix des objets suivants et semblent modifiées. Elles ne servent pas à équilibrer le jeu. Certaines tables primaires changent aussi de nom de champ en fin de progression (`MANAPLUS`/`MANACOST`) : aucune transcription automatique.

La version mobile a évolué ; la description Steam conserve une présentation générale qui ne suffit pas à établir chaque formule. Le wiki indique des fusions dès le niveau 5, tandis que les notes historiques du développeur parlent de niveau 10. Choix explicite : opportunité aux multiples de cinq dès le niveau 5 si deux éléments sont connus, pour rendre le système accessible dans la première campagne.

## Adaptations et écarts assumés de cette version

- Les valeurs de dégâts, coûts, prix, XP et statistiques sont originales ; aucune promesse de reproduction numérique exacte. Les captures figent les rangs mais aucun affixe ne donne de rang primaire supplémentaire dans cette version.
- Les compétences de haut niveau Mage de siège/Incantation rapide sont ouvertes plus tôt (niveau 5 au lieu du niveau historique 25). Les spécialisations majeures de niveau 30 (Immolation, Ether Charge, Hurricane, Harden) ne sont pas reproduites ; 30 compétences hors fusions couvrent le périmètre fonctionnel demandé.
- Portail permanent gratuit avec la touche T, sans achat préalable de clé magique. Téléportation secondaire vers la dernière position de salle sûre. Mort normale : instantané complet à l’entrée d’étage et à l’usage du portail ; sauvegarde de session périodique distincte de cet instantané.
- Six salles par étage au début puis neuf. Corridors connectés en parcours sinueux ; variation des dimensions, placements, ennemis et butins. Les salles ordinaires ne verrouillent pas leurs portes ; seuls les sceaux de gardien nécessitent une clé, ce qui évite les verrouillages liés à un ennemi égaré.
- Les corps des boss sont originaux (roi, abomination, démon, liche), pas des copies du dragon et des autres personnages historiques. Les comportements remplissent des rôles équivalents sans prétendre reproduire exactement leurs attaques.
- Les rarités modulent les affixes ; pas de coffre interpersonnages, classe supplémentaire, publicité, achat réel ou service réseau.
- Animation de silhouettes par déplacement, balancement, saut de marche et impulsion d’attaque dans Godot. Il ne s’agit pas d’animations directionnelles dessinées image par image.
- Interface française pour PC/Mac, raccourcis et navigation manette. Aucune compatibilité Windows ou manette physique n’est affirmée sans test sur ce matériel ; consulter le rapport QA.
