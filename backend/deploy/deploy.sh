#!/usr/bin/env bash
#
# Zero-thought deploy for a Laravel Forge site or a plain VPS.
#
# Forge: paste this into the site's Deploy Script and it runs on every push.
# Plain VPS: run it from the site root as the deploy user.
#
# It is safe to re-run — every step is idempotent.

set -euo pipefail

APP_DIR="${APP_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PHP="${PHP:-php}"
BRANCH="${BRANCH:-main}"

cd "$APP_DIR"

echo "==> Deploying from $APP_DIR (branch $BRANCH)"

# Stop accepting traffic while the schema and caches move underneath us.
# `|| true` because the very first deploy has nothing to put down.
$PHP artisan down --render="errors::503" --retry=15 || true
trap '$PHP artisan up || true' EXIT

echo "==> Fetching code"
git fetch --depth=1 origin "$BRANCH"
git reset --hard "origin/$BRANCH"

echo "==> Installing dependencies"
composer install --no-interaction --prefer-dist --optimize-autoloader --no-dev

echo "==> Running migrations"
# --force is required because this is a non-interactive production run.
$PHP artisan migrate --force

echo "==> Rebuilding caches"
$PHP artisan config:cache
$PHP artisan route:cache
$PHP artisan view:cache
$PHP artisan event:cache

echo "==> Linking storage"
$PHP artisan storage:link || true

echo "==> Restarting workers"
$PHP artisan queue:restart

if command -v php-fpm >/dev/null 2>&1; then
    ( sudo -n systemctl reload php8.4-fpm 2>/dev/null \
      || sudo -n systemctl reload php-fpm 2>/dev/null \
      || true )
fi

echo "==> Deploy complete"
