Original prompt: Ameliore completement les graphismes, les effets visuels, les animations, fait une V2. Les personnages, les effets des sorts, TOUT. Go. Si tu as pas assez de truc visuel nhesite pas a generer avec image Gen.

## V2 — 7 octobre 2026

- Projet natif Godot 4.7.2, donc vérifications dans le moteur natif plutôt que Playwright.
- Travail réalisé sur le worktree déjà modifié, sans commit, reset ni suppression des modifications des autres tâches.
- 3 atlas ImageGen originaux, 48 sprites découpés avec alpha ; personnages, objets, éléments, six fusions, sept rituels et trois icônes supplémentaires.
- Nouveau shader de personnage : déformation du tissu, liseré, réaction au coup et dissolution. Mouvement amorti, incantation, lévitation des spectres, gel/brûlure.
- Effets de projectiles, canaux, impacts, zones, butin ; halos partagés, runes et éclats ; tremblement limité et option de réduction des effets respectée.
- Salles : relief des murs, ombres, fissures, débris, incrustations, poussières et lumière ; portails et brasiers animés ; braises dans le menu.
- La première vérification visuelle a permis de corriger une multiplication double des couleurs dans le shader. Les cristaux utilisent maintenant des primitives convexes afin d'éviter les erreurs de triangulation sur de très petits éclats éloignés de l'origine.
- Traînées regroupées en deux polylignes par projectile pour réduire le coût en combat dense.
- Validation et preuves : voir docs/visual-v2.md et outputs/visual-v2/.

Limite volontaire : animation procédurale de silhouettes peintes, sans planches directionnelles ni squelette articulé. Les géométries de collision et règles de combat sont conservées.
