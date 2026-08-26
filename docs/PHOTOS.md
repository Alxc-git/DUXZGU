# Organisation des photos

Les images publiees par le site sont rangees dans `montres_images/catalogue`.
Chaque variante possede exactement le meme contrat :

```text
montres_images/catalogue/<couleur>/
  packshot.webp
  lifestyle.webp
  details/
    01-angle.webp
    02-vue-eclatee.webp
    03-profil.webp
    04-fond.webp
```

Les cinq photos affichees dans la galerie suivent toujours cet ordre : face,
angle, vue eclatee, profil, puis fond. Le packshot est la premiere miniature et
les quatre fichiers de `details` completent la colonne.

## Remplacement manuel

La methode la plus simple est la page Admin > Produits > Modifier :

1. Trouver la ligne de la bonne couleur.
2. Choisir le packshot principal, la photo lifestyle ou les photos de detail.
3. Pour les details, selectionner les quatre fichiers en une seule fois et dans
   l'ordre souhaite.
4. Enregistrer le produit puis verifier la couleur sur la page produit.

Pour remplacer les fichiers sources du depot, garder les noms ci-dessus puis
executer `bash script/rebuild_display_images`, puis `bin/rails db:seed`. Le
premier script reconstruit les WebP dans le bon ordre; les seeds synchronisent
ensuite Active Storage sans melanger les variantes.

Le script harmonise deux choses que le fournisseur laisse varier d'une seance a
l'autre.

Le fond: chaque original repose sur son propre blanc casse, de 218 a 254, et
plusieurs sont vignettes par-dessus. La scene de la galerie etant en blanc pur
avec la photo en retrait, tout fond plus sombre dessine un carre gris a
l'interieur du cadre. Le point blanc est mesure dans les quatre coins, le plus
sombre l'emporte, puis il est remonte pour que tout le fond tombe sur 255. Les
coins sont la seule zone qu'aucune pose n'atteint, et c'est aussi la que le
vignettage est le plus marque.

L'echelle du packshot: elle est mesuree sur la largeur de la montre, boitier plus
couronne, et les six sont ramenes a 705px. Les quatre photos de detail gardent
leur cadrage d'origine, qui est propre a chaque pose et n'a donc pas d'echelle
commune a viser.

## Dossiers

- `montres_images/catalogue`: fichiers utilises par le site et les seeds.
- `montres_images/sources/cj`: six images originales du fournisseur, renommees
  par couleur.
- `montres_images/sources/editorial`: originaux haute resolution des sections.
- `montres_images/sources/display`: cinq PNG originaux par variante, ranges et
  renommes selon leur position dans la galerie.
- `montres_images/sources/variants`: prises alternatives conservees pour de
  futurs remplacements.
- `docs/reference`: maquettes de design, jamais affichees comme photos produit.

Ne pas remettre de photos produit dans un dossier commun `separer`: une photo
de detail appartient toujours a une variante precise.
