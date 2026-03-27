---
name: domain-driven-design
description: Guide for implementing Domain-Driven Design (DDD) in Laravel applications. Use when building complex Laravel applications with tactical DDD patterns (Entities, Value Objects, Aggregates, Domain Services, Domain Events, Repositories), organizing code with strategic DDD (Bounded Contexts, Ubiquitous Language), implementing Use Cases, or when asked to apply DDD/clean architecture with rich domain models.
user-invocable: false
---

# Domain-Driven Design for Laravel

Domain-Driven Design (DDD) is a powerful approach to software development that aligns your application's architecture with the complexities of your business domain. By focusing on the core domain logic and isolating it from infrastructure concerns, DDD ensures that your codebase remains modular, maintainable, and closely tied to business needs.

**Architecture:**

```
app/
├── Domain/
│   ├── Order/
│   │   ├── Entities/
│   │   ├── ValueObjects/
│   │   ├── Aggregates/
│   │   ├── Repositories/
│   │   ├── Services/
│   │   ├── Events/
│   │   └── Exceptions/
│   │
│   ├── User/
│   └── Payment/
│
├── Application/
│   ├── Order/
│   │   ├── Commands/
│   │   ├── Queries/
│   │   ├── DTOs/
│   │   └── UseCases/
│   │
│   ├── User/
│   └── Payment/
│
├── Infrastructure/
│   ├── Persistence/
│   │   └── Eloquent/
│   │       ├── Models/
│   │       └── Repositories/
│   │
│   ├── Services/
│   │   ├── PaymentGateway/
│   │   └── Email/
│   │
│   └── Providers/
│
├── Interfaces/
│   ├── Http/
│   │   ├── Controllers/
│   │   ├── Requests/
│   │   └── Resources/
│   │
│   ├── Console/
│   └── Jobs/
│
└── Shared/
    ├── Kernel/
    ├── ValueObjects/
    └── Helpers/
```

**See [references/infrastructure.md](references/infrastructure.md) for detailed layer guidance.**

## Setup

### Step 1: Configure Composer Autoloading

All layers live under `app/`, so the default Laravel autoloading already covers them. No changes needed — `App\` maps to `app/` out of the box.

```json
"autoload": {
    "psr-4": {
        "App\\": "app/"
    }
}
```

Run `composer dump-autoload` after any namespace changes.

### Step 2: Create Directory Structure

Use the scaffold script or manually create (run from the Laravel app root):

```bash
# Run from laravel-app/ (the directory containing app/)
cd laravel-app
../.claude/skills/domain-driven-design/scripts/scaffold_context.sh Contact
```

## Quick Start

When implementing a new feature (e.g., Order):

1. **Create Entity / Aggregate** - Define core business object with identity
2. **Create Value Objects** - Immutable domain concepts (e.g., Money, OrderStatus)
3. **Create Domain Service** - Complex business logic spanning multiple entities
4. **Define Repository Interface** - In `app/Domain/{Context}/Repositories/`
5. **Create Command or Query** - In `app/Application/{Context}/Commands/` or `Queries/`
6. **Create DTO** - In `app/Application/{Context}/DTOs/`
7. **Create UseCase** - In `app/Application/{Context}/UseCases/` — orchestrates domain objects
8. **Implement Repository** - In `app/Infrastructure/Persistence/Eloquent/Repositories/`
9. **Create Eloquent Model** - In `app/Infrastructure/Persistence/Eloquent/Models/`
10. **Create Controller** - In `app/Interfaces/Http/Controllers/`, delegates to UseCase
11. **Create Form Request** - In `app/Interfaces/Http/Requests/`
12. **Create Resource** - In `app/Interfaces/Http/Resources/`
13. **Bind Interface** - In `app/Infrastructure/Providers/`
14. **Define Routes** - API or web routes

## Core DDD Concepts

### Strategic Patterns

Strategic DDD focuses on organizing large systems into manageable bounded contexts:

- **Bounded Contexts** - See [references/bounded-contexts.md](references/bounded-contexts.md)
  - Define clear boundaries around domain models
  - Each context has its own ubiquitous language
  - Contexts are autonomous and independently deployable
  - Example: Contact Management, Sales, Billing contexts in CRM

- **Context Mapping** - See [references/context-mapping.md](references/context-mapping.md)
  - Define relationships between contexts
  - Patterns: Partnership, Shared Kernel, Customer-Supplier, ACL
  - Visualize context dependencies
  - Example: Sales (downstream) depends on Contact Management (upstream)

- **Integration Patterns** - See [references/integration-patterns.md](references/integration-patterns.md)
  - Event-driven integration (recommended)
  - REST API integration
  - Message queues for async communication
  - Example: ContactCreated event triggers billing setup

- **Anti-Corruption Layer** - See [references/anti-corruption-layer.md](references/anti-corruption-layer.md)
  - Protect domain from external systems
  - Translate external models to domain models
  - Adapter and Translator patterns
  - Example: Translating third-party API to internal Contact entity

- **Aggregates** - See [references/aggregates.md](references/aggregates.md)
  - Define transactional boundaries
  - Aggregate roots control access
  - Reference aggregates by ID
  - Example: Contact aggregate containing ContactInfo and Preferences

### Tactical Patterns

- **Entities** - See [references/entities.md](references/entities.md)
  - Objects with unique identity
  - Contain business logic and state
  - Example: Contact, Interaction

- **Value Objects** - See [references/value-objects.md](references/value-objects.md) (Optional)
  - Immutable objects without identity
  - Equality based on attributes
  - Example: Email, PhoneNumber, Money

- **Domain Services** - See [references/domain-services.md](references/domain-services.md)
  - Stateless operations
  - Complex logic spanning multiple entities
  - Example: ContactService, PricingService

- **Repositories** - See [references/repositories.md](references/repositories.md)
  - Interface in Domain, implementation in Infrastructure
  - Abstraction for data persistence
  - Collection-oriented API

- **Domain Events** - See [references/domain-events.md](references/domain-events.md) (Optional)
  - Record significant occurrences
  - Enable decoupling between domains
  - Example: ContactCreated, ContactStatusChanged

### Application Patterns

- **Commands & Queries (CQRS)** - See [references/use-cases.md](references/use-cases.md)
  - **Commands** — intent to change state (e.g., `PlaceOrderCommand`)
  - **Queries** — read-only data retrieval (e.g., `GetOrderQuery`)
  - **UseCases** — execute one Command or Query, orchestrate domain objects
  - Return DTOs (not entities)

- **DTOs** - See [references/dtos.md](references/dtos.md)
  - Transfer data between layers
  - Input DTOs for Commands/Queries
  - Output DTOs for responses (returned from UseCases to Controllers)

### Infrastructure

- **Infrastructure Layer** - See [references/infrastructure.md](references/infrastructure.md)
  - Controllers, Eloquent models
  - Repository implementations
  - Service providers

## Complete Example: Order Management

Based on an e-commerce system with Order domain.

### 1. Entity (Domain)

```php
// app/Domain/Order/Entities/Order.php
namespace App\Domain\Order\Entities;

use App\Domain\Order\ValueObjects\OrderStatus;
use App\Domain\Order\Events\OrderPlaced;

class Order
{
    private array $domainEvents = [];

    public function __construct(
        private readonly string $id,
        private readonly string $userId,
        private int $totalAmount,
        private OrderStatus $status,
    ) {}

    public static function place(string $id, string $userId, int $totalAmount): self
    {
        $order = new self($id, $userId, $totalAmount, OrderStatus::pending());
        $order->domainEvents[] = new OrderPlaced($id, $userId, $totalAmount);
        return $order;
    }

    public function confirm(): void
    {
        $this->status = OrderStatus::confirmed();
    }

    public function getId(): string { return $this->id; }
    public function getUserId(): string { return $this->userId; }
    public function getTotalAmount(): int { return $this->totalAmount; }
    public function getStatus(): OrderStatus { return $this->status; }
    public function pullDomainEvents(): array
    {
        $events = $this->domainEvents;
        $this->domainEvents = [];
        return $events;
    }
}
```

### 2. Value Object (Domain)

```php
// app/Domain/Order/ValueObjects/OrderStatus.php
namespace App\Domain\Order\ValueObjects;

class OrderStatus
{
    private function __construct(private readonly string $value) {}

    public static function pending(): self { return new self('pending'); }
    public static function confirmed(): self { return new self('confirmed'); }

    public function getValue(): string { return $this->value; }
    public function equals(self $other): bool { return $this->value === $other->value; }
}
```

### 3. Repository Interface (Domain)

```php
// app/Domain/Order/Repositories/OrderRepositoryInterface.php
namespace App\Domain\Order\Repositories;

use App\Domain\Order\Entities\Order;

interface OrderRepositoryInterface
{
    public function save(Order $order): void;
    public function findById(string $id): ?Order;
}
```

### 4. Command + DTO (Application)

```php
// app/Application/Order/Commands/PlaceOrderCommand.php
namespace App\Application\Order\Commands;

class PlaceOrderCommand
{
    public function __construct(
        public readonly string $userId,
        public readonly int $totalAmount,
    ) {}
}
```

```php
// app/Application/Order/DTOs/OrderDTO.php
namespace App\Application\Order\DTOs;

use App\Domain\Order\Entities\Order;

class OrderDTO
{
    public function __construct(
        public readonly string $id,
        public readonly string $userId,
        public readonly int $totalAmount,
        public readonly string $status,
    ) {}

    public static function fromEntity(Order $order): self
    {
        return new self(
            $order->getId(),
            $order->getUserId(),
            $order->getTotalAmount(),
            $order->getStatus()->getValue(),
        );
    }
}
```

### 5. UseCase (Application)

```php
// app/Application/Order/UseCases/PlaceOrderUseCase.php
namespace App\Application\Order\UseCases;

use App\Application\Order\Commands\PlaceOrderCommand;
use App\Application\Order\DTOs\OrderDTO;
use App\Domain\Order\Entities\Order;
use App\Domain\Order\Repositories\OrderRepositoryInterface;
use Illuminate\Contracts\Events\Dispatcher;
use Ramsey\Uuid\Uuid;

class PlaceOrderUseCase
{
    public function __construct(
        private readonly OrderRepositoryInterface $orders,
        private readonly Dispatcher $events,
    ) {}

    public function execute(PlaceOrderCommand $command): OrderDTO
    {
        $order = Order::place(
            Uuid::uuid4()->toString(),
            $command->userId,
            $command->totalAmount,
        );

        $this->orders->save($order);

        foreach ($order->pullDomainEvents() as $event) {
            $this->events->dispatch($event);
        }

        return OrderDTO::fromEntity($order);
    }
}
```

### 6. Eloquent Model (Infrastructure)

```php
// app/Infrastructure/Persistence/Eloquent/Models/OrderModel.php
namespace App\Infrastructure\Persistence\Eloquent\Models;

use Illuminate\Database\Eloquent\Model;

class OrderModel extends Model
{
    protected $table = 'orders';
    protected $fillable = ['id', 'user_id', 'total_amount', 'status'];
    public $incrementing = false;
    protected $keyType = 'string';
}
```

### 7. Repository Implementation (Infrastructure)

```php
// app/Infrastructure/Persistence/Eloquent/Repositories/EloquentOrderRepository.php
namespace App\Infrastructure\Persistence\Eloquent\Repositories;

use App\Domain\Order\Entities\Order;
use App\Domain\Order\Repositories\OrderRepositoryInterface;
use App\Domain\Order\ValueObjects\OrderStatus;
use App\Infrastructure\Persistence\Eloquent\Models\OrderModel;

class EloquentOrderRepository implements OrderRepositoryInterface
{
    public function save(Order $order): void
    {
        OrderModel::updateOrCreate(
            ['id' => $order->getId()],
            [
                'user_id'      => $order->getUserId(),
                'total_amount' => $order->getTotalAmount(),
                'status'       => $order->getStatus()->getValue(),
            ]
        );
    }

    public function findById(string $id): ?Order
    {
        $model = OrderModel::find($id);
        if (!$model) return null;

        return Order::reconstitute(
            $model->id,
            $model->user_id,
            $model->total_amount,
            OrderStatus::fromString($model->status),
        );
    }
}
```

### 8. Controller (Interfaces)

```php
// app/Interfaces/Http/Controllers/OrderController.php
namespace App\Interfaces\Http\Controllers;

use App\Application\Order\Commands\PlaceOrderCommand;
use App\Application\Order\UseCases\PlaceOrderUseCase;
use App\Interfaces\Http\Requests\PlaceOrderRequest;
use App\Interfaces\Http\Resources\OrderResource;
use Illuminate\Http\JsonResponse;

class OrderController extends Controller
{
    public function __construct(
        private readonly PlaceOrderUseCase $useCase,
    ) {}

    public function store(PlaceOrderRequest $request): JsonResponse
    {
        $command = new PlaceOrderCommand(
            userId: $request->user()->id,
            totalAmount: $request->validated('total_amount'),
        );

        $dto = $this->useCase->execute($command);

        return (new OrderResource($dto))->response()->setStatusCode(201);
    }
}
```

### 9. Form Request + Resource (Interfaces)

```php
// app/Interfaces/Http/Requests/PlaceOrderRequest.php
namespace App\Interfaces\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class PlaceOrderRequest extends FormRequest
{
    public function authorize(): bool { return true; }

    public function rules(): array
    {
        return [
            'total_amount' => ['required', 'integer', 'min:1'],
        ];
    }
}
```

```php
// app/Interfaces/Http/Resources/OrderResource.php
namespace App\Interfaces\Http\Resources;

use App\Application\Order\DTOs\OrderDTO;
use Illuminate\Http\Resources\Json\JsonResource;

class OrderResource extends JsonResource
{
    public function toArray($request): array
    {
        /** @var OrderDTO $dto */
        $dto = $this->resource;
        return [
            'id'           => $dto->id,
            'user_id'      => $dto->userId,
            'total_amount' => $dto->totalAmount,
            'status'       => $dto->status,
        ];
    }
}
```

### 10. Service Provider (Infrastructure)

```php
// app/Infrastructure/Providers/DomainServiceProvider.php
namespace App\Infrastructure\Providers;

use Illuminate\Support\ServiceProvider;
use App\Domain\Order\Repositories\OrderRepositoryInterface;
use App\Infrastructure\Persistence\Eloquent\Repositories\EloquentOrderRepository;

class DomainServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->bind(OrderRepositoryInterface::class, EloquentOrderRepository::class);
    }
}
```

Register in `bootstrap/providers.php` (Laravel 11):

```php
return [
    App\Providers\AppServiceProvider::class,
    App\Infrastructure\Providers\DomainServiceProvider::class,
];
```

### 11. Routes

```php
// routes/api.php
use App\Interfaces\Http\Controllers\OrderController;

Route::post('/orders', [OrderController::class, 'store']);
```

## Multi-Context Example: CRM System

This example shows three bounded contexts working together with event-driven integration and API gateways.

### Bounded Contexts

1. **Contact Management Context**
   - Manages customer/contact information
   - Owns: Contact entity, ContactStatus value object
   - Publishes: ContactCreated, ContactUpdated events

2. **Sales Context**
   - Manages sales opportunities and pipeline
   - Depends on Contact context for customer info
   - Owns: Opportunity entity, Pipeline value object

3. **Billing Context**
   - Manages invoices and payments
   - Depends on Contact and Sales contexts
   - Owns: Invoice entity, Payment value object

### Context Map

```
Contact Management (Upstream)
    |
    | ContactCreated event
    | ContactGateway API
    |
    v
Sales (Downstream - Customer/Supplier)
    |
    | OpportunityClosed event
    |
    v
Billing (Downstream - Conformist)
```

### Integration Example

**Contact context publishes event:**

```php
// Domain/Contact/Events/ContactCreated.php
namespace Domain\Contact\Events;

class ContactCreated
{
    public function __construct(
        public readonly string $contactId,
        public readonly string $name,
        public readonly string $email
    ) {}
}
```

**Sales context listens to event:**

```php
// TECHNICAL: Infrastructure/Listeners/CreateOpportunityWhenContactCreated.php
// MODULAR: Infrastructure/Sales/Listeners/CreateOpportunityWhenContactCreated.php
namespace Infrastructure\Listeners; // Technical
// namespace Infrastructure\Sales\Listeners; // Modular

use Domain\Contact\Events\ContactCreated;
use Application\Sales\UseCases\CreateOpportunityUseCase;
use Application\Sales\DTOs\CreateOpportunityDTO;

class CreateOpportunityWhenContactCreated
{
    public function __construct(
        private readonly CreateOpportunityUseCase $createOpportunity
    ) {}

    public function handle(ContactCreated $event): void
    {
        // Automatically create sales opportunity for new contact
        $this->createOpportunity->execute(
            new CreateOpportunityDTO(
                contactId: $event->contactId,
                name: "New opportunity for {$event->name}"
            )
        );
    }
}
```

**Sales context uses Anti-Corruption Layer to fetch contact details:**

```php
// TECHNICAL: Infrastructure/Integration/Contact/ContactGateway.php
// MODULAR: Infrastructure/Sales/Integration/Contact/ContactGateway.php
namespace Infrastructure\Integration\Contact; // Technical
// namespace Infrastructure\Sales\Integration\Contact; // Modular

use Illuminate\Support\Facades\Http;

class ContactGateway
{
    public function __construct(
        private readonly string $contactApiUrl
    ) {}

    public function getContact(string $contactId): ?array
    {
        $response = Http::get("{$this->contactApiUrl}/api/contacts/{$contactId}");

        if ($response->failed()) {
            return null;
        }

        return $response->json();
    }
}

// TECHNICAL: Infrastructure/Integration/Contact/ContactTranslator.php
// MODULAR: Infrastructure/Sales/Integration/Contact/ContactTranslator.php
namespace Infrastructure\Integration\Contact; // Technical
// namespace Infrastructure\Sales\Integration\Contact; // Modular

use Domain\Sales\ValueObjects\SalesContact;

class ContactTranslator
{
    public function __construct(
        private readonly ContactGateway $gateway
    ) {}

    public function translate(string $contactId): ?SalesContact
    {
        $rawContact = $this->gateway->getContact($contactId);

        if (!$rawContact) {
            return null;
        }

        // Translate external format to Sales context format
        return new SalesContact(
            contactId: $rawContact['id'],
            displayName: $rawContact['name'],
            email: $rawContact['email']
        );
    }
}
```

**This shows:**
- Event-driven integration between Contact and Sales
- API gateway for synchronous data access
- Anti-corruption layer protecting Sales context from Contact context changes

## Layer Responsibilities

### Domain Layer (`app/Domain/`)
- **Pure business logic**
- No framework dependencies
- Entities, Aggregates, Value Objects, Domain Services, Repository interfaces, Domain Events, Exceptions
- Independent and testable

### Application Layer (`app/Application/`)
- **Orchestration via CQRS**
- Commands (write intent) + Queries (read intent) + UseCases
- DTOs for input/output — UseCases return DTOs, never entities
- No business logic

### Infrastructure Layer (`app/Infrastructure/`)
- **Technical implementation**
- `Persistence/Eloquent/Models/` — Eloquent models (separate from domain entities)
- `Persistence/Eloquent/Repositories/` — Repository implementations
- `Services/PaymentGateway/`, `Services/Email/` — external service adapters
- `Providers/` — service providers binding interfaces to implementations

### Interfaces Layer (`app/Interfaces/`)
- **Entry points to the application**
- `Http/Controllers/` — thin controllers, delegate to UseCases
- `Http/Requests/` — form request validation
- `Http/Resources/` — API response transformation
- `Console/` — Artisan commands
- `Jobs/` — queued jobs

### Shared Layer (`app/Shared/`)
- **Cross-cutting concerns**
- `Kernel/` — base classes, contracts used across all layers
- `ValueObjects/` — value objects reused across multiple domains
- `Helpers/` — pure utility functions

## Advantages

- **Separation of Concerns** - Business logic isolated from infrastructure
- **Scalability** - Modular structure enables independent scaling
- **Reusability** - Domain logic reusable across interfaces
- **Testability** - Pure domain logic easily tested
- **Business Alignment** - Ubiquitous language aligns code with business
- **Maintainability** - Clear boundaries reduce complexity

## When to Use DDD

DDD is ideal for:

- **Complex Applications** - CRMs, financial systems, enterprise apps
- **Evolving Requirements** - Flexible architecture accommodates changes
- **Large Teams** - Modular structure enables parallel development
- **Long-Term Maintenance** - Reduces technical debt

## When to Avoid DDD

- **Simple CRUD Apps** - Laravel MVC is sufficient
- **Tight Deadlines** - DDD requires upfront investment
- **Small Teams** - Learning curve may slow development
- **Prototypes** - Overhead not justified

## When to Read References

**Strategic DDD:**
- **Identifying contexts**: Read [bounded-contexts.md](references/bounded-contexts.md)
- **Context relationships**: Read [context-mapping.md](references/context-mapping.md)
- **Context integration**: Read [integration-patterns.md](references/integration-patterns.md)
- **Protecting domain**: Read [anti-corruption-layer.md](references/anti-corruption-layer.md)
- **Transaction boundaries**: Read [aggregates.md](references/aggregates.md)

**Tactical DDD:**
- **Creating domain models**: Read [entities.md](references/entities.md)
- **Complex domain logic**: Read [domain-services.md](references/domain-services.md)
- **Data access patterns**: Read [repositories.md](references/repositories.md)
- **Application orchestration**: Read [use-cases.md](references/use-cases.md)
- **Data transfer**: Read [dtos.md](references/dtos.md)
- **Infrastructure setup**: Read [infrastructure.md](references/infrastructure.md)
- **Value objects** (optional): Read [value-objects.md](references/value-objects.md)
- **Events** (optional): Read [domain-events.md](references/domain-events.md)

## Key Principles

1. **Ubiquitous Language** - Use domain terminology everywhere
2. **Bounded Contexts** - Clear boundaries between domains
3. **Separation of Concerns** - Domain, Application, Infrastructure
4. **Dependency Inversion** - Depend on interfaces
5. **Persistence Ignorance** - Domain doesn't know about database

## Common Pitfalls

- ❌ Business logic in controllers
- ❌ Entities knowing about persistence
- ❌ Skipping repository interfaces
- ❌ Returning entities from controllers (use DTOs)
- ❌ Overcomplicating simple features

## Benefits

- ✅ **Modularity** - Organized by business capabilities
- ✅ **Testability** - Pure domain logic
- ✅ **Flexibility** - Easy to swap implementations
- ✅ **Maintainability** - Clear structure
- ✅ **Scalability** - Independent development
- ✅ **Business alignment** - Reflects business processes
