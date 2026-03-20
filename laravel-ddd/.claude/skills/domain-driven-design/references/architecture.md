# Architecture Reference

This document explains the Domain Oriented Design layers and patterns in detail.

## Table of Contents
1. [Layer Overview](#layer-overview)
2. [Application Layer](#application-layer)
3. [Domain Layer](#domain-layer)
4. [Infrastructure Layer](#infrastructure-layer)
5. [Support Layer](#support-layer)
6. [Pattern Details](#pattern-details)
7. [CommandBus Pattern](#commandbus-pattern)
8. [Binding Repositories in Laravel](#binding-repositories-in-laravel)

---

## Layer Overview

| Layer | Directory | Depends On | Purpose |
|---|---|---|---|
| Application | `app/` | Domain, Support | HTTP controllers, console commands, jobs |
| Domain | `domain/` | Support only | Business logic — framework-agnostic |
| Infrastructure | `infrastructure/` | Domain, Support | DB, external APIs, framework glue |
| Support | `support/` | Nothing | Shared helpers, value objects, third-party wrappers |

**The domain layer must never import from `app/` or `infrastructure/`.** It defines interfaces; infrastructure implements them.

---

## Application Layer (`app/`)

Standard Laravel MVC. Controllers are thin — they translate HTTP into domain language and back.

```php
// app/Http/Controllers/ProductController.php
class ProductController extends Controller
{
    public function store(CreateProductRequest $request, CreateProductAction $action): JsonResponse
    {
        $data = ProductData::fromRequest($request);
        $product = $action->handle($data);
        return response()->json(ProductResource::make($product));
    }
}
```

Controllers should:
- Validate input via Form Requests
- Convert validated data into a DTO
- Call an Action
- Return a response

Controllers should NOT contain business logic.

---

## Domain Layer (`domain/`)

The center of the application. Contains everything that expresses what the application *does*, completely independent of Laravel's infrastructure.

### Actions

One class, one business operation, one `handle()` method.

```php
// domain/Products/Actions/CreateProductAction.php
namespace Domain\Products\Actions;

use Domain\Products\DTOs\ProductData;
use Domain\Products\Models\Product;
use Domain\Products\Repositories\ProductRepository;

class CreateProductAction
{
    public function __construct(
        private readonly ProductRepository $productRepository,
        private readonly NotifyWarehouseAction $notifyWarehouse,
    ) {}

    public function handle(ProductData $data): Product
    {
        $product = Product::fromData($data);
        $this->productRepository->save($product);
        $this->notifyWarehouse->handle($product);
        event(new ProductCreated($product));
        return $product;
    }
}
```

Actions can call other Actions — compose small, focused operations into larger workflows.

### DTOs (Data Transfer Objects)

Replace arrays with typed objects. The DTO is the boundary contract — once data enters the domain as a DTO, you know exactly what it contains.

```php
// domain/Products/DTOs/ProductData.php
namespace Domain\Products\DTOs;

use App\Http\Requests\CreateProductRequest;

class ProductData
{
    public function __construct(
        public readonly string $title,
        public readonly string $categoryId,
        public readonly bool $active,
        public readonly ?string $description = null,
    ) {}

    public static function fromRequest(CreateProductRequest $request): self
    {
        return new self(
            title: $request->input('title'),
            categoryId: $request->input('category_id'),
            active: $request->boolean('active'),
            description: $request->input('description'),
        );
    }

    public static function fromArray(array $data): self
    {
        return new self(
            title: $data['title'],
            categoryId: $data['category_id'],
            active: (bool) ($data['active'] ?? false),
            description: $data['description'] ?? null,
        );
    }
}
```

The `fromRequest` / `fromArray` static constructors mean you can feed the same Action from HTTP requests, CLI imports, events, or tests — without changing the Action itself.

### Domain Models (Entities)

A plain PHP class representing a business object. NOT an Eloquent model — it doesn't know about the database.

```php
// domain/Products/Models/Product.php
namespace Domain\Products\Models;

use Domain\Products\DTOs\ProductData;

class Product
{
    public function __construct(
        public readonly ?int $id,
        public readonly string $title,
        public readonly string $categoryId,
        public readonly bool $active,
        public readonly ?string $description = null,
    ) {}

    public static function fromData(ProductData $data): self
    {
        return new self(
            id: null,
            title: $data->title,
            categoryId: $data->categoryId,
            active: $data->active,
            description: $data->description,
        );
    }

    public function activate(): self
    {
        return new self($this->id, $this->title, $this->categoryId, true, $this->description);
    }
}
```

**When to use domain entities vs. Eloquent models directly:**
- Simple projects: skip domain entities, use Eloquent models directly with QueryBuilders
- Complex domains with rich business rules: use domain entities to encapsulate logic cleanly

### Repository Interfaces

The domain defines what it needs; infrastructure provides it.

```php
// domain/Products/Repositories/ProductRepository.php
namespace Domain\Products\Repositories;

use Domain\Products\Models\Product;

interface ProductRepository
{
    public function findById(int $id): Product;
    public function save(Product $product): Product;
    public function delete(Product $product): void;
    /** @return Product[] */
    public function findActive(): array;
}
```

### QueryBuilders

When you don't need full repository abstraction, extend Eloquent's Builder to push query logic out of controllers and services.

```php
// domain/Products/QueryBuilders/ProductQueryBuilder.php
namespace Domain\Products\QueryBuilders;

use Illuminate\Database\Eloquent\Builder;

class ProductQueryBuilder extends Builder
{
    public function active(): self
    {
        return $this->where('is_active', true);
    }

    public function inCategory(int $categoryId): self
    {
        return $this->where('category_id', $categoryId);
    }

    public function search(string $term): self
    {
        return $this->where('title', 'like', "%{$term}%");
    }
}
```

Usage: `Product::query()->active()->inCategory(3)->get()`

### Collections

Extend Eloquent Collection with domain-specific filtering logic.

```php
// domain/Products/Collections/ProductCollection.php
namespace Domain\Products\Collections;

use Illuminate\Database\Eloquent\Collection;

class ProductCollection extends Collection
{
    public function active(): self
    {
        return $this->filter(fn ($product) => $product->is_active);
    }

    public function totalValue(): float
    {
        return $this->sum('price');
    }
}
```

---

## Infrastructure Layer (`infrastructure/`)

Implements the contracts defined in the domain. Contains Eloquent models and repository implementations.

### Eloquent Models

```php
// infrastructure/Products/Models/Product.php
namespace Infrastructure\Products\Models;

use Domain\Products\Collections\ProductCollection;
use Domain\Products\QueryBuilders\ProductQueryBuilder;
use Illuminate\Database\Eloquent\Model;

class Product extends Model
{
    protected $table = 'products';
    protected $fillable = ['title', 'category_id', 'is_active', 'description'];

    public function newEloquentBuilder($query): ProductQueryBuilder
    {
        return new ProductQueryBuilder($query);
    }

    public function newCollection(array $models = []): ProductCollection
    {
        return new ProductCollection($models);
    }
}
```

### Eloquent Repository Implementations

```php
// infrastructure/Products/Repositories/EloquentProductRepository.php
namespace Infrastructure\Products\Repositories;

use Domain\Products\Models\Product as DomainProduct;
use Domain\Products\Repositories\ProductRepository;
use Infrastructure\Products\Models\Product as EloquentProduct;

class EloquentProductRepository implements ProductRepository
{
    public function findById(int $id): DomainProduct
    {
        $model = EloquentProduct::findOrFail($id);
        return $this->toDomain($model);
    }

    public function save(DomainProduct $product): DomainProduct
    {
        $model = $product->id
            ? EloquentProduct::findOrFail($product->id)
            : new EloquentProduct();

        $model->fill([
            'title' => $product->title,
            'category_id' => $product->categoryId,
            'is_active' => $product->active,
            'description' => $product->description,
        ])->save();

        return $this->toDomain($model);
    }

    public function delete(DomainProduct $product): void
    {
        EloquentProduct::findOrFail($product->id)->delete();
    }

    public function findActive(): array
    {
        return EloquentProduct::query()->active()->get()
            ->map(fn ($m) => $this->toDomain($m))
            ->all();
    }

    private function toDomain(EloquentProduct $model): DomainProduct
    {
        return new DomainProduct(
            id: $model->id,
            title: $model->title,
            categoryId: $model->category_id,
            active: $model->is_active,
            description: $model->description,
        );
    }
}
```

---

## Support Layer (`support/`)

Shared utilities, value objects, and third-party integrations that don't belong to any specific domain.

Examples:
- `support/Money.php` — a value object for monetary amounts
- `support/Address.php` — a value object for addresses
- `support/Http/ApiClient.php` — a generic HTTP client wrapper

---

## Pattern Details

### When to use Repository vs. QueryBuilder

| Scenario | Use |
|---|---|
| Simple project, Eloquent is fine | QueryBuilder + Collection only |
| Need to mock DB in tests | Repository interface |
| Object maps to multiple DB tables | Repository interface |
| May switch DB implementation | Repository interface |
| Just need reusable query scopes | QueryBuilder |

### Composing Actions

Actions compose other Actions via constructor injection:

```php
class FulfillOrderAction
{
    public function __construct(
        private readonly ReserveInventoryAction $reserveInventory,
        private readonly ChargePaymentAction $chargePayment,
        private readonly SendConfirmationEmailAction $sendEmail,
    ) {}

    public function handle(Order $order): void
    {
        $this->reserveInventory->handle($order);
        $this->chargePayment->handle($order);
        $this->sendEmail->handle($order);
    }
}
```

### Dispatching Actions as Jobs

Because Actions are plain classes, wrapping them in a queued job is straightforward:

```php
class CreateProductJob implements ShouldQueue
{
    public function __construct(private readonly ProductData $data) {}

    public function handle(CreateProductAction $action): void
    {
        $action->handle($this->data);
    }
}
```

---

## CommandBus Pattern

For projects already using Services that are hard to refactor, CommandBus is a middle path. Instead of
refactoring existing Services, introduce Commands (DTOs) + Handlers (single-responsibility logic).

```
Request → CommandFactory → Command → Bus::dispatch() → Handler → Action
```

See SKILL.md templates section for full CommandBus example code.

---

## Binding Repositories in Laravel

Add bindings in a ServiceProvider:

```php
// app/Providers/DomainServiceProvider.php
namespace App\Providers;

use Domain\Products\Repositories\ProductRepository;
use Infrastructure\Products\Repositories\EloquentProductRepository;
use Illuminate\Support\ServiceProvider;

class DomainServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->bind(ProductRepository::class, EloquentProductRepository::class);
        // Add more bindings here as new domains are created
    }
}
```

Register in `config/app.php` (or `bootstrap/providers.php` in Laravel 11+):
```php
App\Providers\DomainServiceProvider::class,
```
