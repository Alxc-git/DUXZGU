# Avant de lancer DUWZGU en production

Audit du code local, mis à jour le 5 septembre 2026. La finition visuelle ne valide pas les
paiements ni les services de production. Aucun courriel réel, paiement réel ou
déploiement n'a été effectué pendant cette intervention.

## 1. Bloquants avant toute commande réelle

- [ ] **Conserver le rabais du panier jusqu'au paiement.**
  `app/services/orders/place_from_cart.rb` ne transmet actuellement que la remise
  de quantité, pas `cart.code_discount_cents`. Répartir la remise entre les lignes,
  conserver le code appliqué et vérifier que panier, commande, Stripe, PayPal et
  courriel affichent exactement le même total, au cent près.
- [ ] **Conserver la livraison gratuite.** Le même service utilise
  `store.shipping_cents` au lieu de `cart.shipping_cents`. Tester les montants
  juste avant/après le seuil de livraison gratuite, y compris après un code promo.
- [ ] **Appliquer les limites des codes promo.** `times_used` n'est pas incrémenté.
  Réserver/consommer l'utilisation de façon atomique; gérer les paiements abandonnés,
  les webhooks répétés et les paiements simultanés. Pour l'offre de bienvenue,
  vérifier la première commande et empêcher la réutilisation du même avantage.
- [ ] **Corriger le détail des montants PayPal.**
  `app/services/payments/paypal/create_order.rb` envoie le sous-total avant remise
  et le total après remise sans ligne de réduction correspondante. Le détail
  doit se réconcilier avec le montant payable. Tester panier simple et multiligne.
- [ ] **Terminer l'offre « 10 % » pour les campagnes.** Le formulaire du pied de
  page stocke maintenant le courriel normalisé et unique par boutique, la langue,
  la source et le consentement horodaté; un courriel de bienvenue est mis en file.
  Restent à réaliser : lien public de désabonnement (le champ existe, sans parcours
  public), export des seuls abonnés autorisés, protection anti-abus au-delà de la
  session et preuve de livraison SMTP. Le code de bienvenue est partagé; rendre
  effective la condition « première commande », ses limites, son cumul et sa durée.
  Contrôler également la fenêtre de sortie, encore distincte du formulaire branché.
  Ne pas inscrire automatiquement les clients du checkout aux campagnes.
- [x] **Retirer les preuves sociales fictives.** Avis de démonstration, scores,
  chiffres clients et `aggregateRating` ont été retirés des pages publiques.
  N'ajouter des avis et chiffres qu'avec une source vérifiable.

## 2. Paiement, courriels et livraison

- [ ] Renseigner les clés LIVE Stripe et le secret de signature de
  `https://<domaine>/webhooks/stripe`. Tester succès, refus, 3-D Secure et webhook
  rejoué. Vérifier que seul un paiement confirmé lance la préparation.
- [ ] Si PayPal est affiché, configurer et tester ses identifiants LIVE et son
  parcours de capture; sinon masquer ce moyen de paiement.
- [ ] Définir `APP_HOST` avec le domaine réel et configurer la boîte support,
  l'expéditeur effectif, `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`.
  Vérifier SPF/DKIM/DMARC chez le prestataire et le domaine de l'expéditeur.
- [ ] Vérifier un **worker Solid Queue actif en production**, sa persistance et
  ses tâches échouées. La configuration locale SMTP ne prouve pas la livraison.
- [ ] Recevoir réellement, dans une boîte de test autorisée, la confirmation
  d'achat et le suivi en français et en anglais; vérifier référence, articles,
  rabais, livraison, total, adresse et lien de suivi.
- [ ] Renforcer la fiabilité des notifications : les drapeaux `confirmation_sent`
  et `shipped_email_sent` sont posés après mise en file, avant livraison effective.
  Prévoir reprise des échecs et déduplication atomique lors des appels concurrents.
  Vérifier aussi la branche Stripe `checkout.session.completed`, qui ne passe pas
  par le même envoi de confirmation que `payment_intent.succeeded`.
- [ ] Vérifier tous les identifiants de variantes, tarifs, stock, entrepôts,
  pays servis et délais chez le fournisseur. Tester une commande jusqu'au suivi,
  puis un remboursement complet et partiel d'un panier multiligne.
  **Constat du 5 septembre :** l'API CJ répond, mais les variantes locales de
  Creatine Jelly n'ont pas de VID. La saveur est conservée dans le panier et les
  métadonnées de commande, mais n'est pas reliée au VID de chaque saveur chez CJ.
  Le paiement CJ est manuel. Voir [les identifiants vérifiés et le détail du suivi](CJ_EXPEDITION.md).
- [ ] Valider taxes, devises, frais et conditions de retour pour les pays vendus.

## 3. Contenu, confidentialité et confiance

- [ ] Compléter l'identité du vendeur, l'adresse professionnelle, les coordonnées
  support et le responsable de la confidentialité dans les pages publiques.
- [x] Masquer les liens sociaux sans profil HTTPS configuré. Renseigner les vrais
  profils dans les réglages de la boutique pour les afficher.
- [ ] Vérifier avec les documents produit les ingrédients, doses, portions,
  précautions, promesses et étiquettes des images. Faire valider les allégations
  et la commercialisation pour les marchés visés.
- [ ] Publier des politiques cohérentes avec la livraison et les retours réels;
  utiliser une vraie date de mise à jour, pas la date courante à chaque visite.
- [ ] Aligner la politique de confidentialité avec la configuration réellement
  activée : elle indique actuellement qu'aucun pixel publicitaire n'est actif,
  alors que le code Meta existe. Tester refus/acceptation/retrait du consentement.
- [ ] Définir conservation, suppression et accès aux adresses marketing. Pour les
  campagnes au Canada, vérifier les exigences de consentement, identification et
  désabonnement du [CRTC](https://crtc.gc.ca/eng/com500/faq500.htm).

## 4. Infrastructure et recette finale

- [ ] Domaine, HTTPS, secrets de production et comptes administrateurs sécurisés;
  aucune clé dans Git ou dans le code navigateur. Vérifier les restrictions d'hôte.
- [ ] PostgreSQL et stockage des images téléversées sur volumes persistants;
  sauvegardes automatiques et **restauration testée** sur un environnement séparé.
- [ ] Exécuter migrations et compilation des assets; vérifier le démarrage web,
  le worker, `/up`, les erreurs applicatives et une procédure de retour arrière.
- [ ] Lancer `bin/rails test`, `bin/rails zeitwerk:check`,
  `node --test test/javascript/*.cjs`,
  `bin/brakeman --no-pager` et `bin/bundler-audit check --update`.
  Corriger les problèmes pertinents avant le lancement.
- [ ] Tester FR/EN, les trois saveurs, menu mobile, panier, checkout, FAQ,
  contact, clavier, zoom et réduction des animations. Vérifier aucun asset 404.
- [ ] Remplacer le domaine fictif de `public/robots.txt`, vérifier sitemap,
  canonical, aperçus sociaux et indexation de production. Garder la préproduction
  hors des résultats de recherche.
- [ ] Mesurer sur le domaine déployé avec réseau mobile : chargement du visuel
  principal, stabilité de mise en page et réactivité. Les fichiers allégés localement
  ne garantissent pas un score de performance en production.
- [ ] Effectuer une recette finale autorisée de bout en bout, puis surveiller
  erreurs, paiements, files de tâches et rebonds courriel pendant le lancement.

## Finition effectuée dans cette intervention

Grilles et boutons alignés; cartes de saveurs homogènes; étapes numérotées;
visuels responsives avec dimensions et chargement différé; nettoyage d'images
inutilisées; animations avec nettoyage lors des navigations Turbo et respect
des préférences de mouvement. Voir [le bilan des images](NETTOYAGE_IMAGES.md).

Validation locale du 5 septembre : 395 tests Rails / 1 681 assertions et 12 tests
JavaScript passent; autoload Zeitwerk et compilation Sass vérifiés. Accueil et
fiche produit contrôlés dans le navigateur, notamment sur téléphone et tablette;
ajout de framboise au panier après sélection vérifié, puis article de test retiré.
Voir [le bilan des six améliorations et les nouveaux visuels](REFONTE_PREMIUM.md).

Les blocages fonctionnels ci-dessus restent à corriger. Cette liste constitue
une recette à effectuer, pas une attestation de préparation à la production.
