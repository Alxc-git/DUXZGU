# Expédition et suivi CJ — vérification du 5 septembre 2026

Vérification du code local et appels de lecture à l'API CJ avec la configuration
existante. Aucune commande CJ créée, aucun paiement ni courriel envoyé.

## Produit identifié

L'appel `GET /product/query?variantSku=CJYD231792503CX` identifie **Creatine Jelly**,
PID `2503070255581624500`, SPU `CJYD2317925`.

| Saveur, un pot | SKU CJ | Identifiant de variante (vid) |
| --- | --- | --- |
| Bleuet | CJYD231792503CX | 2503070255581624900 |
| Fraise | CJYD231792504DW | 2503070255581625100 |
| Framboise | CJYD231792502BY | 2503070255581624700 |

À **18:27 UTC le 5 septembre**, `GET /product/stock/queryBySku` pour le bleuet
renvoie Chine, `cjInventoryNum: 0`, `factoryInventoryNum: 8752`.
Le stock fabricant ne prouve ni un stock prêt à partir chez CJ, ni une date de
départ. Cette observation ponctuelle peut changer; elle ne doit pas être figée
dans une promesse publique.

## Ce qui fonctionne et ce qui reste à brancher

- L'authentification API fonctionne dans l'environnement local testé.
- `Suppliers::Cj::Client#tracking` interroge `getOrderDetail` avec
  `order.supplier_order_id`; il récupère statut, numéro et lien de suivi.
- `UpdateTrackingJob` est planifié toutes les six heures en production. La
  présence de cette configuration ne prouve pas qu'un worker tourne en production.
- Le job prévoit un courriel au premier numéro de suivi. La fiabilité de l'envoi
  et sa déduplication restent à valider (voir `AVANT_PRODUCTION.md`).
- Le produit local « Creatine Jelly » n'a pas de PID/VID enregistrés; ses variantes
  s'appellent encore « 300 g », « 500 g », « Pack 2 x 500 g ». Les saveurs visuelles
  du modèle `Flavor` ne choisissent pas automatiquement la variante achetable.
  Il faut relier chaque saveur au bon VID et contrôler le parcours jusqu'à la ligne
  de commande. Ne pas attribuer les trois VID aux variantes actuelles par position.
- La boutique est configurée avec paiement CJ manuel. Le paiement du client ne
  signifie donc pas que CJ a été payé ou a commencé l'expédition.

## Date affichée et comportement à viser

L'ancien « Expédié le 7 septembre » venait uniquement de `DispatchWindow` : heure
limite locale de 15 h, samedi/dimanche exclus. Il n'interrogeait ni CJ, ni le stock,
ni les jours fériés. Le bloc public affiche désormais **« Suivi par courriel dès
qu'il est disponible »** en français et son équivalent anglais; la page livraison
ne promet plus une préparation ou une expédition le jour ouvrable suivant.

Avant achat, afficher seulement une estimation fondée sur le stock, l'entrepôt,
le délai de préparation validé auprès de CJ et le transport vers le pays client.
`DeliveryEstimate` utilise déjà `freightCalculate`, mais ajoute deux jours de
préparation en dur et part de Chine : cette marge n'est pas une confirmation CJ.

Après achat, le numéro de commande CJ permet de suivre préparation puis départ.
L'API expose `subStatus`, `outWarehouseTime` (vide avant expédition), `trackNumber`,
`trackingProvider` et `trackingUrl`. Le site ne conserve pas encore l'heure réelle
`outWarehouseTime`; `shipped_at` prend actuellement l'heure de synchronisation.
Un numéro attribué seul ne doit pas être présenté comme une preuve de prise en
charge par le transporteur. Les événements du colis peuvent être consultés avec
`GET /logistic/trackInfo?trackNumber=...`.

## Sources officielles

- [Catalogue et stocks CJ](https://developers.cjdropshipping.com/en/api/api2/api/product.html)
- [Statuts, numéro de suivi et sortie d'entrepôt](https://developers.cjdropshipping.com/en/api/api2/api/shopping_new.html)
- [Estimation du transport et événements du suivi](https://developers.cjdropshipping.com/en/api/api2/api/logistic.html)
