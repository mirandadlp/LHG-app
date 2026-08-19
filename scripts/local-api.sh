#!/usr/bin/env bash
#
# Starts the API on http://localhost:8000 against a local SQLite file, which is
# where ios/Config/Debug.xcconfig points the simulator.
#
#   scripts/local-api.sh            start the server, setting up anything missing
#   scripts/local-api.sh --fresh    wipe the database and re-seed first
#
# Everything it creates is gitignored, so a --fresh is always safe to run.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND="$ROOT/backend"
DB="$BACKEND/database/database.sqlite"
PORT="${PORT:-8000}"

# PHP and Composer live in the home directory (installed via php.new), which is
# not on PATH for non-login shells such as an IDE's terminal.
export PATH="$HOME/.config/herd-lite/bin:$PATH"

if ! command -v php >/dev/null 2>&1; then
    echo "php not found. Install it with:" >&2
    echo '  /bin/bash -c "$(curl -fsSL https://php.new/install/mac/8.4)"' >&2
    exit 1
fi

cd "$BACKEND"

if [ ! -d vendor ]; then
    echo "==> Installing Composer dependencies"
    composer install --no-interaction --prefer-dist
fi

if [ ! -f .env ]; then
    echo "==> No .env — copying .env.example (edit it for SQLite before continuing)"
    cp .env.example .env
    php artisan key:generate
fi

[ -f "$DB" ] || touch "$DB"

fresh=false
[ "${1:-}" = "--fresh" ] && fresh=true

# An empty file is a database that has never been migrated.
if [ ! -s "$DB" ]; then
    fresh=true
fi

if [ "$fresh" = true ]; then
    echo "==> Rebuilding the database and seeding demo data"
    php artisan migrate:fresh --seed --force
fi

# Stale config/route caches survive an .env edit and cause confusing failures.
php artisan optimize:clear >/dev/null

cat <<INFO

  API      http://localhost:8000
  Database $DB
  Sign in   priya.raman@londonhotelgroup.co.uk / password   (administrator)
            jane.smith@londonhotelgroup.co.uk  / password   (property manager)
            meher.n@londonhotelgroup.co.uk     / password   (leadership, read-only)

  Leave this running, then hit Run in Xcode.

INFO

exec php artisan serve --host=0.0.0.0 --port="$PORT"
