# Domain Events in Domain-Driven Design

## What are Domain Events?

Domain Events are immutable records of significant occurrences in the domain. They represent something that has happened in the past and communicate state changes to other parts of the system.

**Key Characteristics:**
- Immutable - cannot be changed after creation
- Past tense naming - represents something that happened
- Contain relevant data about the event
- Raised by Entities when state changes
- Used for decoupling and eventual consistency

## Location

```
app/Domain/[BoundedContext]/Events/
```

Example:
```
app/Domain/Contact/Events/ContactCreated.php
app/Domain/Contact/Events/ContactEmailUpdated.php
app/Domain/Interaction/Events/InteractionCompleted.php
```

## Event Structure

```php
<?php

namespace App\Domain\Contact\Events;

use App\Domain\Contact\ValueObjects\Email;
use App\Domain\Contact\ValueObjects\ContactName;
use Ramsey\Uuid\UuidInterface;
use DateTimeImmutable;

final readonly class ContactCreated
{
    public function __construct(
        public UuidInterface $contactId,
        public ContactName $name,
        public Email $email,
        public DateTimeImmutable $occurredAt
    ) {}

    public static function now(
        UuidInterface $contactId,
        ContactName $name,
        Email $email
    ): self {
        return new self($contactId, $name, $email, new DateTimeImmutable());
    }
}
```

## Raising Events from Entities

```php
<?php

namespace App\Domain\Contact\Entities;

class Contact
{
    private array $domainEvents = [];

    public static function create(
        UuidInterface $id,
        ContactName $name,
        Email $email
    ): self {
        $contact = new self($id, $name, $email);

        $contact->recordEvent(
            ContactCreated::now($id, $name, $email)
        );

        return $contact;
    }

    public function updateEmail(Email $newEmail): void
    {
        if ($this->email->equals($newEmail)) {
            return;
        }

        $oldEmail = $this->email;
        $this->email = $newEmail;

        $this->recordEvent(
            ContactEmailUpdated::now($this->id, $oldEmail, $newEmail)
        );
    }

    private function recordEvent(object $event): void
    {
        $this->domainEvents[] = $event;
    }

    public function releaseEvents(): array
    {
        $events = $this->domainEvents;
        $this->domainEvents = [];
        return $events;
    }
}
```

## Event Examples

### Contact Events

```php
<?php

namespace App\Domain\Contact\Events;

final readonly class ContactEmailUpdated
{
    public function __construct(
        public UuidInterface $contactId,
        public Email $oldEmail,
        public Email $newEmail,
        public DateTimeImmutable $occurredAt
    ) {}

    public static function now(
        UuidInterface $contactId,
        Email $oldEmail,
        Email $newEmail
    ): self {
        return new self($contactId, $oldEmail, $newEmail, new DateTimeImmutable());
    }
}

final readonly class ContactDeactivated
{
    public function __construct(
        public UuidInterface $contactId,
        public string $reason,
        public DateTimeImmutable $occurredAt
    ) {}
}
```

### Interaction Events

```php
<?php

namespace App\Domain\Interaction\Events;

final readonly class InteractionScheduled
{
    public function __construct(
        public UuidInterface $interactionId,
        public UuidInterface $contactId,
        public InteractionType $type,
        public DateTimeImmutable $scheduledAt,
        public DateTimeImmutable $occurredAt
    ) {}
}

final readonly class InteractionCompleted
{
    public function __construct(
        public UuidInterface $interactionId,
        public UuidInterface $contactId,
        public string $notes,
        public DateTimeImmutable $completedAt,
        public DateTimeImmutable $occurredAt
    ) {}
}

final readonly class InteractionRescheduled
{
    public function __construct(
        public UuidInterface $interactionId,
        public DateTimeImmutable $oldDate,
        public DateTimeImmutable $newDate,
        public DateTimeImmutable $occurredAt
    ) {}
}
```

## Dispatching Events

Events are typically dispatched after the entity is persisted:

```php
<?php

namespace App\Application\Contact\UseCases;

use App\Domain\Contact\Entities\Contact;
use App\Domain\Contact\Repositories\ContactRepositoryInterface;
use Illuminate\Contracts\Events\Dispatcher;

class CreateContactUseCase
{
    public function __construct(
        private readonly ContactRepositoryInterface $contactRepository,
        private readonly Dispatcher $eventDispatcher
    ) {}

    public function execute(CreateContactDTO $dto): Contact
    {
        $contact = Contact::create(
            $dto->id,
            $dto->name,
            $dto->email
        );

        // Persist first
        $this->contactRepository->save($contact);

        // Then dispatch events
        foreach ($contact->releaseEvents() as $event) {
            $this->eventDispatcher->dispatch($event);
        }

        return $contact;
    }
}
```

## Event Handlers/Listeners

```php
<?php

namespace App\Infrastructure\Listeners;

use App\Domain\Contact\Events\ContactCreated;
use App\Infrastructure\Services\EmailService;

class SendWelcomeEmailOnContactCreated
{
    public function __construct(
        private readonly EmailService $emailService
    ) {}

    public function handle(ContactCreated $event): void
    {
        $this->emailService->sendWelcomeEmail(
            $event->email,
            $event->name
        );
    }
}
```

Register in EventServiceProvider:

```php
protected $listen = [
    ContactCreated::class => [
        SendWelcomeEmailOnContactCreated::class,
        LogContactCreationActivity::class,
    ],
];
```

## Best Practices

1. **Use past tense** - `ContactCreated` not `CreateContact`
2. **Immutable** - Use `readonly` classes
3. **Include timestamp** - When the event occurred
4. **Include relevant data** - Everything needed to handle the event
5. **Small and focused** - One event per significant occurrence
6. **No business logic** - Just data carriers
7. **Serializable** - Can be stored and replayed

## Domain Events for Cross-Context Integration

Domain events are excellent for integrating bounded contexts with loose coupling.

### Integration Events vs Domain Events

**Domain Events:**
- Internal to a bounded context
- Rich domain language
- May contain domain objects
- Example: `ContactStatusChanged`

**Integration Events:**
- Cross-context communication
- Simplified, stable contract
- Primitive data types only
- Example: `ContactCreatedIntegrationEvent`

### Pattern: Publish Domain Events Across Contexts

**Contact context publishes domain event:**

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

// Application/Contact/UseCases/CreateContactUseCase.php
use Illuminate\Support\Facades\Event;

public function execute(CreateContactDTO $dto): Contact
{
    $contact = $this->contactService->createContact($dto->name, $dto->email);

    // Dispatch event for other contexts
    Event::dispatch(new ContactCreated(
        $contact->getId(),
        $contact->getName(),
        $contact->getEmail(),
        new \DateTimeImmutable()
    ));

    return $contact;
}
```

**Sales context listens to event:**

```php
// Infrastructure/Listeners/CreateOpportunityWhenContactCreated.php
namespace Infrastructure\Listeners;

use Domain\Contact\Events\ContactCreated;
use Application\Sales\UseCases\CreateOpportunityUseCase;

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
                name: "New opportunity for {$event->name}"
            )
        );
    }
}
```

### Pattern: Convert to Integration Events

For external systems or when domain events contain too much detail:

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

// Convert and publish
Event::listen(ContactCreated::class, function (ContactCreated $event) {
    $integrationEvent = ContactCreatedIntegrationEvent::fromDomainEvent($event);
    Queue::push('external.events', $integrationEvent->toMessage());
});
```

### Event Versioning

As contexts evolve, events need versioning:

```php
namespace Domain\Contact\Events;

// Version 1
class ContactCreatedV1
{
    public function __construct(
        public readonly string $contactId,
        public readonly string $name,
        public readonly string $email
    ) {}
}

// Version 2 - added company field
class ContactCreatedV2
{
    public function __construct(
        public readonly string $contactId,
        public readonly string $name,
        public readonly string $email,
        public readonly ?string $company
    ) {}
}

// Upcaster for backwards compatibility
class ContactCreatedUpcaster
{
    public static function upcast(ContactCreatedV1 $v1): ContactCreatedV2
    {
        return new ContactCreatedV2(
            $v1->contactId,
            $v1->name,
            $v1->email,
            null // Company not available in V1
        );
    }
}
```

### Cross-Context Event Flow Example

**Complete flow: Contact → Sales → Billing**

```php
// 1. Contact context creates contact and dispatches event
class ContactService
{
    public function createContact(string $name, string $email): Contact
    {
        $contact = new Contact(uniqid(), $name, $email);
        $this->contactRepository->save($contact);

        Event::dispatch(new ContactCreated($contact->getId(), $contact->getName(), $contact->getEmail()));

        return $contact;
    }
}

// 2. Sales context listens and creates opportunity
class CreateOpportunityWhenContactCreated
{
    public function handle(ContactCreated $event): void
    {
        $opportunity = $this->salesService->createOpportunity($event->contactId, "New opportunity");

        // Sales dispatches its own event
        Event::dispatch(new OpportunityCreated($opportunity->getId(), $event->contactId));
    }
}

// 3. Billing context listens to opportunity event
class CreateAccountWhenOpportunityCreated
{
    public function handle(OpportunityCreated $event): void
    {
        // Fetch contact details via gateway
        $contact = $this->contactGateway->getContact($event->contactId);

        $this->billingService->createAccount($contact['id'], $contact['email']);
    }
}
```

**Result:** Contact creation triggers opportunity creation, which triggers billing account creation.

### Best Practices for Cross-Context Events

1. **Keep events simple** - Primitive types, no complex objects
2. **Version events** - Support multiple versions for compatibility
3. **Document contracts** - Clear schema for downstream consumers
4. **Handle failures gracefully** - Retry logic, dead letter queues
5. **Monitor event flow** - Track event propagation across contexts
6. **Use correlation IDs** - Trace events across contexts
7. **Consider ordering** - May need ordered event processing

## Key Takeaways

- Domain Events represent significant state changes
- Raised by entities, dispatched by application layer
- Enable decoupling between bounded contexts
- Support event sourcing and audit trails
- Use past tense naming
- Integration events for cross-context communication
- Version events for backwards compatibility
- Always immutable
