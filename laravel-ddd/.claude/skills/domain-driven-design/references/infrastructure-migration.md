# Migrating from Technical to Modular Infrastructure Organization

## When to Migrate

Migrate from Technical to Modular organization when you experience:

1. **Frequent merge conflicts** in Infrastructure directories
2. **7+ bounded contexts** with multiple teams
3. **Team ownership confusion** - unclear who maintains which controllers
4. **Context isolation violations** - contexts accidentally coupling through Infrastructure
5. **Independent deployment needs** - want to deploy contexts separately
6. **Microservices future** - planning to extract contexts to services

## Migration Strategies

### Strategy 1: Big Bang Migration (Not Recommended)

Migrate all contexts at once. **Only for small projects** or during major refactoring windows.

**Pros:**
- ✅ Clean, consistent structure immediately
- ✅ No mixed patterns

**Cons:**
- ❌ High risk (everything changes at once)
- ❌ Large PR/changeset
- ❌ Difficult to test incrementally
- ❌ Blocks all other development

### Strategy 2: Incremental Migration (Recommended)

Migrate one context at a time, starting with the most independent or problematic context.

**Pros:**
- ✅ Low risk (one context at a time)
- ✅ Testable at each step
- ✅ Doesn't block other development
- ✅ Can pause/resume migration

**Cons:**
- ❌ Mixed patterns during migration
- ❌ Takes longer overall

## Incremental Migration Process

### Phase 1: Preparation

**Step 1: Identify Bounded Contexts**

List all your bounded contexts and their dependencies:

```
Contact Management
  ├── Dependencies: None (upstream)
  └── Depended on by: Sales, Billing

Sales
  ├── Dependencies: Contact, Product
  └── Depended on by: Billing

Billing
  ├── Dependencies: Contact, Sales
  └── Depended on by: None (downstream)
```

**Step 2: Choose Migration Order**

Migrate in dependency order (upstream first):
1. **Leaf contexts** (no dependencies) or **upstream contexts** (depended on by others)
2. **Middle contexts**
3. **Downstream contexts** (most dependencies)

**Example order:** Contact → Sales → Billing

**Why?** Upstream contexts have fewer Integration/ directories to reorganize.

**Step 3: Create Shared Infrastructure**

Before migrating any context, create the Shared directory:

```bash
mkdir -p src/Infrastructure/Shared/Http/Middleware
mkdir -p src/Infrastructure/Shared/Providers
mkdir -p src/Infrastructure/Shared/Console
```

Move truly shared Infrastructure components to Shared:

**Middleware** (auth, CORS, rate limiting):
```bash
mv src/Infrastructure/Http/Middleware/Authenticate.php \
   src/Infrastructure/Shared/Http/Middleware/Authenticate.php

mv src/Infrastructure/Http/Middleware/Cors.php \
   src/Infrastructure/Shared/Http/Middleware/Cors.php
```

Update namespaces:
```php
// FROM:
namespace Infrastructure\Http\Middleware;

// TO:
namespace Infrastructure\Shared\Http\Middleware;
```

**Providers** (if you want them shared):
```bash
cp src/Infrastructure/Providers/*.php src/Infrastructure/Shared/Providers/
# Update namespaces in copied files
```

### Phase 2: Migrate One Context

For each context, follow this checklist:

#### Step 1: Create Context Directories

```bash
# Example: Migrating Contact context
CONTEXT="Contact"

mkdir -p src/Infrastructure/${CONTEXT}/Http/Controllers
mkdir -p src/Infrastructure/${CONTEXT}/Http/Requests
mkdir -p src/Infrastructure/${CONTEXT}/Database/Eloquent
mkdir -p src/Infrastructure/${CONTEXT}/Database/Repositories
mkdir -p src/Infrastructure/${CONTEXT}/Console
mkdir -p src/Infrastructure/${CONTEXT}/Listeners
mkdir -p src/Infrastructure/${CONTEXT}/Integration
```

#### Step 2: Move Controllers

**Identify Contact-specific controllers:**
```bash
# List all controllers
ls src/Infrastructure/Http/Controllers/

# Example output:
# ContactController.php
# ContactExportController.php
# SalesController.php  # Don't move yet
# BillingController.php  # Don't move yet
```

**Move Contact controllers:**
```bash
mv src/Infrastructure/Http/Controllers/ContactController.php \
   src/Infrastructure/Contact/Http/Controllers/ContactController.php

mv src/Infrastructure/Http/Controllers/ContactExportController.php \
   src/Infrastructure/Contact/Http/Controllers/ContactExportController.php
```

**Update namespaces:**
```php
// In ContactController.php
// FROM:
namespace Infrastructure\Http\Controllers;

// TO:
namespace Infrastructure\Contact\Http\Controllers;
```

**Update imports** in other files that reference these controllers:
```php
// In routes/api.php
// FROM:
use Infrastructure\Http\Controllers\ContactController;

// TO:
use Infrastructure\Contact\Http\Controllers\ContactController;
```

#### Step 3: Move Form Requests

```bash
mv src/Infrastructure/Http/Requests/CreateContactRequest.php \
   src/Infrastructure/Contact/Http/Requests/CreateContactRequest.php

mv src/Infrastructure/Http/Requests/UpdateContactRequest.php \
   src/Infrastructure/Contact/Http/Requests/UpdateContactRequest.php
```

**Update namespaces:**
```php
// FROM:
namespace Infrastructure\Http\Requests;

// TO:
namespace Infrastructure\Contact\Http\Requests;
```

#### Step 4: Move Eloquent Models

```bash
mv src/Infrastructure/Database/Eloquent/ContactModel.php \
   src/Infrastructure/Contact/Database/Eloquent/ContactModel.php

mv src/Infrastructure/Database/Eloquent/ContactInteractionModel.php \
   src/Infrastructure/Contact/Database/Eloquent/ContactInteractionModel.php
```

**Update namespaces:**
```php
// FROM:
namespace Infrastructure\Database\Eloquent;

// TO:
namespace Infrastructure\Contact\Database\Eloquent;
```

**Update model relationships** (if models reference each other):
```php
// In ContactModel.php
// FROM:
use Infrastructure\Database\Eloquent\ContactInteractionModel;

// TO:
use Infrastructure\Contact\Database\Eloquent\ContactInteractionModel;
```

#### Step 5: Move Repositories

```bash
mv src/Infrastructure/Database/Repositories/EloquentContactRepository.php \
   src/Infrastructure/Contact/Database/Repositories/EloquentContactRepository.php
```

**Update namespaces:**
```php
// FROM:
namespace Infrastructure\Database\Repositories;
use Infrastructure\Database\Eloquent\ContactModel;

// TO:
namespace Infrastructure\Contact\Database\Repositories;
use Infrastructure\Contact\Database\Eloquent\ContactModel;
```

**Update service provider bindings:**
```php
// In Infrastructure/Shared/Providers/RepositoryServiceProvider.php
// FROM:
use Infrastructure\Database\Repositories\EloquentContactRepository;

// TO:
use Infrastructure\Contact\Database\Repositories\EloquentContactRepository;
```

#### Step 6: Move Event Listeners

**Identify Contact-specific listeners:**
```bash
ls src/Infrastructure/Listeners/

# Example:
# SendWelcomeEmailOnContactCreated.php  # Contact listener
# CreateOpportunityOnContactCreated.php  # Sales listener (don't move yet)
```

```bash
mv src/Infrastructure/Listeners/SendWelcomeEmailOnContactCreated.php \
   src/Infrastructure/Contact/Listeners/SendWelcomeEmailOnContactCreated.php
```

**Update namespaces:**
```php
// FROM:
namespace Infrastructure\Listeners;

// TO:
namespace Infrastructure\Contact\Listeners;
```

**Update EventServiceProvider:**
```php
// In Infrastructure/Shared/Providers/EventServiceProvider.php
// FROM:
use Infrastructure\Listeners\SendWelcomeEmailOnContactCreated;

// TO:
use Infrastructure\Contact\Listeners\SendWelcomeEmailOnContactCreated;
```

#### Step 7: Move Console Commands

```bash
mv src/Infrastructure/Console/SyncContactsCommand.php \
   src/Infrastructure/Contact/Console/SyncContactsCommand.php
```

**Update namespaces:**
```php
// FROM:
namespace App\Infrastructure\Console;

// TO:
namespace App\Infrastructure\Contact\Console;
```

**Update kernel registration** (if manually registered):
```php
// In app/Console/Kernel.php
// FROM:
use App\Infrastructure\Console\SyncContactsCommand;

// TO:
use App\Infrastructure\Contact\Console\SyncContactsCommand;
```

#### Step 8: Reorganize Integration Directory

**Technical pattern:**
```
Infrastructure/Integration/Contact/
├── ContactGateway.php       # Used by Sales to access Contact
└── ContactTranslator.php
```

**Modular pattern:**
```
Infrastructure/Sales/Integration/Contact/
├── ContactGateway.php       # Sales → Contact gateway (moves to Sales context)
└── ContactTranslator.php
```

**Since we're migrating Contact first**, leave Integration/Contact/ alone for now. It will be moved when we migrate the **consuming context** (Sales).

**But if Contact has Integration to external systems:**
```bash
# If Contact integrates with external CRM
mv src/Infrastructure/Integration/CRM \
   src/Infrastructure/Contact/Integration/CRM
```

#### Step 9: Run Tests

**Test the migrated context:**
```bash
# Run unit tests
vendor/bin/phpunit --filter Contact

# Run feature tests
vendor/bin/phpunit --filter ContactController

# Run PHPStan
vendor/bin/phpstan analyse src/Infrastructure/Contact --level=max

# Check for broken imports
composer dump-autoload
```

#### Step 10: Update Routes (Optional)

**Consider organizing routes by context:**

**Before:**
```php
// routes/api.php
Route::post('/contacts', [ContactController::class, 'store']);
Route::post('/sales', [SalesController::class, 'store']);
Route::post('/billing', [BillingController::class, 'store']);
```

**After:**
```php
// routes/api/contact.php
use Infrastructure\Contact\Http\Controllers\ContactController;

Route::prefix('contacts')->group(function () {
    Route::post('/', [ContactController::class, 'store']);
    Route::get('/{id}', [ContactController::class, 'show']);
});

// routes/api.php (loads context routes)
Route::middleware('api')->group(base_path('routes/api/contact.php'));
Route::middleware('api')->group(base_path('routes/api/sales.php'));
```

#### Step 11: Commit

```bash
git add src/Infrastructure/Contact
git add src/Infrastructure/Shared
git add -u  # Add all deletions/moves
git commit -m "refactor: migrate Contact context to modular Infrastructure organization

- Move Contact controllers, models, repositories to Infrastructure/Contact/
- Create Infrastructure/Shared for shared middleware and providers
- Update all namespaces and imports
- Update service provider bindings
- Update EventServiceProvider listener registrations

See .claude/skills/domain-driven-design/references/infrastructure-migration.md
"
```

### Phase 3: Repeat for Each Context

Repeat Phase 2 for each remaining context in dependency order.

**Important:** When migrating a context that **depends** on already-migrated contexts:

**Move Integration gateways to the consuming context:**

```bash
# When migrating Sales (which depends on Contact)
mv src/Infrastructure/Integration/Contact/ \
   src/Infrastructure/Sales/Integration/Contact/
```

**Update namespaces:**
```php
// In ContactGateway.php
// FROM:
namespace Infrastructure\Integration\Contact;

// TO:
namespace Infrastructure\Sales\Integration\Contact;
```

This makes dependencies explicit: `Sales/Integration/Contact/` shows that Sales depends on Contact.

### Phase 4: Cleanup

After migrating all contexts:

**Remove old directories:**
```bash
# Check if empty
ls src/Infrastructure/Database/Eloquent/
ls src/Infrastructure/Database/Repositories/
ls src/Infrastructure/Http/Controllers/

# If empty, remove
rmdir src/Infrastructure/Database/Eloquent/
rmdir src/Infrastructure/Database/Repositories/
rmdir src/Infrastructure/Http/Controllers/
rmdir src/Infrastructure/Http/Requests/
rmdir src/Infrastructure/Listeners/
rmdir src/Infrastructure/Console/

# Remove old Integration directory
rm -rf src/Infrastructure/Integration/
```

**Update documentation:**
- Update CLAUDE.md with modular structure
- Update README.md
- Update team onboarding docs

## Namespace Mapping Reference

### Controllers
```php
// Before
Infrastructure\Http\Controllers\ContactController

// After
Infrastructure\Contact\Http\Controllers\ContactController
```

### Form Requests
```php
// Before
Infrastructure\Http\Requests\CreateContactRequest

// After
Infrastructure\Contact\Http\Requests\CreateContactRequest
```

### Eloquent Models
```php
// Before
Infrastructure\Database\Eloquent\ContactModel

// After
Infrastructure\Contact\Database\Eloquent\ContactModel
```

### Repositories
```php
// Before
Infrastructure\Database\Repositories\EloquentContactRepository

// After
Infrastructure\Contact\Database\Repositories\EloquentContactRepository
```

### Listeners
```php
// Before
Infrastructure\Listeners\SendWelcomeEmailOnContactCreated

// After
Infrastructure\Contact\Listeners\SendWelcomeEmailOnContactCreated
```

### Console Commands
```php
// Before
App\Infrastructure\Console\SyncContactsCommand

// After
App\Infrastructure\Contact\Console\SyncContactsCommand
```

### Middleware (Shared)
```php
// Before
Infrastructure\Http\Middleware\Authenticate

// After
Infrastructure\Shared\Http\Middleware\Authenticate
```

### Integration Gateways
```php
// Before (Technical)
Infrastructure\Integration\Contact\ContactGateway

// After (Modular - moved to consuming context)
Infrastructure\Sales\Integration\Contact\ContactGateway
```

## Composer Autoload

No changes needed! PSR-4 autoloading handles the new structure automatically:

```json
"autoload": {
    "psr-4": {
        "Infrastructure\\": "src/Infrastructure/"
    }
}
```

Just run `composer dump-autoload` after moving files.

## Common Issues and Solutions

### Issue 1: Broken Imports

**Symptom:** Class not found errors after migration

**Solution:**
```bash
# Search for old namespace usage
grep -r "Infrastructure\\\\Http\\\\Controllers\\\\ContactController" src/
grep -r "Infrastructure\\\\Database\\\\Eloquent\\\\ContactModel" src/

# Update all imports
# Then regenerate autoload
composer dump-autoload
```

### Issue 2: Service Provider Bindings Fail

**Symptom:** `Class [Infrastructure\Database\Repositories\EloquentContactRepository] does not exist`

**Solution:**
Update service provider to use new namespace:
```php
// In Infrastructure/Shared/Providers/RepositoryServiceProvider.php
$this->app->bind(
    ContactRepositoryInterface::class,
    \Infrastructure\Contact\Database\Repositories\EloquentContactRepository::class
);
```

### Issue 3: Event Listeners Not Firing

**Symptom:** Domain events dispatched but listeners don't execute

**Solution:**
Update EventServiceProvider with new listener namespaces:
```php
protected $listen = [
    ContactCreated::class => [
        \Infrastructure\Contact\Listeners\SendWelcomeEmailOnContactCreated::class,
    ],
];
```

### Issue 4: Routes Not Found

**Symptom:** 404 errors for endpoints that should exist

**Solution:**
Update route file imports:
```php
// In routes/api.php
use Infrastructure\Contact\Http\Controllers\ContactController;
```

### Issue 5: Tests Fail

**Symptom:** Tests can't find controllers or models

**Solution:**
Update test imports and ensure test autoload is configured:
```json
// composer.json
"autoload-dev": {
    "psr-4": {
        "Tests\\": "tests/"
    }
}
```

Then regenerate autoload: `composer dump-autoload`

## Testing the Migration

### Automated Testing

**Create a test script:**
```bash
#!/bin/bash
# test-migration.sh

echo "Testing migrated contexts..."

# 1. Dump autoload
composer dump-autoload

# 2. Run PHPStan on migrated contexts
vendor/bin/phpstan analyse src/Infrastructure/Contact --level=max
vendor/bin/phpstan analyse src/Infrastructure/Sales --level=max

# 3. Run unit tests
vendor/bin/phpunit --testsuite Unit

# 4. Run feature tests
vendor/bin/phpunit --testsuite Feature

echo "✅ Migration tests passed!"
```

### Manual Testing

**Test each migrated context:**

1. **API endpoints work:**
   ```bash
   curl -X POST http://localhost/api/contacts \
     -H "Content-Type: application/json" \
     -d '{"name": "Test Contact", "email": "test@example.com"}'
   ```

2. **Console commands work:**
   ```bash
   php artisan contact:sync
   php artisan sales:generate-report
   ```

3. **Event listeners fire:**
   - Trigger events that should fire listeners
   - Check logs/database for expected side effects

4. **Cross-context integration works:**
   - Test gateways between contexts
   - Verify anti-corruption layers translate correctly

## Rollback Plan

If migration fails, rollback steps:

1. **Git reset:**
   ```bash
   git reset --hard HEAD^
   ```

2. **Or revert specific commit:**
   ```bash
   git revert <migration-commit-hash>
   ```

3. **Restore from backup:**
   ```bash
   cp -r backup/src/Infrastructure/* src/Infrastructure/
   composer dump-autoload
   ```

## Migration Checklist

Use this checklist for each context:

- [ ] Create context Infrastructure directories
- [ ] Move controllers (update namespaces)
- [ ] Move form requests (update namespaces)
- [ ] Move Eloquent models (update namespaces and relationships)
- [ ] Move repositories (update namespaces and imports)
- [ ] Move event listeners (update namespaces)
- [ ] Move console commands (update namespaces)
- [ ] Reorganize Integration/ (if applicable)
- [ ] Update service provider bindings
- [ ] Update EventServiceProvider registrations
- [ ] Update route file imports
- [ ] Update test imports
- [ ] Run `composer dump-autoload`
- [ ] Run PHPStan on migrated context
- [ ] Run unit tests for context
- [ ] Run feature tests for context
- [ ] Test API endpoints manually
- [ ] Test console commands
- [ ] Test cross-context integration
- [ ] Commit changes
- [ ] Update documentation

## Summary

**Incremental migration** is the safest approach:
1. **Prepare:** Create Shared/, move shared components
2. **Migrate:** One context at a time in dependency order
3. **Test:** After each context migration
4. **Cleanup:** Remove old directories when all contexts migrated

**Key principles:**
- Migrate upstream contexts first (fewer dependencies)
- Test thoroughly after each context
- Update namespaces, imports, and bindings
- Move Integration/ gateways to consuming contexts
- Keep Shared/ for truly shared infrastructure

Good luck with your migration! 🚀
