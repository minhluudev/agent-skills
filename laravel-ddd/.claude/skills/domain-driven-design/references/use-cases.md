# Use Cases (Application Services) in Domain-Driven Design

## What are Use Cases?

Use Cases (also called Application Services) orchestrate domain objects to fulfill a specific application requirement. They coordinate the flow of data between the presentation layer and domain layer.

**Key Characteristics:**
- Live in Application layer
- Orchestrate domain objects
- Handle transactions
- Dispatch domain events
- Return DTOs, not domain entities
- Thin coordinators, not business logic containers

## Location

```
app/Application/[BoundedContext]/UseCases/
```

Example:
```
app/Application/Contact/UseCases/CreateContactUseCase.php
app/Application/Interaction/UseCases/CompleteInteractionUseCase.php
```

## Use Case Structure

```php
<?php

namespace App\Application\Contact\UseCases;

use App\Application\Contact\DTOs\CreateContactDTO;
use App\Application\Contact\DTOs\ContactDTO;
use App\Domain\Contact\Entities\Contact;
use App\Domain\Contact\Repositories\ContactRepositoryInterface;
use Illuminate\Contracts\Events\Dispatcher;
use Ramsey\Uuid\Uuid;

class CreateContactUseCase
{
    public function __construct(
        private readonly ContactRepositoryInterface $contactRepository,
        private readonly Dispatcher $eventDispatcher
    ) {}

    public function execute(CreateContactDTO $dto): ContactDTO
    {
        // Create domain entity
        $contact = Contact::create(
            Uuid::uuid4(),
            $dto->name,
            $dto->email
        );

        // Persist
        $this->contactRepository->save($contact);

        // Dispatch events
        foreach ($contact->releaseEvents() as $event) {
            $this->eventDispatcher->dispatch($event);
        }

        // Return DTO
        return ContactDTO::fromEntity($contact);
    }
}
```

## Use Case Examples

### Create Contact

```php
<?php

namespace App\Application\Contact\UseCases;

use App\Application\Contact\DTOs\CreateContactDTO;
use App\Application\Contact\DTOs\ContactDTO;
use App\Domain\Contact\Entities\Contact;
use App\Domain\Contact\Repositories\ContactRepositoryInterface;
use App\Domain\Contact\Services\ContactMatchingService;
use Illuminate\Contracts\Events\Dispatcher;
use Ramsey\Uuid\Uuid;

class CreateContactUseCase
{
    public function __construct(
        private readonly ContactRepositoryInterface $contactRepository,
        private readonly ContactMatchingService $matchingService,
        private readonly Dispatcher $eventDispatcher
    ) {}

    public function execute(CreateContactDTO $dto): ContactDTO
    {
        // Business logic: Check for duplicates
        $existing = $this->contactRepository->findByEmail($dto->email);
        if ($existing) {
            throw new \DomainException('Contact with this email already exists');
        }

        // Create entity
        $contact = Contact::create(
            Uuid::uuid4(),
            $dto->name,
            $dto->email
        );

        // Check for potential duplicates
        $duplicates = $this->matchingService->findPotentialDuplicates($contact);
        if (!empty($duplicates)) {
            // Log or notify about potential duplicates
        }

        // Persist
        $this->contactRepository->save($contact);

        // Dispatch events
        foreach ($contact->releaseEvents() as $event) {
            $this->eventDispatcher->dispatch($event);
        }

        return ContactDTO::fromEntity($contact);
    }
}
```

### Update Contact Email

```php
<?php

namespace App\Application\Contact\UseCases;

use App\Application\Contact\DTOs\UpdateContactEmailDTO;
use App\Application\Contact\DTOs\ContactDTO;
use App\Domain\Contact\Repositories\ContactRepositoryInterface;
use Illuminate\Contracts\Events\Dispatcher;

class UpdateContactEmailUseCase
{
    public function __construct(
        private readonly ContactRepositoryInterface $contactRepository,
        private readonly Dispatcher $eventDispatcher
    ) {}

    public function execute(UpdateContactEmailDTO $dto): ContactDTO
    {
        // Find entity
        $contact = $this->contactRepository->findById($dto->contactId);
        if (!$contact) {
            throw new \DomainException('Contact not found');
        }

        // Check if email is already in use
        $existing = $this->contactRepository->findByEmail($dto->newEmail);
        if ($existing && !$existing->getId()->equals($contact->getId())) {
            throw new \DomainException('Email already in use');
        }

        // Update entity (business logic in entity)
        $contact->updateEmail($dto->newEmail);

        // Persist
        $this->contactRepository->save($contact);

        // Dispatch events
        foreach ($contact->releaseEvents() as $event) {
            $this->eventDispatcher->dispatch($event);
        }

        return ContactDTO::fromEntity($contact);
    }
}
```

### Complete Interaction

```php
<?php

namespace App\Application\Interaction\UseCases;

use App\Application\Interaction\DTOs\CompleteInteractionDTO;
use App\Application\Interaction\DTOs\InteractionDTO;
use App\Domain\Interaction\Repositories\InteractionRepositoryInterface;
use App\Domain\Interaction\Services\InteractionScheduler;
use Illuminate\Contracts\Events\Dispatcher;

class CompleteInteractionUseCase
{
    public function __construct(
        private readonly InteractionRepositoryInterface $interactionRepository,
        private readonly InteractionScheduler $scheduler,
        private readonly Dispatcher $eventDispatcher
    ) {}

    public function execute(CompleteInteractionDTO $dto): InteractionDTO
    {
        // Find interaction
        $interaction = $this->interactionRepository->findById($dto->interactionId);
        if (!$interaction) {
            throw new \DomainException('Interaction not found');
        }

        // Complete interaction (business logic in entity)
        $interaction->complete($dto->notes);

        // Persist
        $this->interactionRepository->save($interaction);

        // Dispatch events
        foreach ($interaction->releaseEvents() as $event) {
            $this->eventDispatcher->dispatch($event);
        }

        // Suggest next interaction (domain service)
        $nextDate = $this->scheduler->suggestNextInteractionDate($interaction);

        return InteractionDTO::fromEntity($interaction);
    }
}
```

### List Contacts

```php
<?php

namespace App\Application\Contact\UseCases;

use App\Application\Contact\DTOs\ContactListDTO;
use App\Application\Contact\DTOs\ContactDTO;
use App\Domain\Contact\Repositories\ContactRepositoryInterface;

class ListContactsUseCase
{
    public function __construct(
        private readonly ContactRepositoryInterface $contactRepository
    ) {}

    public function execute(): ContactListDTO
    {
        $contacts = $this->contactRepository->findAllActive();

        $contactDTOs = array_map(
            fn($contact) => ContactDTO::fromEntity($contact),
            $contacts
        );

        return new ContactListDTO($contactDTOs);
    }
}
```

## Transaction Management

Use Cases typically manage transactions:

```php
<?php

namespace App\Application\Contact\UseCases;

use Illuminate\Support\Facades\DB;

class CreateContactUseCase
{
    public function execute(CreateContactDTO $dto): ContactDTO
    {
        return DB::transaction(function () use ($dto) {
            // Create contact
            $contact = Contact::create(/*...*/);

            // Save to repository
            $this->contactRepository->save($contact);

            // Maybe create initial interaction
            $interaction = Interaction::create(/*...*/);
            $this->interactionRepository->save($interaction);

            // Dispatch events
            foreach ($contact->releaseEvents() as $event) {
                $this->eventDispatcher->dispatch($event);
            }

            return ContactDTO::fromEntity($contact);
        });
    }
}
```

## Use Case vs Domain Service

| Aspect | Use Case | Domain Service |
|--------|----------|----------------|
| Layer | Application | Domain |
| Purpose | Orchestration | Domain logic |
| Dependencies | Domain + Infrastructure | Domain only |
| Returns | DTOs | Domain objects |
| Transactions | Yes | No |
| Events | Dispatches | No |
| Example | CreateContactUseCase | ContactMatchingService |

## Best Practices

### 1. Keep Thin

```php
// GOOD: Orchestration only
public function execute(CreateContactDTO $dto): ContactDTO
{
    $contact = Contact::create($dto->id, $dto->name, $dto->email);
    $this->contactRepository->save($contact);
    $this->dispatchEvents($contact);
    return ContactDTO::fromEntity($contact);
}

// BAD: Business logic in use case
public function execute(CreateContactDTO $dto): ContactDTO
{
    // Complex validation logic here
    // Complex business rules here
    // Should be in entity or domain service
}
```

### 2. Return DTOs

```php
// GOOD: Return DTO
public function execute(CreateContactDTO $dto): ContactDTO;

// BAD: Return entity
public function execute(CreateContactDTO $dto): Contact;
```

### 3. One Use Case Per Operation

```php
// GOOD: Focused use cases
CreateContactUseCase
UpdateContactEmailUseCase
DeactivateContactUseCase

// BAD: God use case
ContactManagementUseCase  // Does everything
```

### 4. Inject Dependencies

```php
public function __construct(
    private readonly ContactRepositoryInterface $contactRepository,
    private readonly Dispatcher $eventDispatcher
) {}
```

## Use Cases Coordinating Multiple Contexts

When operations span multiple bounded contexts, use cases orchestrate across context boundaries.

### Pattern: Orchestrating Cross-Context Operations

**Use Case calling multiple contexts:**

```php
// Application/Order/UseCases/PlaceOrderUseCase.php
namespace Application\Order\UseCases;

use Infrastructure\Integration\Contact\ContactGateway; // Technical
use Infrastructure\Integration\Inventory\InventoryGateway; // Technical
// use Infrastructure\Order\Integration\Contact\ContactGateway; // Modular
// use Infrastructure\Order\Integration\Inventory\InventoryGateway; // Modular
use Domain\Order\Services\OrderService;

class PlaceOrderUseCase
{
    public function __construct(
        private readonly OrderService $orderService,
        private readonly ContactGateway $contactGateway,
        private readonly InventoryGateway $inventoryGateway
    ) {}

    public function execute(PlaceOrderDTO $dto): OrderDTO
    {
        // 1. Fetch contact details from Contact context
        $contact = $this->contactGateway->getContact($dto->contactId);

        if (!$contact) {
            throw new \DomainException("Contact not found: {$dto->contactId}");
        }

        // 2. Check inventory in Inventory context
        $availability = $this->inventoryGateway->checkAvailability($dto->productId, $dto->quantity);

        if (!$availability['available']) {
            throw new \DomainException("Insufficient inventory for product: {$dto->productId}");
        }

        // 3. Create order in Order context
        $order = $this->orderService->createOrder(
            $dto->contactId,
            $dto->productId,
            $dto->quantity
        );

        // 4. Reserve inventory (separate transaction)
        $this->inventoryGateway->reserve($dto->productId, $dto->quantity, $order->getId());

        return OrderDTO::fromEntity($order);
    }
}
```

**Key points:**
- Uses gateways to access other contexts
- Coordinates logic across contexts
- Each context maintains its own transaction

### Pattern: Saga for Distributed Transactions

When consistency across contexts is critical, use a saga pattern:

```php
// Application/Order/UseCases/PlaceOrderWithSagaUseCase.php
namespace Application\Order\UseCases;

class PlaceOrderWithSagaUseCase
{
    public function execute(PlaceOrderDTO $dto): OrderDTO
    {
        $sagaId = uniqid();
        $order = null;

        try {
            // Step 1: Create order
            $order = $this->orderService->createOrder($dto->contactId, $dto->productId, $dto->quantity);

            // Step 2: Reserve inventory
            $this->inventoryGateway->reserve($dto->productId, $dto->quantity, $order->getId());

            // Step 3: Process payment
            $this->paymentGateway->charge($dto->contactId, $order->getTotal());

            // Step 4: Confirm order
            $order->confirm();
            $this->orderRepository->save($order);

            return OrderDTO::fromEntity($order);
        } catch (\Exception $e) {
            // Compensating transactions (rollback)
            if ($order) {
                $this->orderService->cancelOrder($order->getId());
                $this->inventoryGateway->release($dto->productId, $dto->quantity);
            }

            throw $e;
        }
    }
}
```

**Compensating transactions:**
- Cancel order if payment fails
- Release inventory if order fails
- Ensures eventual consistency

### Pattern: Event-Driven Use Case Coordination

Prefer events over direct calls for loose coupling:

```php
// Application/Contact/UseCases/CreateContactUseCase.php
namespace Application\Contact\UseCases;

class CreateContactUseCase
{
    public function execute(CreateContactDTO $dto): ContactDTO
    {
        // Create contact
        $contact = $this->contactService->createContact($dto->name, $dto->email);

        // Dispatch event - other contexts will react
        Event::dispatch(new ContactCreated(
            $contact->getId(),
            $contact->getName(),
            $contact->getEmail()
        ));

        return ContactDTO::fromEntity($contact);
    }
}

// Sales context reacts via listener
// TECHNICAL: Infrastructure/Listeners/CreateOpportunityWhenContactCreated.php
// MODULAR: Infrastructure/Sales/Listeners/CreateOpportunityWhenContactCreated.php
class CreateOpportunityWhenContactCreated
{
    public function __construct(
        private readonly CreateOpportunityUseCase $createOpportunity
    ) {}

    public function handle(ContactCreated $event): void
    {
        // Sales use case called from Contact event
        $this->createOpportunity->execute(
            new CreateOpportunityDTO(
                contactId: $event->contactId,
                name: "New opportunity for {$event->name}"
            )
        );
    }
}
```

**Benefits:**
- Loose coupling between contexts
- Contact context doesn't know about Sales
- Easy to add new contexts (just add listeners)
- Asynchronous processing possible

### Pattern: Use Case Calling Use Case (Same Context)

Within the same context, use cases can call each other:

```php
// Application/Contact/UseCases/CreateContactWithPreferencesUseCase.php
namespace Application\Contact\UseCases;

class CreateContactWithPreferencesUseCase
{
    public function __construct(
        private readonly CreateContactUseCase $createContact,
        private readonly SetContactPreferencesUseCase $setPreferences
    ) {}

    public function execute(CreateContactWithPreferencesDTO $dto): ContactDTO
    {
        // Call CreateContactUseCase
        $contact = $this->createContact->execute(
            new CreateContactDTO($dto->name, $dto->email)
        );

        // Call SetContactPreferencesUseCase
        $this->setPreferences->execute(
            new SetPreferencesDTO(
                $contact->id,
                $dto->emailNotifications,
                $dto->smsNotifications
            )
        );

        return $contact;
    }
}
```

**Guidelines:**
- ✓ OK within same context
- ❌ Avoid across contexts (use events instead)
- ✓ Promotes reusability
- ✓ Each use case remains focused

### Example: Multi-Context Order Placement

**Complete flow across contexts:**

```php
// 1. Order context - PlaceOrderUseCase
class PlaceOrderUseCase
{
    public function execute(PlaceOrderDTO $dto): OrderDTO
    {
        // Validate contact exists (Contact context)
        $contact = $this->contactGateway->getContact($dto->contactId);

        if (!$contact) {
            throw new ContactNotFoundException($dto->contactId);
        }

        // Check product availability (Catalog context)
        $product = $this->catalogGateway->getProduct($dto->productId);

        if (!$product || $product['stock'] < $dto->quantity) {
            throw new InsufficientStockException($dto->productId);
        }

        // Create order (Order context domain)
        $order = $this->orderService->createOrder(
            $dto->contactId,
            $dto->productId,
            $dto->quantity,
            $product['price']
        );

        // Dispatch event for other contexts
        Event::dispatch(new OrderPlaced(
            $order->getId(),
            $order->getContactId(),
            $order->getProductId(),
            $order->getQuantity()
        ));

        return OrderDTO::fromEntity($order);
    }
}

// 2. Inventory context reacts to event
class ReserveInventoryWhenOrderPlaced
{
    public function handle(OrderPlaced $event): void
    {
        $this->reserveInventoryUseCase->execute(
            new ReserveInventoryDTO(
                $event->productId,
                $event->quantity,
                $event->orderId
            )
        );
    }
}

// 3. Billing context reacts to event
class CreateInvoiceWhenOrderPlaced
{
    public function handle(OrderPlaced $event): void
    {
        // Fetch contact details
        $contact = $this->contactGateway->getContact($event->contactId);

        $this->createInvoiceUseCase->execute(
            new CreateInvoiceDTO(
                $event->orderId,
                $event->contactId,
                $contact['email']
            )
        );
    }
}
```

**Flow:**
1. PlaceOrderUseCase orchestrates across contexts synchronously (Contact, Catalog)
2. PlaceOrderUseCase dispatches OrderPlaced event
3. Inventory context reacts asynchronously
4. Billing context reacts asynchronously

**Result:** Mixed sync/async coordination for optimal consistency and performance.

### Best Practices for Multi-Context Use Cases

1. **Prefer events over direct calls** - Loose coupling
2. **Use gateways for synchronous needs** - Clear integration points
3. **Handle failures gracefully** - Try/catch, compensating transactions
4. **One transaction per context** - Don't span transactions across contexts
5. **Document dependencies** - Make context relationships explicit
6. **Monitor cross-context calls** - Track performance and failures
7. **Consider idempotency** - Events may be replayed

## Key Takeaways

- Use Cases orchestrate domain objects
- Live in Application layer
- Handle transactions and event dispatch
- Return DTOs, not entities
- One use case per operation
- Keep thin - business logic in domain
- Use events for cross-context coordination
- Gateways for synchronous cross-context access
- Sagas for distributed transactions
- Monitor and handle cross-context failures
- Coordinate between domain and infrastructure
