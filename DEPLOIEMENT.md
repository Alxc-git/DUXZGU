# Mise en ligne sur Railway

Marche a suivre, dans l'ordre. Chaque etape suppose la precedente faite.

## 1. Creer le projet et la base

1. railway.app -> **New Project** -> **Deploy from GitHub repo** -> ce depot.
2. Dans le projet : **+ New** -> **Database** -> **Add PostgreSQL**.

Railway detecte le `Dockerfile` et l'utilise. Il n'y a rien a configurer pour la
construction.

## 2. Variables d'environnement

Service web -> onglet **Variables**. `DATABASE_URL` est deja injectee par le
service Postgres ; il reste :

| Variable | Valeur |
|---|---|
| `RAILS_MASTER_KEY` | le contenu de `config/master.key` |
| `APP_HOST` | le domaine final, ex. `luxtime.ca` |
| `SOLID_QUEUE_IN_PUMA` | `true` |
| `RAILS_MAX_THREADS` | `5` |
| `STRIPE_SECRET_KEY` | clé Stripe **live** le jour du lancement |
| `STRIPE_PUBLISHABLE_KEY` | idem |
| `STRIPE_WEBHOOK_SECRET` | fourni a l'etape 5 |
| `PAYPAL_CLIENT_ID` | depuis `.env` |
| `PAYPAL_CLIENT_SECRET` | depuis `.env` |
| `PAYPAL_ENV` | `sandbox`, puis `live` |
| `GROQ_API_KEY` | depuis `.env` |
| `CJ_API_KEY` | depuis `.env` |
| `ADMIN_EMAIL` / `ADMIN_PASSWORD` | pour creer le compte admin au premier `db:seed` |

Pour recopier `RAILS_MASTER_KEY` sans l'afficher a l'ecran :

    cat config/master.key | xclip -selection clipboard   # ou pbcopy sur Mac

## 3. Volume pour les images

Les fichiers ecrits par le conteneur disparaissent a chaque redeploiement. Les
photos ajoutees depuis l'admin sont dans ce cas.

Service web -> **Settings** -> **Volumes** -> **Add Volume**, point de montage :

    /rails/storage

C'est exactement ou pointe deja le service Active Storage `local`, donc il n'y a
aucun changement de code a faire.

> Si le conteneur ne parvient pas a ecrire dans le volume (droits root sur le
> point de montage), la solution est de passer Active Storage sur un stockage
> S3 compatible — Cloudflare R2 par exemple. Me le dire, c'est une quinzaine de
> lignes dans `config/storage.yml`.

## 4. Premier deploiement

Railway construit et demarre. `bin/docker-entrypoint` lance `db:prepare` tout
seul : les migrations passent au demarrage, y compris celles de Solid Queue,
Solid Cache et Solid Cable, qui vivent maintenant dans la meme base.

Ensuite, une seule fois, pour creer la boutique et le produit :

    railway run bin/rails db:seed

`db:seed` lit `APP_HOST` et enregistre le domaine de la boutique. Verifier :

    railway run bin/rails runner 'puts Store.pluck(:name, :domain).inspect'

## 5. Domaine et webhooks

1. Service web -> **Settings** -> **Networking** -> **Custom Domain**, ajouter le
   domaine et creer l'enregistrement CNAME chez le registraire. Railway emet le
   certificat TLS automatiquement.
2. Mettre `APP_HOST` a jour avec ce domaine, puis relancer `db:seed`.
3. Stripe -> Developpeurs -> Webhooks -> ajouter
   `https://VOTRE-DOMAINE/webhooks/stripe`, evenements `payment_intent.succeeded`
   et `payment_intent.payment_failed`. Copier le `whsec_...` dans
   `STRIPE_WEBHOOK_SECRET`.
4. PayPal : une fois le domaine en ligne, creer le webhook et remplir
   `PAYPAL_WEBHOOK_ID`.

## 6. Verifications apres mise en ligne

    curl -I https://VOTRE-DOMAINE/up          # 200
    curl -I http://VOTRE-DOMAINE/             # 301 vers https

Puis, dans un navigateur : la boutique s'affiche, `/admin` demande une connexion,
et un paiement test passe de bout en bout.
