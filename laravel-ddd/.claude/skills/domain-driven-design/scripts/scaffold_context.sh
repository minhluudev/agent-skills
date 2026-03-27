#!/usr/bin/env bash

# Scaffold a new DDD bounded context with all necessary directories
#
# Usage: ./scaffold_context.sh ContextName
#
# Run from the Laravel app root (the directory containing app/)
#
# Examples:
#   ./scaffold_context.sh Contact
#   ./scaffold_context.sh Subscription

set -e

# Display usage
usage() {
    echo "Usage: ./scaffold_context.sh ContextName"
    echo ""
    echo "Run from the Laravel app root (the directory containing app/)."
    echo ""
    echo "Examples:"
    echo "  ./scaffold_context.sh Contact"
    echo "  ./scaffold_context.sh Subscription"
    echo ""
    echo "See references/infrastructure.md for layer guidance."
    exit 1
}

# Check arguments
if [ $# -eq 0 ]; then
    usage
fi

CONTEXT_NAME="$1"

BASE_PATH="$(pwd)/app"

# Verify we're in a Laravel app root
if [ ! -d "$BASE_PATH" ]; then
    echo "Error: No 'app/' directory found in $(pwd)"
    echo "Run this script from the Laravel app root."
    exit 1
fi

DIRECTORIES=(
    # Domain layer — pure business logic, no framework deps
    "Domain/${CONTEXT_NAME}/Entities"
    "Domain/${CONTEXT_NAME}/ValueObjects"
    "Domain/${CONTEXT_NAME}/Aggregates"
    "Domain/${CONTEXT_NAME}/Services"
    "Domain/${CONTEXT_NAME}/Events"
    "Domain/${CONTEXT_NAME}/Exceptions"
    "Domain/${CONTEXT_NAME}/Repositories"

    # Application layer — CQRS: Commands, Queries, UseCases, DTOs
    "Application/${CONTEXT_NAME}/Commands"
    "Application/${CONTEXT_NAME}/Queries"
    "Application/${CONTEXT_NAME}/UseCases"
    "Application/${CONTEXT_NAME}/DTOs"

    # Infrastructure layer — Eloquent models, repository implementations, external services
    "Infrastructure/Persistence/Eloquent/Models"
    "Infrastructure/Persistence/Eloquent/Repositories"
    "Infrastructure/Providers"

    # Interfaces layer — HTTP controllers, form requests, API resources, jobs
    "Interfaces/Http/Controllers"
    "Interfaces/Http/Requests"
    "Interfaces/Http/Resources"
    "Interfaces/Jobs"
    "Interfaces/Console"
)

echo "🚀 Scaffolding DDD Bounded Context: ${CONTEXT_NAME}"
echo ""

# Create directories
for dir in "${DIRECTORIES[@]}"; do
    FULL_PATH="${BASE_PATH}/${dir}"
    if [ ! -d "$FULL_PATH" ]; then
        mkdir -p "$FULL_PATH"
        echo "✓ Created: app/${dir}"
    else
        echo "⊘ Exists:  app/${dir}"
    fi
done

echo ""
echo "✅ Bounded Context '${CONTEXT_NAME}' scaffolded successfully!"
echo ""
echo "Next steps:"
echo "1. Define Value Objects in app/Domain/${CONTEXT_NAME}/ValueObjects/"
echo "2. Create Entity/Aggregate in app/Domain/${CONTEXT_NAME}/Entities/ or Aggregates/"
echo "3. Define Repository interface in app/Domain/${CONTEXT_NAME}/Repositories/"
echo "4. Create Domain Events in app/Domain/${CONTEXT_NAME}/Events/"
echo "5. Implement Domain Services in app/Domain/${CONTEXT_NAME}/Services/ (if needed)"
echo "6. Create Commands/Queries in app/Application/${CONTEXT_NAME}/Commands|Queries/"
echo "7. Create DTOs in app/Application/${CONTEXT_NAME}/DTOs/"
echo "8. Create UseCase in app/Application/${CONTEXT_NAME}/UseCases/"
echo "9. Create Eloquent Model in app/Infrastructure/Persistence/Eloquent/Models/"
echo "10. Implement Repository in app/Infrastructure/Persistence/Eloquent/Repositories/"
echo "11. Bind interface in app/Infrastructure/Providers/DomainServiceProvider.php"
echo "12. Create Form Request in app/Interfaces/Http/Requests/"
echo "13. Create Controller in app/Interfaces/Http/Controllers/"
echo "14. Create API Resource in app/Interfaces/Http/Resources/"
echo "15. Register route in routes/api.php"
