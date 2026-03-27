# Integration Patterns for Bounded Contexts

## Overview

Bounded contexts must integrate to provide complete business functionality. This guide covers patterns for integrating contexts while maintaining their independence and boundaries.

## Integration Approaches

### Event-Driven Integration (Recommended)

**Best for:** Loose coupling, async communication, eventual consistency

### REST API Integration

**Best for:** Sync communication, request-response, real-time data

### Message Queue Integration

**Best for:** High volume, async, reliability, scalability

### Direct Database Access (Anti-Pattern)

**Never use:** Violates bounded context boundaries

## 1. Event-Driven Integration

### Domain Events vs Integration Events

**Domain Events:**
- Internal to a bounded context
- Express business occurrences
- Rich domain language
- Example: `ContactStatusChanged`

**Integration Events:**
- Cross-context communication
- Simplified, stable contract
- More generic than domain events
- Example: `ContactCreatedIntegrationEvent`

### Pattern: Publish Domain Events for Integration

**Step 1: Domain event in Contact context**

```php
// Domain/Contact/Events/ContactCreated.php
namespace Domain\Contact\Events;

class ContactCreated
{
    public function __construct(
        public readonly string $contactId,
        public readonly string $name,
        public readonly string $email,
        public readonly \DateTimeImmutable $createdAt
    ) {}
}
```

**Step 2: Entity raises event**

```php
// Domain/Contact/Services/ContactService.php
namespace Domain\Contact\Services;

use Illuminate\Support\Facades\Event;

class ContactService
{
    public function createContact(string $name, string $email): Contact
    {
        $contact = new Contact(uniqid(), $name, $email);
        $this->contactRepository->save($contact);

        // Dispatch event for other contexts
        Event::dispatch(new ContactCreated(
            $contact->getId(),
            $contact->getName(),
            $contact->getEmail(),
            new \DateTimeImmutable()
        ));

        return $contact;
    }
}
```

**Step 3: Sales context listens to event**

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
        // Sales context reacts to Contact context event
        $this->createOpportunity->execute(
            new CreateOpportunityDTO(
                contactId: $event->contactId,
                name: "New opportunity for {$event->name}",
                source: 'contact_creation'
            )
        );
    }
}
```

**Step 4: Register listener in EventServiceProvider**

```php
// TECHNICAL: Infrastructure/Providers/EventServiceProvider.php
// MODULAR: Infrastructure/Shared/Providers/EventServiceProvider.php
namespace Infrastructure\Providers; // Technical
// namespace Infrastructure\Shared\Providers; // Modular

use Illuminate\Foundation\Support\Providers\EventServiceProvider as ServiceProvider;
use Domain\Contact\Events\ContactCreated;
use Infrastructure\Listeners\CreateOpportunityWhenContactCreated; // Technical
// use Infrastructure\Sales\Listeners\CreateOpportunityWhenContactCreated; // Modular

class EventServiceProvider extends ServiceProvider
{
    protected $listen = [
        ContactCreated::class => [
            CreateOpportunityWhenContactCreated::class,
        ],
    ];
}
```

### Pattern: Convert Domain Events to Integration Events

For external systems or when domain events are too detailed:

```php
// Infrastructure/Integration/Events/ContactCreatedIntegrationEvent.php
namespace Infrastructure\Integration\Events;

class ContactCreatedIntegrationEvent
{
    public function __construct(
        public readonly string $id,
        public readonly string $contactId,
        public readonly string $eventType,
        public readonly array $payload,
        public readonly string $occurredAt
    ) {}

    public static function fromDomainEvent(ContactCreated $domainEvent): self
    {
        return new self(
            id: uniqid(),
            contactId: $domainEvent->contactId,
            eventType: 'contact.created',
            payload: [
                'name' => $domainEvent->name,
                'email' => $domainEvent->email,
            ],
            occurredAt: $domainEvent->createdAt->format('Y-m-d H:i:s')
        );
    }

    public function toMessage(): array
    {
        return [
            'id' => $this->id,
            'type' => $this->eventType,
            'data' => $this->payload,
            'timestamp' => $this->occurredAt,
        ];
    }
}
```

### Event Bus Setup with Laravel

```php
// config/events.php
return [
    'bus' => [
        'default' => 'sync', // or 'redis', 'database'
    ],
];
```

### Eventual Consistency

Events create eventual consistency - data is synchronized asynchronously:

**Example:**
1. Contact created in Contact context (time = 0s)
2. ContactCreated event dispatched (time = 0.1s)
3. Sales context receives event (time = 0.5s)
4. Opportunity created in Sales context (time = 1s)

**Period of inconsistency:** 1 second where contact exists but opportunity doesn't yet.

**This is acceptable for:**
- Non-critical workflows
- Background processes
- Data synchronization
- Notifications

**Not acceptable for:**
- Financial transactions requiring immediate consistency
- Real-time inventory updates
- Critical validation logic

## 2. REST API Integration

### Pattern: Gateway for Synchronous Access

When a context needs immediate data from another context:

**Contact context exposes API:**

```php
// Infrastructure/Http/Controllers/Api/ContactApiController.php
namespace Infrastructure\Http\Controllers\Api;

use Application\Contact\UseCases\GetContactUseCase;
use Illuminate\Http\JsonResponse;

class ContactApiController extends Controller
{
    public function __construct(
        private readonly GetContactUseCase $getContact
    ) {}

    public function show(string $id): JsonResponse
    {
        $contact = $this->getContact->execute($id);

        if (!$contact) {
            return response()->json(['error' => 'Contact not found'], 404);
        }

        return response()->json([
            'id' => $contact->getId(),
            'name' => $contact->getName(),
            'email' => $contact->getEmail(),
            'status' => $contact->getStatus(),
        ]);
    }
}
```

**Sales context consumes API via Gateway:**

```php
// TECHNICAL: Infrastructure/Integration/Contact/ContactGateway.php
// MODULAR: Infrastructure/Sales/Integration/Contact/ContactGateway.php
namespace Infrastructure\Integration\Contact; // Technical
// namespace Infrastructure\Sales\Integration\Contact; // Modular

use Illuminate\Support\Facades\Http;

class ContactGateway
{
    public function __construct(
        private readonly string $contactApiBaseUrl
    ) {}

    public function getContact(string $contactId): ?array
    {
        try {
            $response = Http::timeout(5)
                ->get("{$this->contactApiBaseUrl}/api/contacts/{$contactId}");

            if ($response->successful()) {
                return $response->json();
            }

            return null;
        } catch (\Exception $e) {
            // Log error
            return null;
        }
    }

    public function listContacts(array $filters = []): array
    {
        $response = Http::get("{$this->contactApiBaseUrl}/api/contacts", $filters);

        return $response->successful() ? $response->json('data') : [];
    }
}
```

**Sales context uses gateway with Anti-Corruption Layer:**

```php
// Domain/Sales/Services/OpportunityService.php
namespace Domain\Sales\Services;

use Infrastructure\Integration\Contact\ContactGateway; // Technical
// use Infrastructure\Sales\Integration\Contact\ContactGateway; // Modular

class OpportunityService
{
    public function __construct(
        private readonly ContactGateway $contactGateway
    ) {}

    public function createOpportunity(string $contactId, string $name): Opportunity
    {
        // Fetch contact details from Contact context
        $contactData = $this->contactGateway->getContact($contactId);

        if (!$contactData) {
            throw new \Exception("Contact not found: {$contactId}");
        }

        // Create opportunity with contact reference
        return new Opportunity(
            uniqid(),
            $contactId,
            $name,
            $contactData['name'] // Use contact's name for display
        );
    }
}
```

### Configuration

```php
// config/services.php
return [
    'contact_api' => [
        'base_url' => env('CONTACT_API_URL', 'http://localhost:8000'),
        'timeout' => env('CONTACT_API_TIMEOUT', 5),
    ],
];

// Bind in ServiceProvider
$this->app->singleton(ContactGateway::class, function ($app) {
    return new ContactGateway(
        config('services.contact_api.base_url')
    );
});
```

### API Versioning

```php
// Multiple API versions for backward compatibility
Route::prefix('api/v1')->group(function () {
    Route::get('/contacts/{id}', [ContactApiV1Controller::class, 'show']);
});

Route::prefix('api/v2')->group(function () {
    Route::get('/contacts/{id}', [ContactApiV2Controller::class, 'show']);
});
```

## 3. Message Queue Integration

### Pattern: Async Communication via Queues

For high-volume, reliable, asynchronous integration:

**Contact context publishes to queue:**

```php
// Infrastructure/Jobs/PublishContactCreatedJob.php
namespace Infrastructure\Jobs;

use Illuminate\Bus\Queueable;
use Illuminate\Queue\SerializesModels;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Contracts\Queue\ShouldQueue;

class PublishContactCreatedJob implements ShouldQueue
{
    use Queueable, SerializesModels, InteractsWithQueue;

    public function __construct(
        private readonly string $contactId,
        private readonly string $name,
        private readonly string $email
    ) {}

    public function handle(): void
    {
        // Publish to message queue (Redis, RabbitMQ, etc.)
        Queue::push('contact.created', [
            'contact_id' => $this->contactId,
            'name' => $this->name,
            'email' => $this->email,
            'timestamp' => now()->toIso8601String(),
        ]);
    }
}
```

**Sales context consumes from queue:**

```php
// Infrastructure/Jobs/ConsumeContactCreatedJob.php
namespace Infrastructure\Jobs;

use Application\Sales\UseCases\CreateOpportunityUseCase;

class ConsumeContactCreatedJob implements ShouldQueue
{
    use Queueable, InteractsWithQueue;

    public function __construct(
        private readonly array $message
    ) {}

    public function handle(CreateOpportunityUseCase $createOpportunity): void
    {
        $createOpportunity->execute(
            new CreateOpportunityDTO(
                contactId: $this->message['contact_id'],
                name: "Opportunity for {$this->message['name']}"
            )
        );
    }
}
```

**Queue worker:**

```bash
php artisan queue:work --queue=contact.created
```

### Laravel Queue Configuration

```php
// config/queue.php
'connections' => [
    'redis' => [
        'driver' => 'redis',
        'connection' => 'default',
        'queue' => env('REDIS_QUEUE', 'default'),
        'retry_after' => 90,
    ],
],
```

## 4. Translation Layers

### Pattern: Converting Between Context Models

Protect downstream context from upstream changes:

**Sales context defines its own Contact representation:**

```php
// Domain/Sales/ValueObjects/SalesContact.php
namespace Domain\Sales\ValueObjects;

final readonly class SalesContact
{
    public function __construct(
        public string $contactId,
        public string $displayName,
        public string $primaryEmail
    ) {}
}
```

**Translator converts API response to Sales model:**

```php
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

        // Translation layer maps external structure to internal
        return new SalesContact(
            contactId: $rawContact['id'],
            displayName: $this->formatName($rawContact),
            primaryEmail: $rawContact['email']
        );
    }

    private function formatName(array $contact): string
    {
        // Sales context prefers "Last, First" format
        // even if Contact context changes its name structure
        return $contact['name']; // Could be more complex
    }
}
```

## 5. Direct Database Access (Anti-Pattern)

### Why It's Wrong

**Never do this:**

```php
// ❌ Sales context directly accessing Contact database
namespace Domain\Sales\Repositories;

use Illuminate\Support\Facades\DB;

class OpportunityRepository
{
    public function createOpportunity(string $contactId): void
    {
        // ❌ Directly querying Contact context's database
        $contact = DB::table('contacts')
            ->where('id', $contactId)
            ->first();

        // Create opportunity...
    }
}
```

**Problems:**
- ❌ Violates bounded context boundaries
- ❌ Tight coupling to database schema
- ❌ No domain logic validation
- ❌ Can't change Contact schema independently
- ❌ Can't deploy contexts independently
- ❌ Bypasses business rules
- ❌ Creates hidden dependencies

**Instead, use:**
- ✓ Events for notifications
- ✓ REST APIs for queries
- ✓ Anti-Corruption Layers for protection
- ✓ Message queues for async

## Choosing Integration Pattern

| Pattern | Latency | Coupling | Reliability | Complexity | Use When |
|---------|---------|----------|-------------|------------|----------|
| Event-Driven | High (async) | Low | High (with queue) | Medium | Notifications, workflows, eventual consistency OK |
| REST API | Low (sync) | Medium | Medium | Low | Real-time data needed, request-response |
| Message Queue | High (async) | Low | Very High | High | High volume, guaranteed delivery, async OK |
| Direct DB | Lowest | Highest | High | Low | ❌ Never (anti-pattern) |

## Best Practices

1. **Prefer events** for most integration
2. **Use API gateway pattern** for synchronous needs
3. **Always use translation layers** to protect domain
4. **Version your integration contracts**
5. **Monitor integration points**
6. **Handle failures gracefully** (retries, dead letter queues)
7. **Never access another context's database directly**

## Example: Complete Integration Flow

**Scenario:** Contact created → Sales opportunity created → Billing account setup

**Step 1: Contact context**

```php
// Contact created, event dispatched
$contact = $contactService->createContact('John Doe', 'john@example.com');
Event::dispatch(new ContactCreated($contact->getId(), $contact->getName(), $contact->getEmail()));
```

**Step 2: Sales context listens**

```php
class CreateOpportunityWhenContactCreated
{
    public function handle(ContactCreated $event): void
    {
        $opportunity = $this->salesService->createOpportunity($event->contactId, $event->name);

        // Dispatch event for next context
        Event::dispatch(new OpportunityCreated($opportunity->getId(), $event->contactId));
    }
}
```

**Step 3: Billing context listens**

```php
class CreateAccountWhenOpportunityCreated
{
    public function handle(OpportunityCreated $event): void
    {
        // Fetch contact details via API
        $contact = $this->contactGateway->getContact($event->contactId);

        // Create billing account
        $this->billingService->createAccount($contact['id'], $contact['email']);
    }
}
```

**Integration patterns used:**
- Contact → Sales: Event-driven
- Sales → Billing: Event-driven
- Billing → Contact: REST API (via gateway)

## Common Pitfalls

- ❌ Shared database between contexts
- ❌ Direct entity references across contexts
- ❌ Synchronous calls for non-critical workflows
- ❌ No error handling for integration failures
- ❌ Tight coupling through shared DTOs
- ❌ No versioning strategy
- ❌ Blocking operations in event handlers

## Key Takeaways

- Event-driven integration preferred for loose coupling
- REST APIs for synchronous, real-time needs
- Message queues for high-volume, reliable async
- Always use translation layers to protect contexts
- Never access another context's database directly
- Choose pattern based on latency, coupling, and reliability needs
- Handle integration failures gracefully
