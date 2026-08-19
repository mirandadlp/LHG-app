#!/usr/bin/env bash
#
# Deploy script for a plain VPS.
#
# Run it from anywhere as the deploy user; it locates the Laravel root itself:
#
#     backend/deploy/deploy.sh
#
# It is safe to re-run — every step is idempotent.
#
# On Laravel Forge use forge-deploy-script.sh instead. Forge takes pasted text
# rather than a file, and performs its own `git pull`, so the two would fight
# over the working tree.

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
