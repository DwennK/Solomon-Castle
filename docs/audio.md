# Bande-son — La Tour des Cendres

78 ressources originales rendues hors ligne, sans échantillon externe ni dépendance réseau pendant le jeu. Le générateur déterministe est `tools/make_audio.py` ; `assets/audio/audio_manifest.json` donne leurs durées, formats et niveaux.

## Direction sonore

- Menu : thème en ré mineur, cordes synthétiques douces, notes pincées et cloches espacées (50,5 s).
- Village : variation plus lumineuse, mélodie de flûte synthétique et accompagnement pincé (43,6 s).
- Exploration : nappes graves, cloches éloignées et pulsations discrètes (60 s).
- Boss : ostinato, graves et percussions plus présents (34,3 s). Déclenchement à proximité d’un boss actif et accessible ; délai de cinq secondes avant le retour à l’exploration.

Les quatre morceaux sont en Ogg Vorbis stéréo, 44,1 kHz. Les fins de notes et la réverbération reviennent au début de chaque boucle. Les transitions utilisent deux lecteurs et un fondu de 1,8 seconde ; la pause atténue la musique.

Les 74 WAV mono PCM 16 bits / 44,1 kHz comprennent 41 événements, leurs variantes et cinq textures continues. Les missiles ont une impulsion arcanique, le feu un souffle grave, le gel des éclats cristallins, l’électricité des crépitements. Les fusions combinent ces matières. Chaque rituel possède son propre son. Les attaques de mêlée, flèches, sorts ennemis et morts sont séparées. Potions de soin et de mana, monnaie, équipement, bois de coffre et céramique des urnes sont différenciés. Pas sur pierre et gravier déclenchés selon la distance réellement parcourue, sans bruit quand le personnage pousse contre un mur.

## Mixage et comportement

24 voix spatialisées maximum, variantes alternées et petite variation de hauteur sur les sons répétitifs, limitation de cadence par événement. Les attaques lointaines sont ignorées. Blessures, bouclier et événements importants prennent la priorité sur les sons secondaires quand les voix sont occupées. Les notifications et menus sont centrés, indépendants de la position de la caméra.

Une voix dédiée joue le sort maintenu : aucun redémarrage toutes les 200 ms. Elle s’éteint au relâchement ou à court de mana, et s’arrête immédiatement lors d’une pause, d’un changement d’étage ou d’un retour au menu. Les événements de mort et victoire font disparaître la musique de combat. Limiteur final à −1 dB, commandes séparées pour musique et effets, et véritable coupure du bus principal à 0 %.

## Régénération et vérification

```sh
.tools-venv/bin/python -m pip install -r tools/audio-requirements.txt
.tools-venv/bin/python tools/make_audio.py
./tools/godot.sh --headless --path . --editor --import --quit
./tools/godot.sh --path . --resolution 1440x900 tests/audio_qa.tscn -- --qa
.tools-venv/bin/python tools/check_audio.py
```

Les tests audio utilisent les préférences/sauvegardes QA, jamais la campagne du joueur. Le test natif produit `outputs/audio-qa/result.json`, un enregistrement du vrai bus de mixage et une capture des options. Les vérifications numériques contrôlent les 78 fichiers, les limites de boucle, l’absence d’écrêtage et le signal enregistré. Elles ne remplacent pas l’appréciation musicale d’un auditeur.

Les anciens fichiers `ambience.wav` et `channel.wav` sont remplacés par les morceaux et textures dédiés. Les noms d’effets historiques encore utilisables restent dans le catalogue. Les bibliothèques Python servent uniquement à régénérer les assets ; elles ne sont pas incluses dans le jeu.
