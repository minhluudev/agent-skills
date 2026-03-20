---
name: domain-driven-design
description: >
  Scaffolds and generates code for Laravel projects structured around Domain Oriented Design (DOD) — a pragmatic approach
  that places business logic at the center of the application. Use this skill whenever the user wants to:
  - Set up a Domain Oriented Design structure in a Laravel project
  - Generate any DDD component (Action, DTO, Repository, QueryBuilder, Collection, Command, Handler, Domain Model)
  - Refactor an existing Laravel MVC project toward a domain-oriented architecture
  - Ask about where to place business logic, how to structure a domain, or how to implement any DOD pattern in Laravel
  - Ask questions like "how do I create an Action?", "where should this logic live?", "how do I set up repositories?"
  Always use this skill when the user mentions Actions, DTOs, Domain Models, Repositories in a Laravel context, or asks
  how to organize complex business logic in Laravel.
---

# Domain Oriented Design for Laravel

This skill helps you build Laravel applications structured around **Domain Oriented Design** — a pragmatic approach
inspired by DDD that puts business logic first. The core philosophy: business logic lives in the `Domain` layer,
completely independent of Laravel's MVC infrastructure.

## Architecture Overview

```
app/                          ← Application layer (Laravel MVC)
  Http/
    Controllers/
    Requests/
    Resources/
  Console/
domain/                       ← Domain layer (pure business logic)
  {DomainName}/
    Actions/                  ← Use cases / business operations
    DTOs/                     ← Typed data transfer objects
    Models/                   ← Domain entities (NOT Eloquent models)
    Repositories/             ← Repository interfaces only
    QueryBuilders/            ← Custom Eloquent query builders
    Collections/              ← Custom Eloquent collections
    Commands/                 ← (Optional) CommandBus commands
    Handlers/                 ← (Optional) CommandBus handlers
infrastructure/               ← Infrastructure layer (DB, external services)
  {DomainName}/
    Models/                   ← Eloquent models
    Repositories/             ← Eloquent repository implementations
support/                      ← Shared helpers, third-party integrations
```

See `references/architecture.md` for detailed explanation of each layer and when to use each pattern.
See `templates/` for ready-to-use PHP code templates for every component.

## Workflow: Generating Code

When the user asks to generate a component, follow this process:

### 1. Identify what to generate

Ask (or infer from context):
- **Domain name** — the business context (e.g., `Products`, `Orders`, `Users`)
- **Component type** — Action, DTO, Repository, QueryBuilder, Collection, Domain Model, Command, Handler, or full domain scaffold
- **Component name** — what the component represents (e.g., `CreateProduct`, `Product`, `OrderItems`)

### 2. Generate the code

Use the templates in `templates/` as your starting point. Adapt them to the user's specific domain.

Key naming conventions:
- Actions: `{Verb}{Subject}Action` (e.g., `CreateProductAction`, `SendOrderNotificationAction`)
- DTOs: `{Subject}Data` or `{Subject}DTO` (e.g., `ProductData`, `CreateOrderDTO`)
- Repository interfaces: `{Subject}Repository` placed in `domain/{Domain}/Repositories/`
- Repository implementations: `Eloquent{Subject}Repository` placed in `infrastructure/{Domain}/Repositories/`
- Domain models: plain class in `domain/{Domain}/Models/` — NOT extending Eloquent
- Eloquent models: placed in `infrastructure/{Domain}/Models/` — extends `Illuminate\Database\Eloquent\Model`
- QueryBuilders: `{Subject}QueryBuilder` extending `Illuminate\Database\Eloquent\Builder`
- Collections: `{Subject}Collection` extending `Illuminate\Database\Eloquent\Collection`

### 3. Wire up in Laravel

After generating components, help the user:
1. **Bind repository interfaces** in a ServiceProvider (typically `AppServiceProvider` or a dedicated `DomainServiceProvider`)
2. **Register the domain's Eloquent model** to use the custom QueryBuilder/Collection if applicable
3. **Register autoloading** — add `domain/` and `infrastructure/` to `composer.json` PSR-4 autoload if not present:
   ```json
   "autoload": {
     "psr-4": {
       "App\\": "app/",
       "Domain\\": "domain/",
       "Infrastructure\\": "infrastructure/",
       "Support\\": "support/"
     }
   }
   ```
   Then run: `composer dump-autoload`

## Workflow: Full Domain Scaffold

When the user wants to scaffold an entire new domain (e.g., "set up a Products domain"), generate all of these:

1. `domain/{Domain}/Actions/` (directory, plus a placeholder example Action)
2. `domain/{Domain}/DTOs/{Domain}Data.php`
3. `domain/{Domain}/Models/{Singular}.php` (domain entity)
4. `domain/{Domain}/Repositories/{Singular}Repository.php` (interface)
5. `domain/{Domain}/QueryBuilders/{Singular}QueryBuilder.php`
6. `domain/{Domain}/Collections/{Singular}Collection.php`
7. `infrastructure/{Domain}/Models/{Singular}.php` (Eloquent model using the QueryBuilder/Collection)
8. `infrastructure/{Domain}/Repositories/Eloquent{Singular}Repository.php`
9. A ServiceProvider binding entry (show the user what to add)

## Workflow: Refactoring from MVC

When the user wants to refactor an existing MVC project:

1. **Keep `app/` untouched** for now — Controllers, Models stay where they are
2. **Create the `domain/` directory** and start extracting business logic from fat Controllers/Services into Actions
3. **Introduce DTOs** to replace raw `$request->validated()` arrays at the boundary
4. Move **query logic** out of Controllers/Services into QueryBuilders or Repository interfaces
5. Graduate to full repository separation only when the domain logic justifies it

The key insight: you don't have to refactor everything at once. Start with Actions for new features, and
gradually extract existing logic as you touch it.

## Design Principles to Enforce

When reviewing or writing code for this architecture:

- **Actions are the heart** — each Action class has exactly one `handle()` method doing exactly one business task
- **Domain layer is framework-agnostic** — no Eloquent, no HTTP Request objects, no `app()` or Laravel facades in `domain/`
- **Repository interface lives in Domain, implementation lives in Infrastructure** — the domain defines the contract, infrastructure fulfills it
- **DTOs replace arrays** — any time data crosses a layer boundary, use a typed DTO, not a plain array
- **Composition over Inheritance** — wire up via DI; avoid deeply nested class hierarchies
- **Don't over-engineer small projects** — if the domain is simple, use CustomQueryBuilders and skip the Repository abstraction entirely

## Running Quality Checks

After generating code, run the quality scripts:

```bash
# Check code quality (PHPStan + Pint)
bash scripts/check_quality.sh

# Run tests
bash scripts/run_tests.sh

# Run a single test
php artisan test --filter=TestClassName
```

See `scripts/` for the full scripts.
