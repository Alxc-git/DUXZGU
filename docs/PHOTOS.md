# Organisation des photos

Les images publiees par le site sont rangees dans `montres_images/catalogue`.
Chaque variante possede exactement le meme contrat :

```text
montres_images/catalogue/<couleur>/
  packshot.webp
  lifestyle.webp
  details/
    01-angle.webp
    02-profil.webp
    03-fond.webp
    04-bracelet.webp
```

Les noms de certains details varient quand la serie disponible montre plutot la
face ou la boucle. Le prefixe numerique fixe leur ordre dans la galerie.

## Remplacement manuel

La methode la plus simple est la page Admin > Produits > Modifier :

1. Trouver la ligne de la bonne couleur.
2. Choisir le packshot principal, la photo lifestyle ou les photos de detail.
3. Pour les details, selectionner les quatre fichiers en une seule fois et dans
   l'ordre souhaite.
4. Enregistrer le produit puis verifier la couleur sur la page produit.

Pour remplacer les fichiers sources du depot, garder les noms ci-dessus puis
executer `bin/rails db:seed`. Les seeds synchronisent Active Storage avec les
fichiers du catalogue sans melanger les variantes.

## Dossiers

- `montres_images/catalogue`: fichiers utilises par le site et les seeds.
- `montres_images/sources/cj`: six images originales du fournisseur, renommees
  par couleur.
- `montres_images/sources/editorial`: originaux haute resolution des sections.
- `montres_images/sources/variants`: prises alternatives conservees pour de
  futurs remplacements.
- `docs/reference`: maquettes de design, jamais affichees comme photos produit.

Ne pas remettre de photos produit dans un dossier commun `separer`: une photo
de detail appartient toujours a une variante precise.
