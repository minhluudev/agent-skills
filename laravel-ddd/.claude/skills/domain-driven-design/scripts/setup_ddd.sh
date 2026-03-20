#!/usr/bin/env bash
#
# setup_ddd.sh
#
# Scaffolds the initial Domain Oriented Design directory structure in a Laravel project.
# Run from the root of your Laravel project:
#
#   bash scripts/setup_ddd.sh
#
# This is a one-time setup. It will not overwrite existing files.

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "========================================"
echo " Setting up Domain Oriented Design"
echo " Project root: $PROJECT_ROOT"
echo "========================================"

# ---------- Create top-level directories ----------
DIRS=(
    "domain"
    "infrastructure"
    "support"
    "tests/Unit/Domain"
    "tests/Integration/Repositories"
)

for dir in "${DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        echo "  created: $dir/"
    else
        echo "  exists:  $dir/"
    fi
done

# ---------- Add .gitkeep to empty dirs so git tracks them ----------
for dir in "domain" "infrastructure" "support"; do
    if [ -z "$(ls -A "$dir" 2>/dev/null)" ]; then
        touch "$dir/.gitkeep"
    fi
done

# ---------- Check composer.json autoload ----------
echo ""
echo ">> Checking composer.json autoload..."

if grep -q '"Domain\\\\":' composer.json 2>/dev/null; then
    echo "   Domain\\ already registered in composer.json"
else
    echo ""
    echo "   ACTION REQUIRED: Add the following to the 'autoload.psr-4' section of composer.json:"
    echo ""
    echo '     "Domain\\": "domain/",'
    echo '     "Infrastructure\\": "infrastructure/",'
    echo '     "Support\\": "support/"'
    echo ""
    echo "   Then run: composer dump-autoload"
fi

# ---------- Check DomainServiceProvider ----------
echo ""
echo ">> Checking DomainServiceProvider..."

PROVIDER_PATH="app/Providers/DomainServiceProvider.php"
if [ -f "$PROVIDER_PATH" ]; then
    echo "   $PROVIDER_PATH already exists"
else
    cat > "$PROVIDER_PATH" << 'PHP'
<?php

namespace App\Providers;

use Illuminate\Support\ServiceProvider;

class DomainServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        // Bind repository interfaces to their Eloquent implementations here.
        // Example:
        // $this->app->bind(
        //     \Domain\Products\Repositories\ProductRepository::class,
        //     \Infrastructure\Products\Repositories\EloquentProductRepository::class,
        // );
    }
}
PHP
    echo "   created: $PROVIDER_PATH"
    echo ""
    echo "   ACTION REQUIRED: Register the provider in bootstrap/providers.php (Laravel 11+):"
    echo "     App\\Providers\\DomainServiceProvider::class,"
    echo "   Or in config/app.php 'providers' array (Laravel 10 and below)."
fi

# ---------- Done ----------
echo ""
echo "========================================"
echo " Setup complete."
echo ""
echo " Next steps:"
echo "   1. Update composer.json autoload (see above) and run: composer dump-autoload"
echo "   2. Register DomainServiceProvider in your app"
echo "   3. Start building your first domain: domain/{YourDomain}/"
echo "      Actions/, DTOs/, Models/, Repositories/, QueryBuilders/, Collections/"
echo "========================================"
