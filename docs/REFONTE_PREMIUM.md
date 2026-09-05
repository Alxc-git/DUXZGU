# Refonte premium DUWZGU — 5 septembre 2026

## Les six points réalisés

1. Accueil ouvert, typographie plus affirmée, grand pot et appel à l'achat principal.
2. Sélection instantanée des saveurs : image, ambiance, libellés, liens produit, zoom et formulaires d'achat synchronisés. Les liens restent fonctionnels sans JavaScript.
3. Sections plus variées : grille des saveurs, photographie en gros plan, portrait produit, routine et garanties ouvertes.
4. Deux nouveaux visuels éditoriaux intégrés, avec WebP responsives et chargement différé. Les trois scènes de fruits restent celles validées précédemment.
5. DUWZGU devient la marque principale; Creatine Jelly identifie la collection. Retrait des avis, scores et chiffres fictifs, y compris le score des données structurées. Le badge « Achat vérifié » exige maintenant une vérification explicite.
6. Effets roses réservés aux actions principales, chat plus discret, bordures et ombres atténuées. Barre de lecture en haut conservée, animations nettoyées lors des navigations et préférence de réduction du mouvement respectée.

La FAQ renvoie aux indications de l'étiquette : les sources fournisseur consultées n'étaient pas cohérentes sur la portion. L'étiquette et les allégations restent à valider avant vente. Le badge commercial « Le plus populaire » est remplacé par « Le duo ».

## Validation

- 395 tests Rails, 1 681 assertions, aucun échec.
- 12 tests JavaScript : sélection des saveurs, liens et quantités conservés, formulaires d'achat isolés des lignes existantes du panier, historique, nettoyage, réduction des animations, économie de données et progression de lecture.
- Compilation Sass, autoload Zeitwerk et vérification des différences Git réussis. Les avertissements existants sur les imports Sass restent présents.
- Vérification navigateur locale : accueil et fiche produit, FR/EN, menu mobile, trois saveurs, affichages de 320, 390, 768 et 1 280 pixels. Aucun débordement horizontal détecté dans les affichages inspectés.
- Ajout réel au panier local après changement vers framboise : bonne saveur affichée; article de test retiré ensuite. Aucun paiement ni courriel réel envoyé.

Les opérations de production sont détaillées dans [AVANT_PRODUCTION.md](AVANT_PRODUCTION.md). Les tests locaux ne valident pas l'envoi SMTP, les paiements LIVE ou une expédition CJ.

## Visuels générés

Mode : outil intégré ImageGen; pas de CLI ni d'appel API facturé depuis une clé locale.
Référence : pot DUWZGU fraise fourni par la fiche CJ, utilisé uniquement comme référence de forme et d'étiquette.
Ces images sont des illustrations de campagne générées, pas des photos de clients ou des preuves d'achat.

Fichiers intégrés au projet :
- `app/assets/images/product/duwzgu-editorial-hand-v1.webp` — portrait du pot tenu en main.
- `app/assets/images/product/duwzgu-editorial-detail-v1.webp` — gros plan du pot et des fraises.
- Déclinaisons 240, 480 et 800 pixels; également 1 200 pixels pour le gros plan.
- Tailles et sources responsives dans `config/storefront_images.json`, régénérables par `bin/rails runner script/build_storefront_images.rb`.

## Prompts finaux

### hand

Use case: product-mockup / photorealistic-natural. Create one premium editorial photograph, portrait 4:5. Reference image is the exact DUWZGU strawberry Creatine Monohydrate jar identity. Preserve its short wide cylindrical proportions, white container, red-to-white label, black ribbed lid, exact branding and label artwork. A natural adult hand and forearm in a simple charcoal training sleeve hold the jar from below, all the fingers anatomically correct, relaxed grip, jar frontal and legible, occupying about 60% of image width. Crop out the person's face and body. Deep soft charcoal seamless studio backdrop, restrained warm daylight from upper left, real skin pores and tactile package, very subtle red edge light. Premium sports editorial, calm, confident, no liquid explosions, no stone pedestal, no props, no extra wording, no invented badges, no watermark, no background graphics. Jar fully visible with breathing room top and bottom. Looks like a carefully art-directed product campaign rather than an advertisement template. Photo only, not a UI mockup.

### detail

Use case: product-mockup / precise-object-edit. Create one premium editorial still life photograph landscape 4:3. Reference image is the exact DUWZGU strawberry Creatine Monohydrate jar. Preserve its identity, short wide container shape, red-to-white strawberry label, black ribbed lid, lettering and white plastic. Intimate macro still life: the jar lying diagonally on a matte dark charcoal surface, label facing camera, with three ripe strawberries nearby, one cut strawberry showing juicy natural seed texture. Tight but intentional framing: jar dominates center, entire main brand and product wording visible; tactile black lid ridges, tiny natural moisture on the fruit, detailed print and soft shadows. Soft directional daylight, restrained red highlights, high-end minimal cosmetic-product photography adapted to sports nutrition. No gummy candy added because its exact shape isn't referenced. No stone pedestal, no floating splash, no neon, no hands, no new text, no graphics, no artificial sparkles or watermark. Photo only. Keep the overall composition dark and harmonious with a black and raspberry-accent website.

## Révision demandée : ancien hero et fonds noirs

L'ancien visuel panoramique du hero et son cadrage ont été restaurés. Sur mobile,
l'image dédiée revient au-dessus du texte. Le texte, les boutons et les pastilles
de la refonte sont conservés; la sélection actualise séparément la scène du hero
et les images de cartes.

Les deux photos éditoriales ont été modifiées avec l'outil ImageGen intégré,
en utilisant les versions v1 comme cibles d'édition. Les fonds gris sont remplacés
par du noir, et le fond de la section est #000000. Les sujets et la composition
sont conservés. Les versions v1 restent disponibles dans les fichiers du projet.

Fichiers finaux utilisés :
- `app/assets/images/product/duwzgu-editorial-detail-v2.webp`
- `app/assets/images/product/duwzgu-editorial-hand-v2.webp`

Les dérivés responsives et le manifeste ont été mis à jour. Vérification locale :
9 tests storefront / 83 assertions et 14 tests JavaScript passent; Sass et lint
des helpers passent. Hero contrôlé sur ordinateur et à 390 / 320 pixels;
trois saveurs contrôlées, dont changement de scène mobile sans rechargement.
Les deux images v2 chargent dans la section, sans erreur JavaScript observée.

Prompts exacts des modifications :

### Fond noir — detail

Use case: precise-object-edit. Edit the supplied product still life photograph. Change ONLY the gray backdrop and gray ground to seamless pure jet black (#000000) matching a black website. Keep the existing tilted DUWZGU jar, its exact dimensions, framing, angle, white plastic, black ribbed lid, red label and every printed word/artwork unchanged. Keep all strawberries and their shapes, position, texture, lighting and color unchanged. The black ground may retain extremely subtle contact shadows below the objects, but every outer edge and corner must fade into uniform pure black with no visible gray texture, brown haze, vignette rectangle or spotlight. Preserve the product highlights and exposure; do not darken the jar or fruit. Preserve the existing 4:3 composition. Photorealistic edit, no added text, objects, badges, splash or graphics.

### Fond noir — hand

Use case: precise-object-edit. Edit the supplied hand-held product photograph. Change ONLY the gray/brown textured backdrop to seamless uniform pure jet black (#000000) that blends perfectly into a black website. Every outer background edge and corner must be pure black; remove gray texture, brown haze and spotlight. Preserve the entire existing jar exactly: same scale, placement, white plastic, red-to-white label, lettering DUWZGU, CREAtINE MONOHYDRATE, all artwork and black ribbed lid. Preserve the natural hand, fingers, skin color, pose, sleeve, crop and lighting exactly. Keep the product and hand properly exposed with existing highlights, not darkened. Maintain the portrait 4:5 composition with current headroom. Photorealistic background-only edit, no additional text, objects, lights, logos, badges or watermark.
