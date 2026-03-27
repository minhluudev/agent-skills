# Aggregates in Domain-Driven Design

## What is an Aggregate?

An **Aggregate** is a cluster of domain objects (entities and value objects) that are treated as a single unit for data changes. One entity in the aggregate serves as the **Aggregate Root**, which is the only entry point for modifying the aggregate.

**Key characteristics:**
- Cluster of related objects
- Single entry point (Aggregate Root)
- Consistency boundary
- Transactional boundary
- Referenced from outside by ID only

## Why Aggregates Matter

### Without Aggregates

```php
// ❌ Direct manipulation of related entities
$contact = Contact::find($id);
$contact->email = 'new@email.com';
$contact->save();

$preferences = $contact->preferences;
$preferences->emailNotifications = false;
$preferences->save(); // Inconsistent state possible

// Contact updated but preferences not validated
```

**Problems:**
- ❌ No consistency guarantees
- ❌ Business rules can be bypassed
- ❌ Relationships can become invalid
- ❌ No clear transaction boundaries

### With Aggregates

```php
// ✓ Modification through Aggregate Root
$contact = $contactRepository->find($id);
$contact->updateEmail('new@email.com'); // Validates and updates
$contact->updateEmailNotificationPreference(false); // Maintains consistency
$contactRepository->save($contact); // Single transaction

// Contact aggregate ensures consistency
```

**Benefits:**
- ✓ Consistency guaranteed
- ✓ Business rules enforced
- ✓ Clear transaction boundary
- ✓ Encapsulated behavior

## Aggregate Root Pattern

The **Aggregate Root** is the main entity that:
- Controls access to the aggregate
- Enforces invariants (business rules)
- Manages lifecycle of contained objects
- Is the only object referenced from outside

### Example: Contact Aggregate

```php
// Domain/Contact/Entities/Contact.php
namespace Domain\Contact\Entities;

use Domain\Contact\ValueObjects\Email;
use Domain\Contact\ValueObjects\ContactPreferences;

/**
 * Contact is the Aggregate Root
 */
class Contact
{
    private string $id;
    private string $name;
    private Email $email;
    private ContactPreferences $preferences; // Part of aggregate
    private string $status;

    public function __construct(
        string $id,
        string $name,
        Email $email,
        ContactPreferences $preferences
    ) {
        $this->id = $id;
        $this->name = $name;
        $this->email = $email;
        $this->preferences = $preferences;
        $this->status = 'active';
    }

    // Aggregate Root controls all changes
    public function updateEmail(Email $newEmail): void
    {
        // Business rule: Can't change email for archived contacts
        if ($this->status === 'archived') {
            throw new \DomainException('Cannot update email for archived contact');
        }

        // Update email and sync preferences
        $this->email = $newEmail;

        // Ensure consistency: Update email in preferences too
        $this->preferences = $this->preferences->withEmail($newEmail);
    }

    public function updateEmailNotificationPreference(bool $enabled): void
    {
        // Access preferences only through aggregate root
        $this->preferences = $this->preferences->withEmailNotifications($enabled);
    }

    public function archive(): void
    {
        // Business rule: Must have no pending interactions
        if ($this->hasPendingInteractions()) {
            throw new \DomainException('Cannot archive contact with pending interactions');
        }

        $this->status = 'archived';
    }

    // Aggregate root exposes needed information
    public function getId(): string
    {
        return $this->id;
    }

    public function getName(): string
    {
        return $this->name;
    }

    public function getEmail(): Email
    {
        return $this->email;
    }

    // Preferences accessed through Contact, not directly
    public function wantsEmailNotifications(): bool
    {
        return $this->preferences->emailNotificationsEnabled();
    }

    private function hasPendingInteractions(): bool
    {
        // Logic to check for pending interactions
        return false;
    }
}
```

### Contained Objects

```php
// Domain/Contact/ValueObjects/ContactPreferences.php
namespace Domain\Contact\ValueObjects;

/**
 * ContactPreferences is part of Contact aggregate
 * Cannot be modified directly, only through Contact aggregate root
 */
final readonly class ContactPreferences
{
    private function __construct(
        private Email $email,
        private bool $emailNotifications,
        private bool $smsNotifications,
        private string $preferredContactMethod
    ) {}

    public static function create(Email $email): self
    {
        return new self(
            email: $email,
            emailNotifications: true,
            smsNotifications: false,
            preferredContactMethod: 'email'
        );
    }

    public function withEmail(Email $email): self
    {
        return new self(
            $email,
            $this->emailNotifications,
            $this->smsNotifications,
            $this->preferredContactMethod
        );
    }

    public function withEmailNotifications(bool $enabled): self
    {
        return new self(
            $this->email,
            $enabled,
            $this->smsNotifications,
            $this->preferredContactMethod
        );
    }

    public function emailNotificationsEnabled(): bool
    {
        return $this->emailNotifications;
    }
}
```

## Transactional Consistency Boundaries

Aggregates define **transaction boundaries**:

### Rule: One Aggregate Per Transaction

```php
// ✓ Correct: Single aggregate in transaction
public function updateContactEmail(string $contactId, string $newEmail): void
{
    DB::transaction(function () use ($contactId, $newEmail) {
        $contact = $this->contactRepository->find($contactId);
        $contact->updateEmail(Email::fromString($newEmail));
        $this->contactRepository->save($contact);
    });
}
```

### Rule: Multiple Aggregates = Eventual Consistency

```php
// Multiple aggregates affected? Use eventual consistency via events
public function closeOpportunity(string $opportunityId): void
{
    DB::transaction(function () use ($opportunityId) {
        $opportunity = $this->opportunityRepository->find($opportunityId);
        $opportunity->close();
        $this->opportunityRepository->save($opportunity);

        // Don't update Contact aggregate in same transaction
        // Instead, dispatch event
        Event::dispatch(new OpportunityClosed($opportunity->getId(), $opportunity->getContactId()));
    });
}

// Separate transaction handles Contact update
class UpdateContactWhenOpportunityClosed
{
    public function handle(OpportunityClosed $event): void
    {
        DB::transaction(function () use ($event) {
            $contact = $this->contactRepository->find($event->contactId);
            $contact->recordSale();
            $this->contactRepository->save($contact);
        });
    }
}
```

## Aggregate Design Rules

### 1. Small Aggregates Preferred

**Large aggregate (Anti-pattern):**

```php
// ❌ Too large - includes too many entities
class Order // Aggregate root
{
    private OrderId $id;
    private Customer $customer; // Separate aggregate!
    private Collection $orderLines;
    private Payment $payment; // Separate aggregate!
    private Shipment $shipment; // Separate aggregate!
    private Collection $invoices; // Separate aggregate!

    // Hard to maintain, poor performance
}
```

**Small aggregate (Better):**

```php
// ✓ Right-sized aggregate
class Order // Aggregate root
{
    private OrderId $id;
    private CustomerId $customerId; // Reference by ID
    private Collection $orderLines; // Part of aggregate
    private OrderStatus $status;

    public function addOrderLine(Product $product, int $quantity): void
    {
        // Business rule: Can't modify completed orders
        if ($this->status->isCompleted()) {
            throw new \DomainException('Cannot modify completed order');
        }

        $this->orderLines->add(new OrderLine($product->getId(), $quantity, $product->getPrice()));
    }
}

class Payment // Separate aggregate
{
    private PaymentId $id;
    private OrderId $orderId; // Reference by ID
    private Money $amount;
    private PaymentStatus $status;
}
```

### 2. Reference Other Aggregates by ID

```php
// ✓ Correct: Reference by ID
class Opportunity
{
    private string $id;
    private string $contactId; // ID reference, not Contact entity

    public function getContactId(): string
    {
        return $this->contactId;
    }
}

// ❌ Wrong: Direct entity reference
class Opportunity
{
    private string $id;
    private Contact $contact; // Don't hold entire entity

    public function getContact(): Contact
    {
        return $this->contact; // Violates aggregate boundary
    }
}
```

### 3. Use Eventual Consistency Between Aggregates

When changes span multiple aggregates, use domain events:

```php
// Scenario: Contact created → Opportunity created

// Step 1: Contact aggregate (Transaction 1)
class ContactService
{
    public function createContact(string $name, string $email): Contact
    {
        DB::transaction(function () use ($name, $email) {
            $contact = new Contact(uniqid(), $name, Email::fromString($email));
            $this->contactRepository->save($contact);

            // Dispatch event - don't create Opportunity in same transaction
            Event::dispatch(new ContactCreated($contact->getId(), $contact->getName()));
        });
    }
}

// Step 2: Opportunity aggregate (Transaction 2)
class CreateOpportunityWhenContactCreated
{
    public function handle(ContactCreated $event): void
    {
        DB::transaction(function () use ($event) {
            $opportunity = new Opportunity(
                uniqid(),
                $event->contactId,
                "Opportunity for {$event->name}"
            );
            $this->opportunityRepository->save($opportunity);
        });
    }
}
```

**Result:** Eventual consistency - Contact created first, Opportunity shortly after.

### 4. Enforce Invariants Within Aggregate

Invariants (business rules) enforced by aggregate root:

```php
class Order
{
    private Collection $orderLines;
    private OrderStatus $status;
    private Money $totalAmount;

    // Invariant: Order total must equal sum of line items
    public function addOrderLine(OrderLine $line): void
    {
        $this->orderLines->add($line);
        $this->recalculateTotal(); // Maintain invariant
    }

    public function removeOrderLine(OrderLineId $lineId): void
    {
        $this->orderLines->remove($lineId);
        $this->recalculateTotal(); // Maintain invariant
    }

    private function recalculateTotal(): void
    {
        $total = $this->orderLines->sum(fn($line) => $line->getTotal());
        $this->totalAmount = new Money($total, 'USD');
    }

    // Invariant: Can't ship empty order
    public function ship(): void
    {
        if ($this->orderLines->isEmpty()) {
            throw new \DomainException('Cannot ship empty order');
        }

        $this->status = OrderStatus::shipped();
    }
}
```

## Aggregate Lifecycle Management

### Creation

```php
// Factory method for complex creation
class Order
{
    public static function create(CustomerId $customerId, ShippingAddress $address): self
    {
        $order = new self(
            OrderId::generate(),
            $customerId,
            $address,
            OrderStatus::pending()
        );

        // Dispatch domain event
        $order->recordEvent(new OrderCreated($order->getId()));

        return $order;
    }
}
```

### Retrieval

```php
// Repository returns full aggregate
interface OrderRepositoryInterface
{
    public function find(OrderId $id): ?Order;
    public function save(Order $order): void;
}

// Correct: Load full aggregate
$order = $orderRepository->find($orderId);
$order->addOrderLine($line);
$orderRepository->save($order); // Saves entire aggregate
```

### Modification

```php
// All modifications through aggregate root
$order = $orderRepository->find($orderId);
$order->addOrderLine($line); // Aggregate root method
$order->applyDiscount($discount); // Aggregate root method
$orderRepository->save($order);
```

### Deletion

```php
// Soft delete or status change preferred
$order = $orderRepository->find($orderId);
$order->cancel(); // Changes status rather than hard delete
$orderRepository->save($order);

// Hard delete if necessary
$orderRepository->delete($orderId);
```

## Cross-Context Aggregate References

When aggregates span bounded contexts:

```php
// Sales context
class Opportunity
{
    private string $id;
    private string $contactId; // Reference to Contact in different context

    public function getContactDetails(): SalesContact
    {
        // Use Anti-Corruption Layer to fetch contact
        return $this->contactTranslator->translate($this->contactId);
    }
}
```

**Rule:** Reference by ID, fetch via gateway/translator when needed.

## Aggregate vs Entity

| Aspect | Aggregate | Entity |
|--------|-----------|--------|
| Purpose | Consistency boundary | Object with identity |
| Access | Through root only | Can be accessed directly (if not in aggregate) |
| Transactions | One aggregate per transaction | Many entities in transaction if in same aggregate |
| References | By ID from outside | Part of aggregate if inside |

**Example:**
- `Order` is an Aggregate Root
- `OrderLine` is an Entity within Order aggregate
- `Customer` is a separate Aggregate Root
- Order references Customer by ID

## CRM Example: Contact Aggregate

```php
namespace Domain\Contact\Entities;

/**
 * Contact Aggregate
 *
 * Aggregate Root: Contact
 * Contained Objects: ContactPreferences, ContactDetails
 * Referenced by ID: Interactions (separate aggregate)
 */
class Contact
{
    private string $id;
    private string $name;
    private Email $email;
    private ContactPreferences $preferences;
    private ContactDetails $details;
    private string $status;

    // Factory method
    public static function create(string $name, Email $email): self
    {
        $contact = new self(
            uniqid(),
            $name,
            $email,
            ContactPreferences::create($email),
            ContactDetails::empty(),
            'active'
        );

        return $contact;
    }

    // Modify preferences through aggregate root
    public function updatePreferences(bool $emailNotifications, bool $smsNotifications): void
    {
        $this->preferences = $this->preferences
            ->withEmailNotifications($emailNotifications)
            ->withSmsNotifications($smsNotifications);
    }

    // Modify details through aggregate root
    public function updatePhoneNumber(string $phoneNumber): void
    {
        $this->details = $this->details->withPhoneNumber($phoneNumber);
    }

    // Business logic
    public function archive(): void
    {
        if ($this->hasActiveOpportunities()) {
            throw new \DomainException('Cannot archive contact with active opportunities');
        }

        $this->status = 'archived';
    }

    private function hasActiveOpportunities(): bool
    {
        // Check via repository or event
        return false;
    }
}
```

**Contact aggregate includes:**
- Contact (root)
- ContactPreferences
- ContactDetails

**Separate aggregates:**
- Opportunity (references Contact by ID)
- Interaction (references Contact by ID)

## Best Practices

1. **Keep aggregates small** - Prefer smaller aggregates
2. **One aggregate per transaction** - Use events for multiple aggregates
3. **Reference by ID** - Don't hold references to other aggregates
4. **Eventual consistency** - Between aggregates
5. **Enforce invariants** - Within aggregate boundaries
6. **Modify through root** - All changes via aggregate root
7. **Design around business** - Aggregate = business transaction unit

## Common Pitfalls

- ❌ Aggregates too large (performance issues)
- ❌ Modifying contained objects directly (bypassing root)
- ❌ Multiple aggregates in single transaction (tight coupling)
- ❌ Holding entity references across aggregates (memory issues)
- ❌ No clear aggregate root (unclear boundaries)
- ❌ Enforcing invariants outside aggregate (business logic leakage)

## Key Takeaways

- Aggregates are consistency and transaction boundaries
- Aggregate root is the only entry point for changes
- Keep aggregates small for performance and maintainability
- Reference other aggregates by ID only
- Use eventual consistency between aggregates via events
- One aggregate per transaction is the rule
- Aggregate root enforces all business rules for the aggregate
- Design aggregates around business transaction boundaries
