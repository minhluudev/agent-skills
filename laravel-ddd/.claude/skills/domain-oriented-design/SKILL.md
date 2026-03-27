---
name: domain-oriented-design
description: Domain Oriented Design (DOD) patterns and code generation for Laravel projects — business-first architecture based on Actions, DTOs, Entities, and Repositories. Simpler than DDD: no aggregates, no value objects. Use when building practical Laravel features with clean separation between business logic and infrastructure.
user-invocable: true
---

# Domain Oriented Design Code Generation

You are generating DOD (Domain Oriented Design) components for this Laravel project. The Laravel app lives in `laravel-app/` inside the project root.

> **DOD ≠ DDD.** Domain Oriented Design is a simpler, practical approach: put business logic (Actions, Entities, Repositories) at the center, keep the MVC layer as thin transport, and minimize coupling to infrastructure. No complex aggregates or value objects — just clean separation.

## Your Task

Parse the user's request to determine what to generate, then **create the actual files** using the Write tool. Do not just show code — write the files directly.

When the user says something like:
- "create action CreateProduct for Product domain with CreateProductDTO"
- "generate DTO RegisterUserDTO with fields name:string, email:string, password:string"
- "scaffold full feature for Order domain"
- "create entity Product with fields id:int, name:string, price:float"
- "create ViewModel ProductViewModel for Product domain"
- "create QueryBuilder ProductQueryBuilder"

— identify the domain, component type(s), names, and fields, then generate all required files.

## Project Structure

```
laravel-app/app/
├── Domain/
│   └── {Domain}/
│       ├── Actions/          → {ActionName}Action.php        [business use-cases]
│       ├── DTO/              → {DTOName}DTO.php              [typed data transfer]
│       ├── Entities/         → {EntityName}Entity.php        [POJO domain objects]
│       ├── Exceptions/       → {ExceptionName}Exception.php  [domain exceptions]
│       ├── QueryBuilders/    → {EntityName}QueryBuilder.php  [optional, replaces Repo for simple cases]
│       └── Repositories/     → {EntityName}Repository.php   [interface only]
├── Http/
│   ├── Controllers/Api/V{N}/{Domain}/  → {Name}Controller.php
│   ├── Requests/{Domain}/              → {Name}Request.php
│   ├── Resources/{Domain}/             → {Name}Resource.php
│   └── ViewModels/{Domain}/            → {Name}ViewModel.php [optional, prepares view/API data]
├── Infrastructures/
│   ├── Models/               → {EntityName}.php              [Eloquent model]
│   └── Repositories/         → {EntityName}RepositoryEloquent.php
└── Providers/
    └── RepositoryServiceProvider.php   ← update when adding repositories
```

---

## Quick Start

When implementing a new feature (e.g., Product):

1. **Create DTO** — define input data structure in `Domain/{Domain}/DTO/`
2. **Create Entity** — plain PHP object representing the business concept
3. **Create Repository Interface** — declare contract in `Domain/{Domain}/Repositories/`
4. **Create Action** — implement use-case logic, inject Repository interface
5. **Implement Repository** — Eloquent implementation in `Infrastructures/Repositories/`
6. **Create Eloquent Model** — in `Infrastructures/Models/`
7. **Create Form Request** — validation + `toDTO()` in `Http/Requests/{Domain}/`
8. **Create Resource** — response formatting in `Http/Resources/{Domain}/`
9. **Create Controller** — thin transport, delegates to Action
10. **Bind interface** — update `RepositoryServiceProvider`
11. **Define Routes** — API routes

---

## Exact Code Patterns

> **Note:** Templates are in `.claude/skills/domain-oriented-design/templates/`. Reference them when writing files.

### Action
Actions = Use Cases. One class, one business operation, `handle()` method.
```php
<?php
declare(strict_types=1);

namespace App\Domain\{Domain}\Actions;

use App\Domain\{Domain}\DTO\{DTOName}DTO;
use App\Domain\{Domain}\Repositories\{EntityName}Repository;
use Exception;
use Symfony\Component\HttpFoundation\Response;

class {ActionName}Action
{
    public function __construct(
        protected {EntityName}Repository ${entityNameCamel}Repository,
    ) {}

    public function handle({DTOName}DTO ${dtoNameCamel}DTO): mixed
    {
        // TODO: implement business logic
        throw new Exception('Not implemented', Response::HTTP_NOT_IMPLEMENTED);
    }
}
```

### DTO (Data Transfer Object)
Typed objects to replace raw arrays. PHP 8.1 readonly constructor promotion. No business logic.
```php
<?php
declare(strict_types=1);

namespace App\Domain\{Domain}\DTO;

class {DTOName}DTO
{
    public function __construct(
        public readonly string $field1,
        public readonly string $field2,
    ) {}

    public static function fromRequest(array $data): self
    {
        return new self(
            field1: $data['field1'],
            field2: $data['field2'],
        );
    }

    public function toArray(): array
    {
        return [
            'field1' => $this->field1,
            'field2' => $this->field2,
        ];
    }
}
```

### Entity (Domain Model / POJO)
Plain PHP Objects representing business concepts. **No extends, no Framework dependency.**
PHP 8.1 readonly constructor promotion. Identified by ID. Completely separate from Eloquent models.
```php
<?php
declare(strict_types=1);

namespace App\Domain\{Domain}\Entities;

class {EntityName}Entity
{
    public function __construct(
        private readonly int $id,
        private readonly string $name,
    ) {}

    public function getId(): int { return $this->id; }
    public function getName(): string { return $this->name; }

    public function toArray(): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
        ];
    }
}
```

### Repository Interface
Domain layer declares the contract. Completely unaware of Eloquent or any database.
```php
<?php
declare(strict_types=1);

namespace App\Domain\{Domain}\Repositories;

use Prettus\Repository\Contracts\RepositoryInterface;

interface {EntityName}Repository extends RepositoryInterface
{
    // declare custom business-specific methods here
    // Example: public function findBySlug(string $slug): ?array;
}
```

### Repository Eloquent Implementation
Infrastructure layer fulfills the contract using Eloquent.
```php
<?php
declare(strict_types=1);

namespace App\Infrastructures\Repositories;

use App\Domain\{Domain}\Repositories\{EntityName}Repository;
use App\Infrastructures\Models\{EntityName};
use Prettus\Repository\Criteria\RequestCriteria;
use Prettus\Repository\Eloquent\BaseRepository;

class {EntityName}RepositoryEloquent extends BaseRepository implements {EntityName}Repository
{
    public function model(): string
    {
        return {EntityName}::class;
    }

    public function boot(): void
    {
        $this->pushCriteria(app(RequestCriteria::class));
    }
}
```

### Eloquent Model
Infrastructure-level model. Keep in `Infrastructures/Models/`. Optionally bind a custom QueryBuilder.
```php
<?php
declare(strict_types=1);

namespace App\Infrastructures\Models;

use Illuminate\Database\Eloquent\Model;

class {EntityName} extends Model
{
    protected $table = '{table_name}';

    protected $fillable = [
        // add fillable fields here
    ];

    // Uncomment when using a custom QueryBuilder:
    // public function newEloquentBuilder($query): \App\Domain\{Domain}\QueryBuilders\{EntityName}QueryBuilder
    // {
    //     return new \App\Domain\{Domain}\QueryBuilders\{EntityName}QueryBuilder($query);
    // }
}
```

### Domain Exception
Business-level exceptions with meaningful names.
```php
<?php
declare(strict_types=1);

namespace App\Domain\{Domain}\Exceptions;

use Exception;
use Symfony\Component\HttpFoundation\Response;

class {ExceptionName}Exception extends Exception
{
    public function __construct(string $message = '', int $code = Response::HTTP_UNPROCESSABLE_ENTITY)
    {
        parent::__construct($message ?: $this->defaultMessage(), $code);
    }

    private function defaultMessage(): string
    {
        return '{ExceptionName} error occurred.';
    }
}
```

### Custom Query Builder (optional — use instead of Repository for simple cases)
Extends Eloquent Builder. Keep in Domain layer. Attach to Eloquent Model via `newEloquentBuilder()`.
```php
<?php
declare(strict_types=1);

namespace App\Domain\{Domain}\QueryBuilders;

use Illuminate\Database\Eloquent\Builder;

class {EntityName}QueryBuilder extends Builder
{
    public function active(): self
    {
        return $this->where('is_active', true);
    }

    // add domain-specific query methods here
}
```

Eloquent Model binds the QueryBuilder:
```php
// In app/Infrastructures/Models/{EntityName}.php
public function newEloquentBuilder($query): {EntityName}QueryBuilder
{
    return new \App\Domain\{Domain}\QueryBuilders\{EntityName}QueryBuilder($query);
}
```

### ViewModel (optional — for preparing complex view/API data)
Encapsulates all data needed by a view or API response. Use DI for flexibility and testability.
```php
<?php
declare(strict_types=1);

namespace App\Http\ViewModels\{Domain};

use App\Infrastructures\Models\{EntityName};
use Illuminate\Support\Collection;

class {Name}ViewModel
{
    public function __construct(
        private ?{EntityName} ${entityNameCamel} = null,
    ) {}

    public function {entityNameCamel}(): {EntityName}
    {
        return $this->{entityNameCamel} ?? new {EntityName}();
    }

    public function relatedData(): Collection
    {
        return collect(); // TODO: load related data
    }
}
```

### Form Request (with toDTO)
```php
<?php
declare(strict_types=1);

namespace App\Http\Requests\{Domain};

use App\Domain\{Domain}\DTO\{DTOName}DTO;
use Illuminate\Foundation\Http\FormRequest;

class {RequestName}Request extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'field1' => 'required|string',
        ];
    }

    public function toDTO(): {DTOName}DTO
    {
        return {DTOName}DTO::fromRequest($this->validated());
    }
}
```

### Controller
Thin transport layer. Delegate business logic entirely to Action.
```php
<?php
declare(strict_types=1);

namespace App\Http\Controllers\Api\V{N}\{Domain};

use App\Domain\{Domain}\Actions\{ActionName}Action;
use App\Http\Controllers\Api\Controller;
use App\Http\Requests\{Domain}\{RequestName}Request;
use App\Http\Resources\{Domain}\{ResourceName}Resource;
use Exception;
use Illuminate\Http\JsonResponse;

class {ControllerName}Controller extends Controller
{
    public function handle({RequestName}Request $request, {ActionName}Action $action): JsonResponse
    {
        try {
            $result = $action->handle($request->toDTO());
            return $this->sendResponse({ResourceName}Resource::make($result));
        } catch (Exception $e) {
            return $this->sendError($e->getMessage(), $e->getCode());
        }
    }
}
```

### API Resource
```php
<?php
declare(strict_types=1);

namespace App\Http\Resources\{Domain};

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class {ResourceName}Resource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return $this->resource;
    }
}
```

### RepositoryServiceProvider binding
After adding a new repository, update `laravel-app/app/Providers/RepositoryServiceProvider.php`:
```php
protected array $repositories = [
    UserRepository::class => UserRepositoryEloquent::class,
    {EntityName}Repository::class => {EntityName}RepositoryEloquent::class,  // add this
];
```

---

## Generation Rules

1. **Always read existing files first** before modifying them (e.g., RepositoryServiceProvider).
2. **Derive names automatically**:
   - `entityNameCamel` = lcfirst of EntityName (`Product` → `product`)
   - `dtoNameCamel` = lcfirst of DTOName (`CreateProductDTO` → `createProductDTO`)
3. **Actions use `handle()`**, not `__invoke()` or `execute()`.
4. **Entities are POJO** — no `extends Model`, no Framework dependency.
5. **No Eloquent in Domain layer** — Actions use Repository interfaces or QueryBuilders, never Eloquent models directly.
6. **Validation belongs in Form Requests**, not DTOs or Entities.
7. **Use PHP 8.1+ readonly constructor promotion** for DTO and Entity properties.
8. **When to use Repository vs QueryBuilder**:
   - Use **Repository** when: multiple database sources possible, complex domain isolation needed, large teams.
   - Use **QueryBuilder** when: simple project, single database, want to avoid boilerplate Repository.
9. **For a full feature scaffold**, generate: DTO → Entity → Repository interface → RepositoryEloquent → EloquentModel → Action → Request → Resource → Controller, then update RepositoryServiceProvider.
10. **For partial requests**, generate only what was asked.
11. **After generating files**, summarize what was created with file paths.

---

## When to Use DOD

- **Practical Laravel apps** — needs clean architecture without DDD complexity
- **Medium-size teams** — clear separation helps parallel development
- **CRUD-heavy with business logic** — pure MVC gets messy, DDD is overkill
- **Evolving requirements** — Actions are easy to add/modify independently

## When to Avoid DOD

- **Simple CRUD apps** — plain Laravel MVC is sufficient, DOD adds overhead
- **Prototypes / MVPs** — speed matters more than structure
- **Pure DDD projects** — use the `domain-driven-design` skill instead

---

## Key Principles

1. **Single Responsibility** — Each Action handles one and only one business operation
2. **Dependency Injection** — Inject dependencies via constructor; composition over inheritance
3. **No Eloquent in Domain** — Domain layer never imports Eloquent directly
4. **Typed Data** — Use DTO instead of raw arrays; IDE-friendly, type-safe, readable
5. **Validation in Requests** — Never validate inside DTO or Entity
6. **Actions describe User Stories** — The list of Actions is the feature list of the system

---

## Common Pitfalls

- ❌ Business logic in Controllers — Controllers are transport only
- ❌ Eloquent models in Domain layer — use Repository interface or QueryBuilder
- ❌ Raw arrays instead of DTOs — lose type safety and IDE support
- ❌ Fat Actions calling other Actions directly — inject the secondary Action via constructor
- ❌ Validation in DTO or Entity — always validate in Form Request
- ❌ Skipping Repository interface — breaks testability and swappability

## Benefits

- ✅ **Readability** — Actions tell the story of the application
- ✅ **Testability** — Domain layer has no framework dependency
- ✅ **Flexibility** — Swap infrastructure without touching business logic
- ✅ **Maintainability** — Clear boundaries, one class per use-case
- ✅ **Onboarding** — Simpler than DDD; team ramp-up is fast
