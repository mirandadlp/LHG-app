# ---------------------------------------------------------------------------
# Laravel Forge deploy script
#
# Paste the contents of this file into Forge → your site → Deployments →
# Deploy Script. Forge runs it on the server after every push.
#
# It is NOT run from the repository. It lives here so it is version-controlled
# and reviewable alongside the code it deploys.
#
# Why this differs from Forge's default:
#   · Laravel is in backend/, not at the repository root, so every artisan and
#     composer call has to be made from there.
#   · Forge's default also runs `composer install` before the script, which
#     fails here for the same reason — leave "Install Composer Dependencies"
#     unchecked on the site's repository settings.
# ---------------------------------------------------------------------------

cd $FORGE_SITE_PATH
git pull origin $FORGE_SITE_BRANCH

cd $FORGE_SITE_PATH/backend

$FORGE_COMPOSER install --no-dev --no-interaction --prefer-dist --optimize-autoloader

# Maintenance mode only spans the risky part. `|| true` because the very first
# deploy has no application key yet and cannot boot far enough to go down.
( php artisan down --retry=15 ) || true

php artisan migrate --force

php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan event:cache

php artisan storage:link || true
php artisan queue:restart

php artisan up || true

( flock -w 10 9 || exit 1
    echo 'Restarting FPM...'; sudo -S service $FORGE_PHP_FPM reload ) 9>/tmp/fpmlock
