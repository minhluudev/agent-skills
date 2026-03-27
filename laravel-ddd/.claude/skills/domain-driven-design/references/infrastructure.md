# Infrastructure & Interfaces Layers in DDD

## Directory Structure

```
app/
├── Domain/
│   ├── Order/
│   │   ├── Entities/
│   │   ├── ValueObjects/
│   │   ├── Aggregates/
│   │   ├── Repositories/        # Interfaces only — no implementation here
│   │   ├── Services/
│   │   ├── Events/
│   │   └── Exceptions/
│   ├── User/
│   └── Payment/
│
├── Application/
│   ├── Order/
│   │   ├── Commands/            # Write intent (e.g. PlaceOrderCommand)
│   │   ├── Queries/             # Read intent (e.g. GetOrderQuery)
│   │   ├── DTOs/                # Input + output data transfer objects
│   │   └── UseCases/            # One use case per Command or Query
│   ├── User/
│   └── Payment/
│
├── Infrastructure/
│   ├── Persistence/
│   │   └── Eloquent/
│   │       ├── Models/          # Eloquent models — separate from domain entities
│   │       └── Repositories/    # Implements domain repository interfaces
│   ├── Services/
│   │   ├── PaymentGateway/      # VNPay, Stripe, etc. adapters
│   │   └── Email/               # Mail service adapters
│   └── Providers/               # Service providers — bind interfaces to implementations
│
├── Interfaces/
│   ├── Http/
│   │   ├── Controllers/         # Thin — delegate to UseCases
│   │   ├── Requests/            # Form request validation
│   │   └── Resources/           # API response transformation
│   ├── Console/                 # Artisan commands
│   └── Jobs/                    # Queued jobs
│
└── Shared/
    ├── Kernel/                  # Base classes, contracts used across layers
    ├── ValueObjects/            # Value objects reused across multiple domains
    └── Helpers/                 # Pure utility functions
```

## Layer Rules

### Domain — no framework dependencies
- Entities, Aggregates, Value Objects, Domain Services, Events, Exceptions
- Repository interfaces define the contract; no Eloquent here
- Must be testable with plain PHP (no Laravel container needed)

### Application — orchestration only
- Commands carry write intent; Queries carry read intent
- UseCases execute one Command or Query and return a DTO
- No business logic — delegate to Domain objects
- No Eloquent — depend on repository interfaces

### Infrastructure — technical implementations
- `Persistence/Eloquent/Models/` — Eloquent models are persistence models, not domain entities
- `Persistence/Eloquent/Repositories/` — implement domain `RepositoryInterface`
- `Services/PaymentGateway/` — wraps external payment APIs; implements a domain interface
- `Services/Email/` — wraps Laravel Mail; implements a domain interface
- `Providers/` — binds `OrderRepositoryInterface::class => EloquentOrderRepository::class`

### Interfaces — entry points
- Controllers receive HTTP input, build a Command/Query, call the UseCase, return a Resource
- Requests handle validation only (no business logic)
- Resources transform DTOs to JSON (never expose domain entities directly)
- Jobs wrap a Command and dispatch it to a UseCase via the queue

### Shared — cross-cutting concerns
- `Kernel/` — base entity, base value object, base exception classes
- `ValueObjects/` — e.g. `Money`, `Uuid` reused by Order, Payment, User
- `Helpers/` — pure functions (formatting, conversion) with no side effects

## Namespace Reference

| Path | Namespace |
|------|-----------|
| `app/Domain/Order/Entities/Order.php` | `App\Domain\Order\Entities` |
| `app/Domain/Order/Repositories/OrderRepositoryInterface.php` | `App\Domain\Order\Repositories` |
| `app/Application/Order/Commands/PlaceOrderCommand.php` | `App\Application\Order\Commands` |
| `app/Application/Order/UseCases/PlaceOrderUseCase.php` | `App\Application\Order\UseCases` |
| `app/Application/Order/DTOs/OrderDTO.php` | `App\Application\Order\DTOs` |
| `app/Infrastructure/Persistence/Eloquent/Models/OrderModel.php` | `App\Infrastructure\Persistence\Eloquent\Models` |
| `app/Infrastructure/Persistence/Eloquent/Repositories/EloquentOrderRepository.php` | `App\Infrastructure\Persistence\Eloquent\Repositories` |
| `app/Infrastructure/Services/PaymentGateway/VNPayGateway.php` | `App\Infrastructure\Services\PaymentGateway` |
| `app/Infrastructure/Providers/DomainServiceProvider.php` | `App\Infrastructure\Providers` |
| `app/Interfaces/Http/Controllers/OrderController.php` | `App\Interfaces\Http\Controllers` |
| `app/Interfaces/Http/Requests/PlaceOrderRequest.php` | `App\Interfaces\Http\Requests` |
| `app/Interfaces/Http/Resources/OrderResource.php` | `App\Interfaces\Http\Resources` |
| `app/Interfaces/Jobs/ProcessPaymentJob.php` | `App\Interfaces\Jobs` |
| `app/Shared/ValueObjects/Money.php` | `App\Shared\ValueObjects` |

All namespaces fall under `App\` which maps to `app/` — no changes to `composer.json` needed.

## Key Patterns

### Persistence Model vs Domain Entity

```php
// Infrastructure — Eloquent model (persistence concern)
// app/Infrastructure/Persistence/Eloquent/Models/OrderModel.php
class OrderModel extends Model
{
    protected $table = 'orders';
    protected $fillable = ['id', 'user_id', 'total_amount', 'status'];
    public $incrementing = false;
    protected $keyType = 'string';
}

// Domain — entity (business concern)
// app/Domain/Order/Entities/Order.php
class Order
{
    // No Model, no $fillable, no $table — pure PHP
}
```

### Repository: Interface in Domain, Implementation in Infrastructure

```php
// app/Domain/Order/Repositories/OrderRepositoryInterface.php
namespace App\Domain\Order\Repositories;

interface OrderRepositoryInterface
{
    public function save(Order $order): void;
    public function findById(string $id): ?Order;
}

// app/Infrastructure/Persistence/Eloquent/Repositories/EloquentOrderRepository.php
namespace App\Infrastructure\Persistence\Eloquent\Repositories;

class EloquentOrderRepository implements OrderRepositoryInterface
{
    public function save(Order $order): void { /* ... */ }
    public function findById(string $id): ?Order { /* ... */ }
}
```

### External Service Adapter

```php
// app/Infrastructure/Services/PaymentGateway/VNPayGateway.php
namespace App\Infrastructure\Services\PaymentGateway;

use App\Domain\Payment\Services\PaymentGatewayInterface;

class VNPayGateway implements PaymentGatewayInterface
{
    public function createPaymentUrl(string $orderId, int $amount): string
    {
        // VNPay-specific implementation
    }
}
```

### Thin Controller

```php
// app/Interfaces/Http/Controllers/OrderController.php
namespace App\Interfaces\Http\Controllers;

class OrderController extends Controller
{
    public function __construct(
        private readonly PlaceOrderUseCase $useCase,
    ) {}

    public function store(PlaceOrderRequest $request): JsonResponse
    {
        $dto = $this->useCase->execute(new PlaceOrderCommand(
            userId: $request->user()->id,
            totalAmount: $request->validated('total_amount'),
        ));

        return (new OrderResource($dto))->response()->setStatusCode(201);
    }
}
```

### Service Provider Binding

```php
// app/Infrastructure/Providers/DomainServiceProvider.php
namespace App\Infrastructure\Providers;

use Illuminate\Support\ServiceProvider;
use App\Domain\Order\Repositories\OrderRepositoryInterface;
use App\Infrastructure\Persistence\Eloquent\Repositories\EloquentOrderRepository;
use App\Domain\Payment\Services\PaymentGatewayInterface;
use App\Infrastructure\Services\PaymentGateway\VNPayGateway;

class DomainServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->bind(OrderRepositoryInterface::class, EloquentOrderRepository::class);
        $this->app->bind(PaymentGatewayInterface::class, VNPayGateway::class);
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

## Common Pitfalls

- ❌ Returning Eloquent models from UseCases — return DTOs only
- ❌ Calling Eloquent directly from Domain or Application layers
- ❌ Putting business logic in Controllers or Requests
- ❌ Putting validation logic in UseCases — belongs in Form Requests
- ❌ Putting domain logic in Jobs — Jobs should call a UseCase, not contain logic
- ❌ Shared ValueObjects that depend on domain-specific concepts — keep Shared truly generic
