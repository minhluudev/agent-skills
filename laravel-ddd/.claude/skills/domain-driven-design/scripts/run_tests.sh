#!/usr/bin/env bash
#
# run_tests.sh
#
# Runs the Laravel test suite with useful defaults for a Domain Oriented Design project.
# Run from the root of your Laravel project: bash scripts/run_tests.sh [options]
#
# Usage:
#   bash scripts/run_tests.sh                        # run all tests
#   bash scripts/run_tests.sh --filter=CreateProduct # run tests matching a name
#   bash scripts/run_tests.sh --testsuite=Domain     # run a specific suite
#   bash scripts/run_tests.sh --coverage             # generate HTML coverage report
#
# Test organisation recommended for this architecture:
#   tests/
#     Unit/
#       Domain/          ← Tests for Actions, DTOs, Domain Models (no DB needed)
#         Products/
#           Actions/
#             CreateProductActionTest.php
#     Feature/
#       Products/        ← End-to-end HTTP tests
#         CreateProductTest.php
#     Integration/
#       Repositories/    ← Tests that hit a real DB
#         EloquentProductRepositoryTest.php

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "========================================"
echo " Running Tests"
echo "========================================"
echo ""

# Pass all arguments through to artisan test (e.g., --filter, --coverage)
php artisan test "$@"

EXIT_CODE=$?

echo ""
echo "========================================"
if [ $EXIT_CODE -eq 0 ]; then
    echo " All tests passed."
else
    echo " Tests failed. See output above."
fi
echo "========================================"

exit $EXIT_CODE
