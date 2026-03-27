# Entities in Domain-Driven Design

## What are Entities?

Entities are domain objects that have a unique identity that runs through time and different states. Unlike Value Objects, two entities with the same attributes are still different if they have different identities.

**Key Characteristics:**
- Have a unique identifier (ID)
- Mutable - state can change over time
- Identity remains constant throughout lifecycle
- Contain business logic and invariants
- Rich domain models, not anemic data containers

## Location

Entities live in the Domain layer:
```
app/Domain/[BoundedContext]/Entities/
```

Example:
```
app/Domain/Contact/Entities/Contact.php
app/Domain/Interaction/Entities/Interaction.php
```

## Design Principles

### 1. Identity

Every entity must have a unique identifier:

```php
<?php

namespace App\Domain\Contact\Entities;

use Ramsey\Uuid\UuidInterface;

class Contact
{
    private UuidInterface $id;

    public function __construct(UuidInterface $id)
    {
        $this->id = $id;
    }

    public function getId(): UuidInterface
    {
        return $this->id;
    }

    public function equals(Contact $other): bool
    {
        return $this->id->equals($other->getId());
    }
}
```

### 2. Encapsulation

Entities should protect their invariants through encapsulation:

```php
<?php

namespace App\Domain\Contact\Entities;

use App\Domain\Contact\ValueObjects\Email;
use App\Domain\Contact\ValueObjects\ContactName;
use App\Domain\Contact\Events\ContactCreated;
use Ramsey\Uuid\UuidInterface;

class Contact
{
    private UuidInterface $id;
    private ContactName $name;
    private Email $email;
    private bool $isActive;
    private array $domainEvents = [];

    private function __construct(
        UuidInterface $id,
        ContactName $name,
        Email $email
    ) {
        $this->id = $id;
        $this->name = $name;
        $this->email = $email;
        $this->isActive = true;
    }

    public static function create(
        UuidInterface $id,
        ContactName $name,
        Email $email
    ): self {
        $contact = new self($id, $name, $email);

        $contact->recordEvent(new ContactCreated($id, $name, $email));

        return $contact;
    }

    public function updateEmail(Email $email): void
    {
        if ($this->email->equals($email)) {
            return;
        }

        $this->email = $email;
    }

    public function deactivate(): void
    {
        if (!$this->isActive) {
            throw new \DomainException('Contact is already deactivated');
        }

        $this->isActive = false;
    }

    public function activate(): void
    {
        if ($this->isActive) {
            throw new \DomainException('Contact is already active');
        }

        $this->isActive = true;
    }

    // Getters
    public function getId(): UuidInterface
    {
        return $this->id;
    }

    public function getName(): ContactName
    {
        return $this->name;
    }

    public function getEmail(): Email
    {
        return $this->email;
    }

    public function isActive(): bool
    {
        return $this->isActive;
    }

    // Domain Events
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

### 3. Business Logic

Entities contain business rules and behaviors:

```php
<?php

namespace App\Domain\Interaction\Entities;

use App\Domain\Interaction\ValueObjects\InteractionType;
use App\Domain\Interaction\ValueObjects\InteractionStatus;
use Ramsey\Uuid\UuidInterface;
use DateTimeImmutable;

class Interaction
{
    private UuidInterface $id;
    private UuidInterface $contactId;
    private InteractionType $type;
    private InteractionStatus $status;
    private string $notes;
    private DateTimeImmutable $scheduledAt;
    private ?DateTimeImmutable $completedAt = null;

    public function complete(string $notes): void
    {
        if ($this->status->isCompleted()) {
            throw new \DomainException('Interaction is already completed');
        }

        if ($this->scheduledAt > new DateTimeImmutable()) {
            throw new \DomainException('Cannot complete future interaction');
        }

        $this->status = InteractionStatus::completed();
        $this->notes = $notes;
        $this->completedAt = new DateTimeImmutable();
    }

    public function reschedule(DateTimeImmutable $newDate): void
    {
        if ($this->status->isCompleted()) {
            throw new \DomainException('Cannot reschedule completed interaction');
        }

        if ($newDate <= new DateTimeImmutable()) {
            throw new \DomainException('Scheduled date must be in the future');
        }

        $this->scheduledAt = $newDate;
    }

    public function cancel(): void
    {
        if ($this->status->isCompleted()) {
            throw new \DomainException('Cannot cancel completed interaction');
        }

        $this->status = InteractionStatus::cancelled();
    }
}
```

### 4. Factory Methods

Use static factory methods for entity creation:

```php
public static function create(
    UuidInterface $id,
    ContactName $name,
    Email $email
): self {
    // Validate business rules

    $contact = new self($id, $name, $email);

    // Raise domain events
    $contact->recordEvent(new ContactCreated($id, $name, $email));

    return $contact;
}

public static function fromPersistence(
    UuidInterface $id,
    ContactName $name,
    Email $email,
    bool $isActive
): self {
    $contact = new self($id, $name, $email);
    $contact->isActive = $isActive;

    // No events raised when reconstituting from persistence

    return $contact;
}
```

## Entities vs Value Objects

| Aspect | Entity | Value Object |
|--------|--------|--------------|
| Identity | Has unique ID | No identity |
| Equality | Based on ID | Based on attributes |
| Mutability | Mutable | Immutable |
| Lifecycle | Tracked over time | Replaced when changed |
| Example | Contact, Interaction | Email, ContactName, Money |

## Common Patterns

### 1. Aggregate Root

Entities that act as aggregate roots control access to other entities:

```php
<?php

namespace App\Domain\Contact\Entities;

class Contact // Aggregate Root
{
    private UuidInterface $id;
    private ContactName $name;
    private Email $email;
    private array $phoneNumbers = []; // Collection of Value Objects
    private array $addresses = []; // Collection of entities/VOs

    public function addPhoneNumber(PhoneNumber $phoneNumber): void
    {
        // Validate business rules
        if (count($this->phoneNumbers) >= 5) {
            throw new \DomainException('Cannot add more than 5 phone numbers');
        }

        $this->phoneNumbers[] = $phoneNumber;
    }

    public function removePhoneNumber(PhoneNumber $phoneNumber): void
    {
        $this->phoneNumbers = array_filter(
            $this->phoneNumbers,
            fn($p) => !$p->equals($phoneNumber)
        );
    }
}
```

### 2. Domain Events

Entities can raise domain events:

```php
private array $domainEvents = [];

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

// Usage
public function deactivate(): void
{
    $this->isActive = false;
    $this->recordEvent(new ContactDeactivated($this->id));
}
```

### 3. Invariant Protection

Entities protect their business rules (invariants):

```php
public function updateEmail(Email $newEmail): void
{
    // Business rule: cannot update email if contact is deactivated
    if (!$this->isActive) {
        throw new \DomainException('Cannot update email for deactivated contact');
    }

    // Business rule: email must be different
    if ($this->email->equals($newEmail)) {
        return;
    }

    $oldEmail = $this->email;
    $this->email = $newEmail;

    $this->recordEvent(new ContactEmailUpdated($this->id, $oldEmail, $newEmail));
}
```

## Best Practices

1. **Keep constructors private** - Use factory methods instead
2. **Use Value Objects** - For attributes without identity
3. **Protect invariants** - Validate in methods, not setters
4. **Raise domain events** - For significant state changes
5. **Avoid anemic models** - Entities should have behavior, not just getters/setters
6. **Use type hints** - Leverage PHP's type system
7. **Immutable by default** - Only allow changes through named methods
8. **No persistence logic** - Entities shouldn't know about databases

## Anti-Patterns to Avoid

❌ **Anemic Domain Model**
```php
// BAD: Just getters and setters
class Contact
{
    private string $email;

    public function getEmail(): string { return $this->email; }
    public function setEmail(string $email): void { $this->email = $email; }
}
```

✅ **Rich Domain Model**
```php
// GOOD: Business logic and invariants
class Contact
{
    private Email $email;

    public function updateEmail(Email $newEmail): void
    {
        // Business logic and validation
    }
}
```

❌ **Public setters**
```php
// BAD
public function setActive(bool $active): void
{
    $this->isActive = $active;
}
```

✅ **Named behavior methods**
```php
// GOOD
public function activate(): void { /* ... */ }
public function deactivate(): void { /* ... */ }
```

## Key Takeaways

- Entities have identity and lifecycle
- Protect business invariants through encapsulation
- Use factory methods for creation
- Raise domain events for significant changes
- Rich models with behavior, not anemic data containers
- No persistence logic in entities
