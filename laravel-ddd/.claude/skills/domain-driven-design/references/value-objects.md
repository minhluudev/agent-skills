# Value Objects in Domain-Driven Design

## What are Value Objects?

Value Objects are immutable objects that describe characteristics of things. They have no conceptual identity - two Value Objects with the same attributes are considered equal.

**Key Characteristics:**
- Immutable - cannot be changed after creation
- No identity - equality based on attributes
- Self-validating - validate on construction
- Side-effect free behavior
- Can contain business logic

## Location

Value Objects live in the Domain layer:
```
app/Domain/[BoundedContext]/ValueObjects/
```

Example:
```
app/Domain/Contact/ValueObjects/Email.php
app/Domain/Contact/ValueObjects/ContactName.php
app/Domain/Contact/ValueObjects/PhoneNumber.php
```

## Design Principles

### 1. Immutability

Value Objects must be immutable using `readonly` properties (PHP 8.1+):

```php
<?php

namespace App\Domain\Contact\ValueObjects;

final readonly class Email
{
    private function __construct(
        private string $value
    ) {}

    public static function fromString(string $email): self
    {
        $email = trim(strtolower($email));

        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            throw new \InvalidArgumentException("Invalid email address: {$email}");
        }

        return new self($email);
    }

    public function getValue(): string
    {
        return $this->value;
    }

    public function getDomain(): string
    {
        return substr($this->value, strpos($this->value, '@') + 1);
    }

    public function equals(Email $other): bool
    {
        return $this->value === $other->value;
    }

    public function __toString(): string
    {
        return $this->value;
    }
}
```

### 2. Self-Validation

Value Objects validate themselves on construction:

```php
<?php

namespace App\Domain\Contact\ValueObjects;

final readonly class ContactName
{
    private function __construct(
        private string $firstName,
        private string $lastName
    ) {}

    public static function fromNames(string $firstName, string $lastName): self
    {
        $firstName = trim($firstName);
        $lastName = trim($lastName);

        if (empty($firstName)) {
            throw new \InvalidArgumentException('First name cannot be empty');
        }

        if (empty($lastName)) {
            throw new \InvalidArgumentException('Last name cannot be empty');
        }

        if (strlen($firstName) > 50) {
            throw new \InvalidArgumentException('First name too long (max 50 characters)');
        }

        if (strlen($lastName) > 50) {
            throw new \InvalidArgumentException('Last name too long (max 50 characters)');
        }

        return new self($firstName, $lastName);
    }

    public function getFirstName(): string
    {
        return $this->firstName;
    }

    public function getLastName(): string
    {
        return $this->lastName;
    }

    public function getFullName(): string
    {
        return "{$this->firstName} {$this->lastName}";
    }

    public function equals(ContactName $other): bool
    {
        return $this->firstName === $other->firstName
            && $this->lastName === $other->lastName;
    }

    public function __toString(): string
    {
        return $this->getFullName();
    }
}
```

### 3. Value Equality

Implement equality based on attributes, not identity:

```php
public function equals(self $other): bool
{
    return $this->value === $other->value;
}

// For complex Value Objects
public function equals(Address $other): bool
{
    return $this->street === $other->street
        && $this->city === $other->city
        && $this->state === $other->state
        && $this->zipCode === $other->zipCode
        && $this->country === $other->country;
}
```

### 4. Behavior and Business Logic

Value Objects can contain domain logic:

```php
<?php

namespace App\Domain\Contact\ValueObjects;

final readonly class PhoneNumber
{
    private function __construct(
        private string $countryCode,
        private string $number
    ) {}

    public static function fromString(string $phoneNumber): self
    {
        // Remove all non-digit characters
        $cleaned = preg_replace('/\D/', '', $phoneNumber);

        if (strlen($cleaned) < 10) {
            throw new \InvalidArgumentException('Phone number too short');
        }

        // Extract country code (assume +1 for 11 digits, local for 10)
        if (strlen($cleaned) === 11) {
            $countryCode = substr($cleaned, 0, 1);
            $number = substr($cleaned, 1);
        } else {
            $countryCode = '1'; // Default US
            $number = $cleaned;
        }

        return new self($countryCode, $number);
    }

    public function format(): string
    {
        // Format as +1 (555) 123-4567
        $area = substr($this->number, 0, 3);
        $prefix = substr($this->number, 3, 3);
        $line = substr($this->number, 6);

        return "+{$this->countryCode} ({$area}) {$prefix}-{$line}";
    }

    public function isInternational(): bool
    {
        return $this->countryCode !== '1';
    }

    public function equals(PhoneNumber $other): bool
    {
        return $this->countryCode === $other->countryCode
            && $this->number === $other->number;
    }

    public function __toString(): string
    {
        return $this->format();
    }
}
```

## Common Value Object Examples

### Money

```php
<?php

namespace App\Domain\Shared\ValueObjects;

final readonly class Money
{
    private function __construct(
        private int $amount, // Store as cents
        private string $currency
    ) {}

    public static function fromAmount(float $amount, string $currency = 'USD'): self
    {
        if ($amount < 0) {
            throw new \InvalidArgumentException('Amount cannot be negative');
        }

        return new self((int) round($amount * 100), strtoupper($currency));
    }

    public function add(Money $other): self
    {
        if ($this->currency !== $other->currency) {
            throw new \InvalidArgumentException('Cannot add money with different currencies');
        }

        return new self($this->amount + $other->amount, $this->currency);
    }

    public function subtract(Money $other): self
    {
        if ($this->currency !== $other->currency) {
            throw new \InvalidArgumentException('Cannot subtract money with different currencies');
        }

        if ($this->amount < $other->amount) {
            throw new \InvalidArgumentException('Insufficient funds');
        }

        return new self($this->amount - $other->amount, $this->currency);
    }

    public function multiply(float $multiplier): self
    {
        return new self((int) round($this->amount * $multiplier), $this->currency);
    }

    public function getAmount(): float
    {
        return $this->amount / 100;
    }

    public function getCurrency(): string
    {
        return $this->currency;
    }

    public function format(): string
    {
        return number_format($this->getAmount(), 2) . ' ' . $this->currency;
    }

    public function equals(Money $other): bool
    {
        return $this->amount === $other->amount
            && $this->currency === $other->currency;
    }
}
```

### Date Range

```php
<?php

namespace App\Domain\Shared\ValueObjects;

use DateTimeImmutable;

final readonly class DateRange
{
    private function __construct(
        private DateTimeImmutable $startDate,
        private DateTimeImmutable $endDate
    ) {}

    public static function create(
        DateTimeImmutable $startDate,
        DateTimeImmutable $endDate
    ): self {
        if ($startDate > $endDate) {
            throw new \InvalidArgumentException('Start date must be before end date');
        }

        return new self($startDate, $endDate);
    }

    public function contains(DateTimeImmutable $date): bool
    {
        return $date >= $this->startDate && $date <= $this->endDate;
    }

    public function overlaps(DateRange $other): bool
    {
        return $this->startDate <= $other->endDate
            && $this->endDate >= $other->startDate;
    }

    public function getDurationInDays(): int
    {
        return $this->startDate->diff($this->endDate)->days;
    }

    public function getStartDate(): DateTimeImmutable
    {
        return $this->startDate;
    }

    public function getEndDate(): DateTimeImmutable
    {
        return $this->endDate;
    }

    public function equals(DateRange $other): bool
    {
        return $this->startDate == $other->startDate
            && $this->endDate == $other->endDate;
    }
}
```

### Address

```php
<?php

namespace App\Domain\Contact\ValueObjects;

final readonly class Address
{
    private function __construct(
        private string $street,
        private string $city,
        private string $state,
        private string $zipCode,
        private string $country
    ) {}

    public static function create(
        string $street,
        string $city,
        string $state,
        string $zipCode,
        string $country = 'US'
    ): self {
        if (empty($street) || empty($city) || empty($state) || empty($zipCode)) {
            throw new \InvalidArgumentException('All address fields are required');
        }

        // Validate zip code format
        if (!preg_match('/^\d{5}(-\d{4})?$/', $zipCode)) {
            throw new \InvalidArgumentException('Invalid zip code format');
        }

        return new self($street, $city, $state, $zipCode, strtoupper($country));
    }

    public function format(): string
    {
        return "{$this->street}, {$this->city}, {$this->state} {$this->zipCode}, {$this->country}";
    }

    public function getStreet(): string { return $this->street; }
    public function getCity(): string { return $this->city; }
    public function getState(): string { return $this->state; }
    public function getZipCode(): string { return $this->zipCode; }
    public function getCountry(): string { return $this->country; }

    public function equals(Address $other): bool
    {
        return $this->street === $other->street
            && $this->city === $other->city
            && $this->state === $other->state
            && $this->zipCode === $other->zipCode
            && $this->country === $other->country;
    }

    public function __toString(): string
    {
        return $this->format();
    }
}
```

### Status/Enum Value Objects

```php
<?php

namespace App\Domain\Interaction\ValueObjects;

final readonly class InteractionStatus
{
    private const SCHEDULED = 'scheduled';
    private const COMPLETED = 'completed';
    private const CANCELLED = 'cancelled';

    private function __construct(
        private string $value
    ) {}

    public static function scheduled(): self
    {
        return new self(self::SCHEDULED);
    }

    public static function completed(): self
    {
        return new self(self::COMPLETED);
    }

    public static function cancelled(): self
    {
        return new self(self::CANCELLED);
    }

    public static function fromString(string $status): self
    {
        return match ($status) {
            self::SCHEDULED => self::scheduled(),
            self::COMPLETED => self::completed(),
            self::CANCELLED => self::cancelled(),
            default => throw new \InvalidArgumentException("Invalid status: {$status}")
        };
    }

    public function isScheduled(): bool
    {
        return $this->value === self::SCHEDULED;
    }

    public function isCompleted(): bool
    {
        return $this->value === self::COMPLETED;
    }

    public function isCancelled(): bool
    {
        return $this->value === self::CANCELLED;
    }

    public function equals(InteractionStatus $other): bool
    {
        return $this->value === $other->value;
    }

    public function __toString(): string
    {
        return $this->value;
    }
}
```

## Best Practices

1. **Always use readonly** - Enforce immutability at language level (PHP 8.1+)
2. **Private constructor** - Use static factory methods
3. **Validate in factory** - Ensure valid state on creation
4. **Implement equals()** - For value-based comparison
5. **Implement __toString()** - For easy string representation
6. **Make final** - Prevent inheritance
7. **No setters** - Create new instance instead
8. **Rich behavior** - Include domain logic, not just data

## When to Use Value Objects

Use Value Objects when:
- ✅ The concept has no identity (email, money, date range)
- ✅ Equality is based on attributes, not identity
- ✅ The value should be immutable
- ✅ You need to bundle related attributes (address = street + city + state + zip)
- ✅ You want to enforce business rules (valid email, positive money)

Don't use Value Objects when:
- ❌ The concept has identity (Contact, Interaction)
- ❌ The object needs to be tracked over time
- ❌ Mutability is required

## Value Objects vs Entities

| Aspect | Value Object | Entity |
|--------|--------------|--------|
| Identity | No identity | Unique ID |
| Equality | Attribute-based | ID-based |
| Mutability | Immutable | Mutable |
| Lifecycle | Replaced | Modified |
| Example | Email, Money | Contact, Interaction |

## Key Takeaways

- Value Objects are immutable
- Equality based on attributes, not identity
- Self-validating on construction
- Can contain business logic
- Use `readonly` for immutability
- Use static factory methods
- Replace rather than modify
