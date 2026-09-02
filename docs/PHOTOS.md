# Organisation des photos

Les images catalogue versionnees avec le site doivent etre rangees dans
`catalogue_images/catalogue`. Chaque option peut suivre ce contrat :

```text
catalogue_images/catalogue/<option>/
  packshot.webp
  lifestyle.webp
  details/
    01-angle.webp
    02-detail.webp
    03-profil.webp
    04-packaging.webp
```

Le packshot sert aux selecteurs, au panier et aux miniatures. La photo lifestyle
sert aux zones de presentation. Les photos de detail completent la galerie.

## Remplacement manuel

La methode la plus simple reste la page Admin > Produits > Modifier :

1. Trouver la ligne de la bonne option.
2. Choisir le packshot principal, la photo lifestyle ou les photos de detail.
3. Pour les details, selectionner les fichiers en une seule fois et dans l'ordre souhaite.
4. Enregistrer le produit puis verifier l'option sur la page produit.

Les images ajoutees depuis l'admin passent par Active Storage. Les images dans
`catalogue_images/catalogue` servent de fallback deployable quand elles sont
versionnees dans le depot.

## Dossiers

- `catalogue_images/catalogue`: fichiers utilises par le site et les seeds.
- `docs/reference`: maquettes de design, jamais affichees comme photos produit.

Ne pas remettre de photos produit dans un dossier commun non structure : une
photo de detail appartient toujours a une option precise.
