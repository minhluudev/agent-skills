# Domain Services in Domain-Driven Design

## What are Domain Services?

Domain Services are stateless operations that don't naturally fit within an Entity or Value Object. They encapsulate domain logic that involves multiple entities or doesn't belong to any single entity.

**Key Characteristics:**
- Stateless - no internal state
- Contain domain logic that doesn't fit in entities
- Coordinate between multiple aggregates
- Express domain concepts in the ubiquitous language
- Live in the Domain layer

## Location

Domain Services live in the Domain layer:
```
app/Domain/[BoundedContext]/Services/
```

Example:
```
app/Domain/Contact/Services/ContactMatchingService.php
app/Domain/Interaction/Services/InteractionScheduler.php
```

## When to Use Domain Services

Use Domain Services when:
- ✅ Operation involves multiple entities
- ✅ Logic doesn't naturally belong to any single entity
- ✅ Operation is a significant domain concept
- ✅ Stateless behavior is needed

Don't use when:
- ❌ Logic belongs to an entity (put it in the entity instead)
- ❌ Logic is application-level (use Application Service/UseCase)
- ❌ Logic is infrastructure-level (use Infrastructure Service)

## Domain Service vs Application Service (UseCase)

| Aspect | Domain Service | Application Service (UseCase) |
|--------|----------------|-------------------------------|
| Layer | Domain | Application |
| Purpose | Domain logic | Orchestration |
| State | Stateless | Stateless |
| Dependencies | Other domain objects | Domain + Infrastructure |
| Example | Calculate shipping cost | Process order workflow |

## Examples

### Contact Matching Service

```php
<?php

namespace App\Domain\Contact\Services;

use App\Domain\Contact\Entities\Contact;
use App\Domain\Contact\ValueObjects\Email;
use App\Domain\Contact\ValueObjects\ContactName;
use App\Domain\Contact\Repositories\ContactRepositoryInterface;

/**
 * Service for matching and detecting duplicate contacts
 */
class ContactMatchingService
{
    public function __construct(
        private readonly ContactRepositoryInterface $contactRepository
    ) {}

    /**
     * Find potential duplicate contacts
     *
     * @param Contact $contact
     * @return array<Contact>
     */
    public function findPotentialDuplicates(Contact $contact): array
    {
        $duplicates = [];

        // Match by exact email
        $emailMatches = $this->contactRepository->findByEmail($contact->getEmail());
        foreach ($emailMatches as $match) {
            if (!$match->getId()->equals($contact->getId())) {
                $duplicates[] = $match;
            }
        }

        // Match by similar name
        $nameMatches = $this->contactRepository->findBySimilarName(
            $contact->getName()
        );
        foreach ($nameMatches as $match) {
            if (!$match->getId()->equals($contact->getId())
                && !in_array($match, $duplicates, true)
            ) {
                $duplicates[] = $match;
            }
        }

        return $duplicates;
    }

    /**
     * Calculate similarity score between two contacts
     *
     * @param Contact $contact1
     * @param Contact $contact2
     * @return float Similarity score from 0 to 1
     */
    public function calculateSimilarityScore(
        Contact $contact1,
        Contact $contact2
    ): float {
        $score = 0;

        // Email match (40% weight)
        if ($contact1->getEmail()->equals($contact2->getEmail())) {
            $score += 0.4;
        }

        // Name similarity (30% weight)
        $nameScore = $this->calculateNameSimilarity(
            $contact1->getName(),
            $contact2->getName()
        );
        $score += $nameScore * 0.3;

        // Phone number match (30% weight)
        if ($this->haveMatchingPhoneNumbers($contact1, $contact2)) {
            $score += 0.3;
        }

        return $score;
    }

    private function calculateNameSimilarity(
        ContactName $name1,
        ContactName $name2
    ): float {
        $full1 = strtolower($name1->getFullName());
        $full2 = strtolower($name2->getFullName());

        similar_text($full1, $full2, $percent);

        return $percent / 100;
    }

    private function haveMatchingPhoneNumbers(
        Contact $contact1,
        Contact $contact2
    ): bool {
        foreach ($contact1->getPhoneNumbers() as $phone1) {
            foreach ($contact2->getPhoneNumbers() as $phone2) {
                if ($phone1->equals($phone2)) {
                    return true;
                }
            }
        }

        return false;
    }
}
```

### Interaction Scheduler Service

```php
<?php

namespace App\Domain\Interaction\Services;

use App\Domain\Interaction\Entities\Interaction;
use App\Domain\Interaction\ValueObjects\InteractionType;
use App\Domain\Interaction\Repositories\InteractionRepositoryInterface;
use DateTimeImmutable;
use DateInterval;

/**
 * Service for scheduling interactions based on business rules
 */
class InteractionScheduler
{
    public function __construct(
        private readonly InteractionRepositoryInterface $interactionRepository
    ) {}

    /**
     * Suggest next interaction date based on business rules
     *
     * @param Interaction $lastInteraction
     * @return DateTimeImmutable
     */
    public function suggestNextInteractionDate(
        Interaction $lastInteraction
    ): DateTimeImmutable {
        $baseDate = $lastInteraction->getCompletedAt() ?? new DateTimeImmutable();

        return match ($lastInteraction->getType()->getValue()) {
            'call' => $this->addBusinessDays($baseDate, 7),
            'email' => $this->addBusinessDays($baseDate, 3),
            'meeting' => $this->addBusinessDays($baseDate, 14),
            'followup' => $this->addBusinessDays($baseDate, 2),
            default => $this->addBusinessDays($baseDate, 7),
        };
    }

    /**
     * Check if interaction conflicts with existing schedule
     *
     * @param Interaction $interaction
     * @return bool
     */
    public function hasSchedulingConflict(Interaction $interaction): bool
    {
        $contactId = $interaction->getContactId();
        $scheduledAt = $interaction->getScheduledAt();

        // Find interactions within 30 minutes
        $start = $scheduledAt->sub(new DateInterval('PT30M'));
        $end = $scheduledAt->add(new DateInterval('PT30M'));

        $conflicts = $this->interactionRepository->findByContactAndDateRange(
            $contactId,
            $start,
            $end
        );

        foreach ($conflicts as $existing) {
            if (!$existing->getId()->equals($interaction->getId())) {
                return true;
            }
        }

        return false;
    }

    /**
     * Determine if contact is overdue for interaction
     *
     * @param UuidInterface $contactId
     * @param InteractionType $type
     * @return bool
     */
    public function isOverdueForInteraction(
        UuidInterface $contactId,
        InteractionType $type
    ): bool {
        $lastInteraction = $this->interactionRepository->findLastByContactAndType(
            $contactId,
            $type
        );

        if (!$lastInteraction) {
            return true;
        }

        $suggestedDate = $this->suggestNextInteractionDate($lastInteraction);

        return $suggestedDate < new DateTimeImmutable();
    }

    /**
     * Add business days to a date (skipping weekends)
     *
     * @param DateTimeImmutable $date
     * @param int $days
     * @return DateTimeImmutable
     */
    private function addBusinessDays(
        DateTimeImmutable $date,
        int $days
    ): DateTimeImmutable {
        $current = $date;
        $addedDays = 0;

        while ($addedDays < $days) {
            $current = $current->add(new DateInterval('P1D'));

            // Skip weekends
            if ((int) $current->format('N') < 6) {
                $addedDays++;
            }
        }

        return $current;
    }
}
```

### Pricing Service

```php
<?php

namespace App\Domain\Order\Services;

use App\Domain\Order\Entities\Order;
use App\Domain\Shared\ValueObjects\Money;
use App\Domain\Customer\Entities\Customer;

/**
 * Service for calculating prices based on business rules
 */
class PricingService
{
    /**
     * Calculate total price for an order
     *
     * @param Order $order
     * @param Customer $customer
     * @return Money
     */
    public function calculateTotal(Order $order, Customer $customer): Money
    {
        $subtotal = $order->getSubtotal();

        // Apply customer-specific discount
        $discount = $this->calculateDiscount($subtotal, $customer);
        $afterDiscount = $subtotal->subtract($discount);

        // Apply tax
        $tax = $this->calculateTax($afterDiscount, $order->getShippingAddress());

        // Add shipping
        $shipping = $this->calculateShipping($order);

        return $afterDiscount->add($tax)->add($shipping);
    }

    /**
     * Calculate discount based on customer tier
     *
     * @param Money $amount
     * @param Customer $customer
     * @return Money
     */
    private function calculateDiscount(Money $amount, Customer $customer): Money
    {
        $discountPercent = match ($customer->getTier()) {
            'bronze' => 0,
            'silver' => 5,
            'gold' => 10,
            'platinum' => 15,
            default => 0,
        };

        return $amount->multiply($discountPercent / 100);
    }

    /**
     * Calculate tax based on shipping address
     *
     * @param Money $amount
     * @param Address $address
     * @return Money
     */
    private function calculateTax(Money $amount, Address $address): Money
    {
        $taxRate = $this->getTaxRateForState($address->getState());

        return $amount->multiply($taxRate);
    }

    /**
     * Calculate shipping cost
     *
     * @param Order $order
     * @return Money
     */
    private function calculateShipping(Order $order): Money
    {
        $weight = $order->getTotalWeight();
        $destination = $order->getShippingAddress();

        // Simplified shipping calculation
        if ($weight > 50) {
            return Money::fromAmount(25.00);
        } elseif ($weight > 20) {
            return Money::fromAmount(15.00);
        } else {
            return Money::fromAmount(5.00);
        }
    }

    private function getTaxRateForState(string $state): float
    {
        // Simplified tax rates
        return match ($state) {
            'CA' => 0.0725,
            'NY' => 0.0800,
            'TX' => 0.0625,
            default => 0.0500,
        };
    }
}
```

## Best Practices

### 1. Keep Services Stateless

```php
// GOOD: Stateless service
class ContactMatchingService
{
    public function calculateSimilarity(Contact $c1, Contact $c2): float
    {
        // No internal state
    }
}

// BAD: Stateful service
class ContactMatchingService
{
    private array $cachedResults = []; // State!

    public function calculateSimilarity(Contact $c1, Contact $c2): float
    {
        // Storing state defeats the purpose
    }
}
```

### 2. Use Dependency Injection

```php
public function __construct(
    private readonly ContactRepositoryInterface $contactRepository,
    private readonly InteractionRepositoryInterface $interactionRepository
) {}
```

### 3. Name Services After Domain Concepts

```php
// GOOD: Domain language
ContactMatchingService
InteractionScheduler
PricingService

// BAD: Generic names
ContactHelper
InteractionManager
PriceCalculator
```

### 4. Keep Business Logic in Domain Layer

```php
// Domain Service - belongs here
class PricingService
{
    public function calculateTotal(Order $order): Money
    {
        // Business rules for pricing
    }
}

// Infrastructure Service - different layer
class EmailService
{
    public function sendEmail(Email $email): void
    {
        // Technical implementation
    }
}
```

## Common Patterns

### 1. Specification Pattern

```php
<?php

namespace App\Domain\Contact\Services;

use App\Domain\Contact\Entities\Contact;

class ContactEligibilityService
{
    public function isEligibleForPremium(Contact $contact): bool
    {
        return $this->hasMinimumInteractions($contact)
            && $this->hasActiveStatus($contact)
            && $this->hasCompleteProfile($contact);
    }

    private function hasMinimumInteractions(Contact $contact): bool
    {
        return count($contact->getInteractions()) >= 5;
    }

    private function hasActiveStatus(Contact $contact): bool
    {
        return $contact->isActive();
    }

    private function hasCompleteProfile(Contact $contact): bool
    {
        return $contact->hasEmail()
            && $contact->hasPhoneNumber()
            && $contact->hasAddress();
    }
}
```

### 2. Policy Pattern

```php
<?php

namespace App\Domain\Order\Services;

class RefundPolicyService
{
    public function canRefund(Order $order): bool
    {
        // Business rules for refunds
        if ($order->isCompleted() === false) {
            return false;
        }

        if ($order->getDaysSinceCompletion() > 30) {
            return false;
        }

        if ($order->isDigitalProduct()) {
            return false;
        }

        return true;
    }

    public function calculateRefundAmount(Order $order): Money
    {
        $daysSince = $order->getDaysSinceCompletion();

        // Full refund within 7 days
        if ($daysSince <= 7) {
            return $order->getTotal();
        }

        // 50% refund within 14 days
        if ($daysSince <= 14) {
            return $order->getTotal()->multiply(0.5);
        }

        // 25% refund within 30 days
        return $order->getTotal()->multiply(0.25);
    }
}
```

## Key Takeaways

- Domain Services contain domain logic that doesn't fit in entities
- Always stateless
- Coordinate between multiple aggregates
- Use domain language in naming
- Inject repositories and other dependencies
- Keep focused on domain concerns, not infrastructure
- Express significant domain concepts
