# Nettoyage et chargement des images

72 images non utilisées retirées de `app/assets/images/product` : 89.67 Mo.
97 formats WebP responsives générés : 6.58 Mo ajoutés.
Gain net dans les fichiers image du projet : 83.10 Mo.

Les références des vues, modèles (dont `Flavor`), helpers, scripts et seeds ont été examinées.
Les fichiers retirés étaient tous suivis par Git et sont récupérables dans l'historique.
Les originaux WebP utilisés sont conservés. Les dossiers `storage`, `DUWZGU`,
`montres_images` et les sources externes au dossier des assets sont conservés.
Les SVG sont conservés, car les icônes sont appelées dynamiquement.

Le poids retiré réduit l'archive de déploiement; il ne constitue pas à lui seul
un gain de chargement navigateur. Les gains de navigation viennent des `srcset`,
des miniatures dimensionnées, du chargement différé hors premier écran et de
la priorité élevée donnée au visuel principal. Aucun score Lighthouse de production n'est revendiqué.

Les formats sont décrits dans `config/storefront_images.json` et régénérables avec
`bin/rails runner script/build_storefront_images.rb` (libvips requis).

## Fichiers retirés

- `creatine-powder-tub.png`
- `creatine-powder-tub1.png`
- `creatine-powder-tub1.webp`
- `duwzgu-athlete.png`
- `duwzgu-card-blueberry-v2.png`
- `duwzgu-card-blueberry-v2.webp`
- `duwzgu-card-blueberry.png`
- `duwzgu-card-grape-v2.png`
- `duwzgu-card-grape-v2.webp`
- `duwzgu-card-raspberry-v2.png`
- `duwzgu-card-raspberry-v2.webp`
- `duwzgu-card-raspberry.png`
- `duwzgu-card-strawberry.png`
- `duwzgu-checkout-blueberry.png`
- `duwzgu-checkout-raspberry.png`
- `duwzgu-checkout-strawberry.png`
- `duwzgu-cta-mobile-blueberry.png`
- `duwzgu-cta-mobile-raspberry.png`
- `duwzgu-cta-mobile-strawberry.png`
- `duwzgu-feature-1.png`
- `duwzgu-feature-1.webp`
- `duwzgu-hero-alt.png`
- `duwzgu-hero-alt.webp`
- `duwzgu-hero-blueberry.png`
- `duwzgu-hero-mobile-blueberry.png`
- `duwzgu-hero-mobile-raspberry.png`
- `duwzgu-hero-mobile-strawberry.png`
- `duwzgu-hero-raspberry.png`
- `duwzgu-hero-strawberry.png`
- `duwzgu-index-strawberry-v2.png`
- `duwzgu-index-strawberry-v2.webp`
- `duwzgu-jar-2.png`
- `duwzgu-jar-2.webp`
- `duwzgu-jar-3.png`
- `duwzgu-jar-3.webp`
- `duwzgu-jar-raspberry.png`
- `duwzgu-jar-raspberry.webp`
- `duwzgu-lineup-centered.png`
- `duwzgu-lineup.png`
- `duwzgu-lineup.webp`
- `duwzgu-packshot-blueberry.png`
- `duwzgu-packshot-raspberry.png`
- `duwzgu-packshot-raspberry1.png`
- `duwzgu-packshot-raspberry1.webp`
- `duwzgu-packshot-strawberry.png`
- `duwzgu-packshot-strawberry1.png`
- `duwzgu-packshot-strawberry1.webp`
- `duwzgu-pdp-blueberry.png`
- `duwzgu-pdp-strawberry.png`
- `duwzgu-powder-card.png`
- `duwzgu-powder-card.webp`
- `duwzgu-raspberry-close.png`
- `duwzgu-versus-raspberry.png`
- `experiments/duwzgu-concept-blueberry-gym.png`
- `experiments/duwzgu-concept-blueberry-gym.webp`
- `experiments/duwzgu-concept-raspberry-lab.png`
- `experiments/duwzgu-concept-raspberry-lab.webp`
- `experiments/duwzgu-concept-strawberry-frozen.png`
- `experiments/duwzgu-concept-strawberry-frozen.webp`
- `experiments/duwzgu-concept-trio-gym-draft.png`
- `experiments/duwzgu-concept-trio-gym-draft.webp`
- `experiments/duwzgu-concept-trio-neon-rings-draft.png`
- `experiments/duwzgu-concept-trio-neon-rings-draft.webp`
- `experiments/duwzgu-concept-trio-neon-runway-draft.png`
- `experiments/duwzgu-concept-trio-neon-runway-draft.webp`
- `image.png`
- `jar-blueberry.png`
- `jar-blueberry.webp`
- `jar-raspberry.png`
- `jar-raspberry.webp`
- `jar-strawberry.png`
- `jar-strawberry.webp`
