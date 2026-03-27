# DTOs (Data Transfer Objects) in Domain-Driven Design

## What are DTOs?

DTOs transfer data between Application layer and Infrastructure/Presentation layers. They decouple the domain model from external concerns and provide a stable API contract.

**Key Characteristics:**
- Immutable data carriers
- No business logic
- Used for input/output
- Can be serialized/deserialized
- Decouple domain from presentation

## Location

```
app/Application/[BoundedContext]/DTOs/
```

Example:
```
app/Application/Contact/DTOs/CreateContactDTO.php
app/Application/Contact/DTOs/ContactDTO.php
app/Application/Interaction/DTOs/InteractionDTO.php
```

## Input DTOs

Input DTOs receive data from controllers:

```php
<?php

namespace App\Application\Contact\DTOs;

use App\Domain\Contact\ValueObjects\Email;
use App\Domain\Contact\ValueObjects\ContactName;

final readonly class CreateContactDTO
{
    public function __construct(
        public ContactName $name,
        public Email $email
    ) {}

    public static function fromRequest(array $data): self
    {
        return new self(
            ContactName::fromNames($data['first_name'], $data['last_name']),
            Email::fromString($data['email'])
        );
    }
}
```

## Output DTOs

Output DTOs return data to controllers:

```php
<?php

namespace App\Application\Contact\DTOs;

use App\Domain\Contact\Entities\Contact;
use Ramsey\Uuid\UuidInterface;

final readonly class ContactDTO
{
    public function __construct(
        public string $id,
        public string $firstName,
        public string $lastName,
        public string $email,
        public bool $isActive
    ) {}

    public static function fromEntity(Contact $contact): self
    {
        return new self(
            id: $contact->getId()->toString(),
            firstName: $contact->getName()->getFirstName(),
            lastName: $contact->getName()->getLastName(),
            email: $contact->getEmail()->getValue(),
            isActive: $contact->isActive()
        );
    }

    public function toArray(): array
    {
        return [
            'id' => $this->id,
            'first_name' => $this->firstName,
            'last_name' => $this->lastName,
            'email' => $this->email,
            'is_active' => $this->isActive,
        ];
    }
}
```

## DTO Examples

### Update DTO

```php
<?php

namespace App\Application\Contact\DTOs;

use App\Domain\Contact\ValueObjects\Email;
use Ramsey\Uuid\UuidInterface;
use Ramsey\Uuid\Uuid;

final readonly class UpdateContactEmailDTO
{
    public function __construct(
        public UuidInterface $contactId,
        public Email $newEmail
    ) {}

    public static function fromRequest(array $data): self
    {
        return new self(
            Uuid::fromString($data['contact_id']),
            Email::fromString($data['email'])
        );
    }
}
```

### Complex Output DTO

```php
<?php

namespace App\Application\Interaction\DTOs;

use App\Domain\Interaction\Entities\Interaction;

final readonly class InteractionDTO
{
    /**
     * @param array<string> $tags
     */
    public function __construct(
        public string $id,
        public string $contactId,
        public string $type,
        public string $status,
        public string $notes,
        public string $scheduledAt,
        public ?string $completedAt,
        public array $tags
    ) {}

    public static function fromEntity(Interaction $interaction): self
    {
        return new self(
            id: $interaction->getId()->toString(),
            contactId: $interaction->getContactId()->toString(),
            type: $interaction->getType()->getValue(),
            status: $interaction->getStatus()->getValue(),
            notes: $interaction->getNotes(),
            scheduledAt: $interaction->getScheduledAt()->format('Y-m-d H:i:s'),
            completedAt: $interaction->getCompletedAt()?->format('Y-m-d H:i:s'),
            tags: $interaction->getTags()
        );
    }

    public function toArray(): array
    {
        return [
            'id' => $this->id,
            'contact_id' => $this->contactId,
            'type' => $this->type,
            'status' => $this->status,
            'notes' => $this->notes,
            'scheduled_at' => $this->scheduledAt,
            'completed_at' => $this->completedAt,
            'tags' => $this->tags,
        ];
    }
}
```

### Collection DTO

```php
<?php

namespace App\Application\Contact\DTOs;

final readonly class ContactListDTO
{
    /**
     * @param array<ContactDTO> $contacts
     */
    public function __construct(
        public array $contacts
    ) {}

    public function toArray(): array
    {
        return [
            'contacts' => array_map(
                fn(ContactDTO $contact) => $contact->toArray(),
                $this->contacts
            ),
            'count' => count($this->contacts),
        ];
    }
}
```

## Validation

DTOs can include basic validation:

```php
<?php

namespace App\Application\Contact\DTOs;

final readonly class CreateContactDTO
{
    public function __construct(
        public ContactName $name,
        public Email $email,
        public ?string $company = null
    ) {
        if ($company !== null && strlen($company) > 100) {
            throw new \InvalidArgumentException('Company name too long');
        }
    }
}
```

## Nested DTOs

```php
<?php

namespace App\Application\Contact\DTOs;

final readonly class ContactWithInteractionsDTO
{
    /**
     * @param array<InteractionDTO> $interactions
     */
    public function __construct(
        public ContactDTO $contact,
        public array $interactions
    ) {}

    public static function fromEntities(
        Contact $contact,
        array $interactions
    ): self {
        return new self(
            ContactDTO::fromEntity($contact),
            array_map(
                fn($i) => InteractionDTO::fromEntity($i),
                $interactions
            )
        );
    }

    public function toArray(): array
    {
        return [
            'contact' => $this->contact->toArray(),
            'interactions' => array_map(
                fn($i) => $i->toArray(),
                $this->interactions
            ),
        ];
    }
}
```

## Best Practices

### 1. Use readonly

```php
final readonly class ContactDTO
{
    public function __construct(
        public string $id,
        public string $email
    ) {}
}
```

### 2. Static Factory Methods

```php
public static function fromRequest(array $data): self;
public static function fromEntity(Contact $contact): self;
```

### 3. Separate Input and Output

```php
// Input
CreateContactDTO
UpdateContactEmailDTO

// Output
ContactDTO
InteractionDTO
```

### 4. No Business Logic

```php
// GOOD: Just data
final readonly class ContactDTO
{
    public function __construct(
        public string $id,
        public string $email
    ) {}
}

// BAD: Business logic in DTO
final readonly class ContactDTO
{
    public function calculateScore(): int
    {
        // Business logic doesn't belong here
    }
}
```

## Key Takeaways

- DTOs transfer data between layers
- Immutable with `readonly`
- No business logic
- Use static factory methods
- Separate input and output DTOs
- Can include basic validation
- Decouple domain from external concerns
