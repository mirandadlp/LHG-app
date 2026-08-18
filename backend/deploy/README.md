# Deploying the backend

Two supported paths. Both end with a MySQL 8 database, PHP 8.3+, and the API
served over HTTPS.

## Laravel Forge

1. Create a site for `api.londonhotelgroup.co.uk`, PHP 8.3 or newer.
2. Connect the repository, set the **project root** to `backend`.
3. Paste `deploy/deploy.sh` into the site's Deploy Script.
4. Add a MySQL database and put its credentials in the site's Environment tab
   (start from `backend/.env.example`).
5. Enable Let's Encrypt for the domain.
6. Run the first deploy, then in the site's Commands tab:
   ```
   php artisan migrate --force
   php artisan db:seed --force      # demo data — skip on a real install
   ```

## Plain VPS

```bash
# One-off setup
sudo apt install -y php8.3-{fpm,mysql,mbstring,xml,curl,zip,gd,intl} mysql-server nginx
sudo mysql -e "CREATE DATABASE lhg_property_hub CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
sudo mysql -e "CREATE USER 'lhg'@'localhost' IDENTIFIED BY 'CHANGE_ME';"
sudo mysql -e "GRANT ALL ON lhg_property_hub.* TO 'lhg'@'localhost'; FLUSH PRIVILEGES;"

git clone <repo> /var/www/property-hub
cd /var/www/property-hub/backend
cp .env.example .env          # fill in DB credentials and APP_URL
composer install --no-dev --optimize-autoloader
php artisan key:generate
php artisan migrate --force
php artisan storage:link

sudo cp deploy/nginx.conf /etc/nginx/sites-available/property-hub
sudo ln -sf /etc/nginx/sites-available/property-hub /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
sudo certbot --nginx -d api.londonhotelgroup.co.uk

# Subsequent deploys
./deploy/deploy.sh
```

## Permissions

The web user needs to write two directories and nothing else:

```bash
sudo chown -R www-data:www-data storage bootstrap/cache
sudo chmod -R 775 storage bootstrap/cache
```

## Before you go live

- [ ] `APP_DEBUG=false` and `APP_ENV=production` in `.env`
- [ ] `php artisan key:generate` has been run and `APP_KEY` is set
- [ ] Every seeded demo account's password changed, or the seeder never run
- [ ] `CORS_ALLOWED_ORIGINS` lists only origins you control
- [ ] A database backup schedule exists
- [ ] `storage/app` is excluded from any public path (the nginx config above does this)
- [ ] The iOS `Config/Release.xcconfig` `API_BASE_URL` matches this host
