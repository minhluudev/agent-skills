# Repositories in Domain-Driven Design

## What are Repositories?

Repositories provide an abstraction for accessing domain entities, acting as a collection-like interface for retrieving and persisting aggregates.

**Key Characteristics:**
- Interface in Domain layer, implementation in Infrastructure
- Collection-oriented API
- Work with aggregates, not tables
- Hide persistence details from domain

## Location

**Interfaces:**
```
app/Domain/[BoundedContext]/Repositories/
```

**Implementations:**
```
app/Infrastructure/Database/Repositories/
```

## Repository Interface

```php
<?php

namespace App\Domain\Contact\Repositories;

use App\Domain\Contact\Entities\Contact;
use App\Domain\Contact\ValueObjects\Email;
use Ramsey\Uuid\UuidInterface;

interface ContactRepositoryInterface
{
    /**
     * Save a contact (create or update)
     */
    public function save(Contact $contact): void;

    /**
     * Find contact by ID
     */
    public function findById(UuidInterface $id): ?Contact;

    /**
     * Find contact by email
     */
    public function findByEmail(Email $email): ?Contact;

    /**
     * Find all active contacts
     *
     * @return array<Contact>
     */
    public function findAllActive(): array;

    /**
     * Delete a contact
     */
    public function delete(Contact $contact): void;

    /**
     * Check if contact exists
     */
    public function exists(UuidInterface $id): bool;
}
```

## Repository Implementation

```php
<?php

// TECHNICAL: App/Infrastructure/Database/Repositories/EloquentContactRepository.php
// MODULAR: App/Infrastructure/Contact/Database/Repositories/EloquentContactRepository.php
namespace App\Infrastructure\Database\Repositories; // Technical
// namespace App\Infrastructure\Contact\Database\Repositories; // Modular

use App\Domain\Contact\Entities\Contact;
use App\Domain\Contact\Repositories\ContactRepositoryInterface;
use App\Domain\Contact\ValueObjects\Email;
use App\Domain\Contact\ValueObjects\ContactName;
use App\Infrastructure\Database\Eloquent\ContactModel; // Technical
// use App\Infrastructure\Contact\Database\Eloquent\ContactModel; // Modular
use Ramsey\Uuid\UuidInterface;

class EloquentContactRepository implements ContactRepositoryInterface
{
    public function save(Contact $contact): void
    {
        $model = ContactModel::find($contact->getId()->toString());

        if (!$model) {
            $model = new ContactModel();
            $model->id = $contact->getId()->toString();
        }

        $model->first_name = $contact->getName()->getFirstName();
        $model->last_name = $contact->getName()->getLastName();
        $model->email = $contact->getEmail()->getValue();
        $model->is_active = $contact->isActive();

        $model->save();
    }

    public function findById(UuidInterface $id): ?Contact
    {
        $model = ContactModel::find($id->toString());

        if (!$model) {
            return null;
        }

        return $this->toDomain($model);
    }

    public function findByEmail(Email $email): ?Contact
    {
        $model = ContactModel::where('email', $email->getValue())->first();

        if (!$model) {
            return null;
        }

        return $this->toDomain($model);
    }

    public function findAllActive(): array
    {
        $models = ContactModel::where('is_active', true)->get();

        return $models->map(fn($model) => $this->toDomain($model))->toArray();
    }

    public function delete(Contact $contact): void
    {
        ContactModel::destroy($contact->getId()->toString());
    }

    public function exists(UuidInterface $id): bool
    {
        return ContactModel::where('id', $id->toString())->exists();
    }

    /**
     * Map Eloquent model to Domain entity
     */
    private function toDomain(ContactModel $model): Contact
    {
        return Contact::fromPersistence(
            Uuid::fromString($model->id),
            ContactName::fromNames($model->first_name, $model->last_name),
            Email::fromString($model->email),
            $model->is_active
        );
    }
}
```

## Interaction Repository

```php
<?php

namespace App\Domain\Interaction\Repositories;

use App\Domain\Interaction\Entities\Interaction;
use App\Domain\Interaction\ValueObjects\InteractionType;
use Ramsey\Uuid\UuidInterface;
use DateTimeImmutable;

interface InteractionRepositoryInterface
{
    public function save(Interaction $interaction): void;

    public function findById(UuidInterface $id): ?Interaction;

    /**
     * Find interactions for a contact
     *
     * @return array<Interaction>
     */
    public function findByContact(UuidInterface $contactId): array;

    /**
     * Find interactions within date range
     *
     * @return array<Interaction>
     */
    public function findByContactAndDateRange(
        UuidInterface $contactId,
        DateTimeImmutable $start,
        DateTimeImmutable $end
    ): array;

    /**
     * Find last interaction of specific type
     */
    public function findLastByContactAndType(
        UuidInterface $contactId,
        InteractionType $type
    ): ?Interaction;

    /**
     * Find upcoming scheduled interactions
     *
     * @return array<Interaction>
     */
    public function findUpcoming(int $limit = 10): array;

    public function delete(Interaction $interaction): void;
}
```

## Best Practices

### 1. Collection-Oriented Interface

```php
// GOOD: Collection-like methods
public function save(Contact $contact): void;
public function findById(UuidInterface $id): ?Contact;
public function findAll(): array;

// BAD: CRUD-like methods
public function create(array $data): Contact;
public function update(int $id, array $data): bool;
```

### 2. Work with Aggregates

```php
// GOOD: Save entire aggregate
$contact = $this->contactRepository->findById($id);
$contact->updateEmail($newEmail);
$this->contactRepository->save($contact);

// BAD: Update parts separately
$this->contactRepository->updateEmail($id, $email);
```

### 3. Return Domain Objects

```php
// GOOD: Return domain entity
public function findById(UuidInterface $id): ?Contact;

// BAD: Return array or model
public function findById(string $id): array;
public function findById(string $id): ContactModel;
```

### 4. Use Value Objects in Interface

```php
// GOOD: Domain types
public function findByEmail(Email $email): ?Contact;

// BAD: Primitive types
public function findByEmail(string $email): ?Contact;
```

## Mapping Strategies

### From Eloquent to Domain

```php
private function toDomain(ContactModel $model): Contact
{
    $contact = Contact::fromPersistence(
        Uuid::fromString($model->id),
        ContactName::fromNames($model->first_name, $model->last_name),
        Email::fromString($model->email),
        $model->is_active
    );

    // Map phone numbers
    foreach ($model->phoneNumbers as $phoneModel) {
        $contact->addPhoneNumber(
            PhoneNumber::fromString($phoneModel->number)
        );
    }

    return $contact;
}
```

### From Domain to Eloquent

```php
private function toModel(Contact $contact): ContactModel
{
    $model = ContactModel::findOrNew($contact->getId()->toString());

    $model->id = $contact->getId()->toString();
    $model->first_name = $contact->getName()->getFirstName();
    $model->last_name = $contact->getName()->getLastName();
    $model->email = $contact->getEmail()->getValue();
    $model->is_active = $contact->isActive();

    return $model;
}
```

## Specification Pattern (Advanced)

```php
<?php

namespace App\Domain\Contact\Specifications;

interface ContactSpecification
{
    public function isSatisfiedBy(Contact $contact): bool;
}

class ActiveContactSpecification implements ContactSpecification
{
    public function isSatisfiedBy(Contact $contact): bool
    {
        return $contact->isActive();
    }
}

// In repository
public function findBySpecification(ContactSpecification $spec): array
{
    // Implementation depends on persistence layer
}
```

## Service Provider Registration

```php
<?php

// TECHNICAL: App/Infrastructure/Providers/RepositoryServiceProvider.php
// MODULAR: App/Infrastructure/Shared/Providers/RepositoryServiceProvider.php
namespace App\Infrastructure\Providers; // Technical
// namespace App\Infrastructure\Shared\Providers; // Modular

use Illuminate\Support\ServiceProvider;
use App\Domain\Contact\Repositories\ContactRepositoryInterface;
use App\Infrastructure\Database\Repositories\EloquentContactRepository; // Technical
// use App\Infrastructure\Contact\Database\Repositories\EloquentContactRepository; // Modular

class RepositoryServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->bind(
            ContactRepositoryInterface::class,
            EloquentContactRepository::class
        );

        $this->app->bind(
            InteractionRepositoryInterface::class,
            EloquentInteractionRepository::class
        );
    }
}
```

## Key Takeaways

- Interface in Domain, implementation in Infrastructure
- Collection-oriented API
- Work with aggregates
- Return domain objects
- Hide persistence details
- Use Value Objects in signatures
- Mapping between domain and persistence models
