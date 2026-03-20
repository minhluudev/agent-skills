#!/usr/bin/env bash
#
# check_quality.sh
#
# Runs code style (Pint) and static analysis (PHPStan) on the domain-oriented layers.
# Run from the root of your Laravel project: bash scripts/check_quality.sh
#
# Requirements:
#   - Laravel Pint:  composer require laravel/pint --dev
#   - PHPStan:       composer require phpstan/phpstan --dev
#                    (or larastan: composer require nunomaduro/larastan --dev)
#
# Optional: add a phpstan.neon in your project root to configure analysis level and paths.

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

PINT="./vendor/bin/pint"
PHPSTAN="./vendor/bin/phpstan"

DOMAIN_DIRS=("app" "domain" "infrastructure" "support")

echo "========================================"
echo " Code Quality Check"
echo "========================================"

# ---------- Laravel Pint (code style) ----------
if [ -f "$PINT" ]; then
    echo ""
    echo ">> Running Laravel Pint (code style)..."
    "$PINT" "${DOMAIN_DIRS[@]}" --test 2>&1 || {
        echo ""
        echo "  Pint found style issues. Run './vendor/bin/pint' to auto-fix them."
        STYLE_FAILED=1
    }
else
    echo "  [skip] Laravel Pint not installed. Run: composer require laravel/pint --dev"
fi

# ---------- PHPStan (static analysis) ----------
if [ -f "$PHPSTAN" ]; then
    echo ""
    echo ">> Running PHPStan (static analysis)..."

    # Use phpstan.neon if present, otherwise fall back to inline config
    if [ -f "phpstan.neon" ] || [ -f "phpstan.neon.dist" ]; then
        "$PHPSTAN" analyse 2>&1 || PHPSTAN_FAILED=1
    else
        "$PHPSTAN" analyse \
            --level=5 \
            app domain infrastructure support \
            2>&1 || PHPSTAN_FAILED=1
    fi
else
    echo "  [skip] PHPStan not installed. Run: composer require phpstan/phpstan --dev"
fi

# ---------- Summary ----------
echo ""
echo "========================================"

if [ "${STYLE_FAILED:-0}" -eq 1 ] || [ "${PHPSTAN_FAILED:-0}" -eq 1 ]; then
    echo " FAILED — fix the issues above and re-run."
    echo "========================================"
    exit 1
else
    echo " All checks passed."
    echo "========================================"
fi
