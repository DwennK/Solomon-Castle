# Bande-son — La Tour des Cendres

## Ressources

338 fichiers locaux (41,8 Mio), issus de 20 collections gratuites sous CC0 / CC BY. Aucun son de Solomon’s Keep. Les 78 ressources synthétiques précédentes sont remplacées ; le jeu ne dépend d’aucun service audio distant.

| Contexte | Composition | Auteur | Durée adaptée |
|---|---|---|---|
| Menu | Dark chamber | Marcelo Fernandez | 226 s |
| Village | Town Theme RPG | cynicmusic | 96 s |
| Exploration | Dungeon Ambience | yd | 203 s |
| Exploration | Dark Tower Ambience | tcarisland | 129 s |
| Exploration | The Deeper Caverns | Tsorthan Grove | 193 s |
| Boss | Dark Descent | Matthew Pablo | 76 s |

Les pistes menu, village et boss sont recadrées et raccordées avec un fondu de boucle. Les trois compositions d’exploration alternent sans répétition immédiate, avec 9 à 17 secondes de transition vers le silence entre deux pistes ; les changements d’étage ne relancent pas le morceau. Leur lecture et le compte à rebours du silence se suspendent en pause. Les bruitages sont convertis à 44,1 kHz mono, débarrassés du silence de bord, équilibrés et fondus sur leurs extrémités. Certaines textures combinent plusieurs sources avec filtrage, variation de hauteur ou réverbération. Les musiques et ambiances sont en Ogg Vorbis, les effets courts en WAV PCM 16 bits.

Crédits complets : [Audio-Attribution.txt](licenses/Audio-Attribution.txt). Ils sont aussi accessibles dans le jeu et compilés dans les exports. Le manifeste `assets/audio/audio_manifest.json` donne chaque fichier source, durée, format, niveau et SHA-256. `sources.json` fixe les téléchargements et leurs empreintes. Les notices des auteurs priment sur les étiquettes de collection ; le cas Dark chamber (notice CC BY 4.0, étiquette 3.0) y est documenté.

## Identité sonore des sorts

104 fichiers de sorts sont dessinés spécifiquement, dont 70 nouveaux fichiers de variantes et de phases. Le départ des projectiles dure 0,28 à 0,50 seconde ; leurs attaques deviennent audibles en moins de 25 ms dans le fichier. Les tirs répétés ne superposent plus des mélodies ou des traînes de plusieurs secondes.

| Sort | Signature |
|---|---|
| Missile astral | Impulsion magique nette et souffle court |
| Boule de feu | Embrasement grave, souffle puis combustion à l’impact |
| Foudre | Décharge initiale, arcs électriques entretenus, dissipation brève |
| Jet de glace | Fractures cristallines, souffle froid et fragments |
| Missile de feu | Noyau arcanique et combustion, conservés à l’impact |
| Missile de givre | Noyau arcanique, fracture et éclats glacés à l’impact |
| Boule de foudre | Masse arcanique électrifiée ; impulsions uniquement lorsqu’elle touche une cible |
| Fouet de flammes | Feu et arcs électriques entrelacés |
| Vapeur | Véritables enregistrements de jets et sifflements de vapeur |
| Blizzard | Souffle glacé, cristaux et arcs électriques |
| Téléportation / bouclier / cercle | Aspiration puis départ ; résonance protectrice ; soin lumineux |
| Gel / anneau de feu / acide / peur des morts-vivants | Expansion de glace ; déflagration ; liquide et corrosion ; aspiration sombre |

Nouvelles sources : [Magic SFX Sample de ViRiX](https://opengameart.org/content/magic-sfx-sample), [Ice & Electricity Magic de qubodup](https://opengameart.org/content/ice-electricity-magic), [Ice spells](https://opengameart.org/content/ice-spells) et [Steam release sounds](https://opengameart.org/content/steam-release-sounds) de bart. Les deux premières sont sous CC BY 3.0, les deux autres sous CC0 ; crédits intégraux dans la notice et dans le jeu.

Chaque sort et chaque phase courte a trois variantes. Les canalisations ont une attaque unique, huit secondes de texture bouclée avec grains irréguliers et une extinction propre à l’élément. Maintenir le bouton ne relance pas l’attaque ; changer de sort, ouvrir un menu ou quitter le monde coupe les phases précédentes. Une échéance monotone évite de relancer artificiellement un sort à cause du delta d’une image lente. Les contacts d’orbe, l’impulsion d’éther et les impacts sur l’armure de glace disposent de sons dédiés.

Les nouveaux sorts n’ajoutent pas de réverbération de pièce à leurs fins déjà dessinées, pour préserver la lisibilité. Les canalisations restent sous leurs transitoires d’attaque. Six impacts simultanés maximum laissent de la place aux nouveaux tirs et aux alertes.

## Créatures et environnement

Sept familles : ossements, morts-vivants, bêtes, armures, spectres, diablotins, démons. Les douze types d’ennemis ont une famille explicite. Chaque famille possède trois variantes pour présence, détection, attaque, blessure, mort et déplacement. Les quatre boss ont chacun une révélation, un avertissement de 0,62 seconde maximum et une mort distincts : fer et chaînes du roi, matières humides de la peste, feu et rugissement du démon, magie spectrale de la liche. L’avertissement démarre au début du télégraphe de 0,85 seconde, avant la libération de l’attaque. Les morts n’utilisent plus le même effet générique pour tous les ennemis.

Les créatures proches peuvent s’entendre avant leur détection ; les murs atténuent leur présence de 10 dB et retirent les aigus par un filtre passe-bas à 1 300 Hz. Le masquage est évalué au déclenchement du son. Les ennemis dormants ou derrière un sceau restent silencieux. Les présences sont espacées de 5 à 11 secondes, avec un budget global et au plus quatre voix de créatures secondaires simultanées. Les pas suivent la distance réellement parcourue ; le gel suspend les sons de présence et de déplacement. Les dégâts continus ne déclenchent pas de plainte à chaque frame.

Le donjon possède un lit d’ambiance de caverne indépendant de la musique. La torche visible la plus proche crépite dans un rayon de 320 pixels. Six textures discrètes, reliées au décor réel des salles, se croisent en 2,5 secondes : gouttes de crypte, bois de bibliothèque, chaînes de prison, bulles de laboratoire, résonances de chapelle et gravats des ruines. Des événements localisés, espacés de 10 à 19 secondes, ponctuent les temps calmes ; les couloirs retrouvent le fond de caverne seul. Les cryptes et chapelles ont une réverbération plus longue. Un auditeur attaché au joueur garde la spatialisation cohérente avec sa position.

Le village possède un fond naturel d’oiseaux et d’air extérieur. Des activités espacées de 7 à 13 secondes sont émises à la position réelle des villageois proches : matériel du marchand, pages du professeur, eau du guérisseur.

Les impacts mêlent l’élément du sort à la matière de la cible (os, chair, métal, spectre ou pierre), avec trois variantes par matière. Projectiles, canalisations et explosions partagent un budget de matière de 180 ms pour éviter la cacophonie. Inventaire, grimoire, bâton, anneaux, retrait d’équipement, transactions, clé, sceau et butin rare/épique ont leurs propres effets. Les simulations de comparaison d’équipement restent silencieuses.

## Mixage et transitions

24 voix d’effets avec priorités ; dégâts du joueur et alertes prennent le pas sur les sons secondaires. Sélection aléatoire sans répétition immédiate et petite variation de hauteur. Les pas, le butin et les pages d’interface restent discrets. Musique en fondu de 1,8 seconde ; retour du boss après cinq secondes de désengagement. Ambiance réduite sous les boss. À partir de trois ennemis visibles proches, un accent de tension accompagne la rencontre, avec au moins 35 secondes entre deux accents. Le niveau musical suit progressivement la densité du combat. Les avertissements de boss et dégâts du joueur abaissent brièvement la musique de 4 dB et les effets secondaires de 6 dB, avec une attaque rapide et un retour progressif.

Les cinq sorts continus utilisent des textures échantillonnées à niveau modéré. Arrêt au relâchement, à l’épuisement du mana, à la pause et lors d’un changement de contexte. Les ambiances suivent le réglage Effects et se suspendent en pause. Changement d’étage et retour au menu arrêtent les sons du monde. Un limiteur final évite l’écrêtage ; le réglage principal à zéro coupe le bus.

## Reconstruction et validation

```sh
# Les sources brutes sont en cache local ignoré, avec vérification SHA-256.
.tools-venv/bin/python tools/import_free_audio.py --fetch
# Sans réseau quand les sources sont déjà présentes :
.tools-venv/bin/python tools/import_free_audio.py
./tools/godot.sh --headless --path . --editor --import --quit
./tools/godot.sh --path . --resolution 1440x900 tests/audio_qa.tscn -- --qa
.tools-venv/bin/python tools/check_audio.py
.tools-venv/bin/python tools/check_spell_audio.py
./tools/godot.sh --headless --path . tests/tests.tscn -- --test
```

`tools/make_audio.py` est un alias vers ce pipeline et ne régénère plus les anciens sons. L’encodeur Vorbis est alimenté par blocs pour éviter un plantage natif observé avec les longues pistes. Les dépendances Python restent celles de `tools/audio-requirements.txt` et ne sont pas embarquées dans le jeu.

La QA native utilise les sauvegardes de test et enregistre le vrai mélange Godot dans `outputs/audio-qa/gameplay-mix.wav`. Elle vérifie les textures de salle, le village, les silences et rotations de la musique, les matières, les alertes des quatre boss avant attaque, le filtrage des murs, les ouvertures réelles d’inventaire et de grimoire, ainsi que les déclenchements réels des ennemis, la portée, l’atténuation, les budgets de voix, les transitions, les canalisations, la pause, les volumes et l’accès aux crédits. Le contrôle des fichiers vérifie silence, saturation, coutures de boucles, formats, empreintes et provenance. Ces mesures ne remplacent pas l’appréciation musicale du joueur.

Pour reconstruire uniquement les sorts : `.tools-venv/bin/python tools/design_spell_audio.py`. L’import complet appelle la même fonction. L’extraction initiale de l’archive 7z de qubodup requiert `bsdtar` (libarchive, fourni sur macOS) ; aucun outil supplémentaire n’est nécessaire pour jouer ou exporter. `tools/render_spell_preview.py` produit une audition hors moteur avec un déroulé JSON, et une comparaison avec les anciens sons lorsque `outputs/spell-audio/before/` est présent.
