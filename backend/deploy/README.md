# Deploying the backend

Two supported paths. Both end with MySQL 8, PHP 8.3+, and the API served over
HTTPS — which is not optional, because the iOS app ships with no App Transport
Security exception for your domain.

> **This is a monorepo.** Laravel lives in `backend/`, not at the repository
> root. Every path below reflects that, and it is the single most common thing
> to get wrong.

## Laravel Forge

1. **DNS first.** Add an `A` record for `api.yourdomain.com` pointing at the
   server's IP. Propagation takes a few minutes and SSL will fail without it.

2. **Create the site** with these settings:

   | Field | Value |
   | --- | --- |
   | Root Domain | `api.yourdomain.com` |
   | Project Type | Laravel / PHP |
   | **Web Directory** | **`/backend/public`** |
   | PHP Version | 8.3 or newer |

   The web directory is the one that catches people. Forge defaults to
   `/public`, which does not exist here — every request would 404.

3. **Connect the repository**, and leave *Install Composer Dependencies*
   **unchecked**. Forge looks for `composer.json` at the repository root and
   there isn't one; the deploy script installs from `backend/` instead.

4. **Create a database and user** under the server's Database tab.

5. **Set the environment** (site → Environment). Start from
   `backend/.env.example`. At minimum set `APP_URL`, `APP_ENV=production`,
   `APP_DEBUG=false` and the four `DB_*` values.

6. **Replace the deploy script** with the contents of
   [`forge-deploy-script.sh`](forge-deploy-script.sh).

7. **Deploy.** The first run fails because `APP_KEY` is empty — expected. Then
   under site → Commands:

   ```
   cd backend && php artisan key:generate --force
   ```

   Deploy again; it should go green.

8. **Enable SSL** (site → SSL → Let's Encrypt).

9. **Create a real administrator.** See *Accounts* below.

## Plain VPS

```bash
# One-off setup
sudo apt install -y php8.3-{fpm,mysql,mbstring,xml,curl,zip,gd,intl} mysql-server nginx
sudo mysql -e "CREATE DATABASE lhg_property_hub CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
sudo mysql -e "CREATE USER 'lhg'@'localhost' IDENTIFIED BY 'CHANGE_ME';"
sudo mysql -e "GRANT ALL ON lhg_property_hub.* TO 'lhg'@'localhost'; FLUSH PRIVILEGES;"

git clone https://github.com/mirandadlp/LHG-app.git /var/www/property-hub
cd /var/www/property-hub/backend

cp .env.example .env          # fill in DB credentials and APP_URL
composer install --no-dev --optimize-autoloader
php artisan key:generate
php artisan migrate --force
php artisan storage:link

sudo cp deploy/nginx.conf /etc/nginx/sites-available/property-hub
sudo ln -sf /etc/nginx/sites-available/property-hub /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
sudo certbot --nginx -d api.yourdomain.com

# Subsequent deploys
./deploy/deploy.sh
```

Note the nginx `root` must end in `backend/public`.

## Accounts

The seeder is for demos. **Every account it creates has the password
`password`**, so it must not be the way you get your first login on a public
host.

Create a real administrator instead — the command prompts for the password
without echoing it and enforces a 12-character minimum:

```bash
php artisan hub:create-admin
```

If you *do* want the seven demo properties to click through, seed and then
immediately close the demo accounts:

```bash
php artisan db:seed --force
php artisan hub:disable-demo-accounts      # deactivates and revokes their tokens
php artisan hub:disable-demo-accounts --delete   # or removes them outright
```

Deactivating keeps the properties and their audit history intact; the accounts
simply stop being able to sign in, and any token they already hold is revoked.

## Permissions

The web user writes to exactly two directories:

```bash
sudo chown -R www-data:www-data storage bootstrap/cache
sudo chmod -R 775 storage bootstrap/cache
```

## Before you go live

- [ ] `APP_DEBUG=false` and `APP_ENV=production` — a stack trace on a debug
      build exposes your database credentials to anyone who triggers an error
- [ ] `APP_KEY` is set
- [ ] `php artisan hub:create-admin` has been run, and the seeded demo accounts
      are either absent or disabled
- [ ] HTTPS is working — check with `curl -i https://api.yourdomain.com/api/bootstrap`,
      which should answer `401`
- [ ] `CORS_ALLOWED_ORIGINS` lists only origins you control (it is irrelevant to
      the iOS app, which is not a browser)
- [ ] A database backup schedule exists
- [ ] `ios/Config/Release.xcconfig` → `API_BASE_URL` matches this host
