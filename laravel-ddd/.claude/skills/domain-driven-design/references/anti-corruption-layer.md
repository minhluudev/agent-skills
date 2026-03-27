# Anti-Corruption Layer (ACL) in Domain-Driven Design

## What is an Anti-Corruption Layer?

An **Anti-Corruption Layer** is a protective barrier between a bounded context and external systems (or other bounded contexts). It translates external models to match the internal domain model, preventing external changes from "corrupting" the domain.

**Purpose:**
- Protect domain model from external influences
- Translate foreign models to domain language
- Isolate context from upstream changes
- Maintain domain purity and integrity
- Enable independent evolution

## Why Use ACL?

### Without ACL

```php
// ❌ Sales context directly using Contact entity
namespace Domain\Sales\Services;

use Domain\Contact\Entities\Contact; // Direct dependency

class OpportunityService
{
    public function create(string $contactId): Opportunity
    {
        $contact = Contact::find($contactId); // Coupled to Contact structure

        return new Opportunity(
            uniqid(),
            $contact->id,
            $contact->full_name, // If Contact changes this field, Sales breaks
            $contact->primary_email_address
        );
    }
}
```

**Problems:**
- ❌ Tight coupling to Contact entity structure
- ❌ Sales context breaks when Contact changes fields
- ❌ Can't evolve Sales independently
- ❌ Domain language polluted by external concepts

### With ACL

```php
// ✓ Sales context using ACL
namespace Domain\Sales\Services;

use Domain\Sales\ValueObjects\SalesContact;
use Infrastructure\Integration\Contact\ContactTranslator;

class OpportunityService
{
    public function __construct(
        private readonly ContactTranslator $contactTranslator
    ) {}

    public function create(string $contactId): Opportunity
    {
        // ACL translates Contact to SalesContact
        $salesContact = $this->contactTranslator->translate($contactId);

        return new Opportunity(
            uniqid(),
            $salesContact->contactId,
            $salesContact->displayName, // Sales context's own terminology
            $salesContact->email
        );
    }
}
```

**Benefits:**
- ✓ Loose coupling - Contact changes don't break Sales
- ✓ Sales uses its own domain language
- ✓ Independent evolution
- ✓ Protected domain model

## ACL Patterns

### 1. Adapter Pattern

Converts external interface to domain interface.

**Example: Third-party payment provider**

```php
// Domain interface
namespace Domain\Billing\Ports;

interface PaymentGatewayInterface
{
    public function charge(string $customerId, Money $amount): PaymentResult;
    public function refund(string $transactionId, Money $amount): PaymentResult;
}

// ACL Adapter for Stripe
namespace Infrastructure\Integration\Stripe;

use Domain\Billing\Ports\PaymentGatewayInterface;
use Domain\Billing\ValueObjects\Money;
use Domain\Billing\ValueObjects\PaymentResult;
use Stripe\StripeClient;

class StripePaymentAdapter implements PaymentGatewayInterface
{
    public function __construct(
        private readonly StripeClient $stripe
    ) {}

    public function charge(string $customerId, Money $amount): PaymentResult
    {
        try {
            // Translate domain Money to Stripe format
            $charge = $this->stripe->charges->create([
                'customer' => $customerId,
                'amount' => $amount->getCents(), // Stripe uses cents
                'currency' => strtolower($amount->getCurrency()), // Stripe uses lowercase
            ]);

            // Translate Stripe response to domain PaymentResult
            return new PaymentResult(
                success: $charge->status === 'succeeded',
                transactionId: $charge->id,
                message: $charge->status
            );
        } catch (\Stripe\Exception\ApiErrorException $e) {
            return new PaymentResult(
                success: false,
                transactionId: null,
                message: $e->getMessage()
            );
        }
    }

    public function refund(string $transactionId, Money $amount): PaymentResult
    {
        try {
            $refund = $this->stripe->refunds->create([
                'charge' => $transactionId,
                'amount' => $amount->getCents(),
            ]);

            return new PaymentResult(
                success: $refund->status === 'succeeded',
                transactionId: $refund->id,
                message: $refund->status
            );
        } catch (\Stripe\Exception\ApiErrorException $e) {
            return new PaymentResult(
                success: false,
                transactionId: null,
                message: $e->getMessage()
            );
        }
    }
}
```

**Usage in domain:**

```php
namespace Domain\Billing\Services;

use Domain\Billing\Ports\PaymentGatewayInterface;

class BillingService
{
    public function __construct(
        private readonly PaymentGatewayInterface $paymentGateway // Interface, not Stripe
    ) {}

    public function chargeCustomer(string $customerId, Money $amount): void
    {
        $result = $this->paymentGateway->charge($customerId, $amount);

        if (!$result->success) {
            throw new PaymentFailedException($result->message);
        }
    }
}
```

**Binding in ServiceProvider:**

```php
$this->app->bind(PaymentGatewayInterface::class, StripePaymentAdapter::class);
```

**Benefits:**
- Can swap Stripe for PayPal without changing domain
- Domain speaks its own language (Money, PaymentResult)
- External API changes isolated to adapter

### 2. Facade Pattern

Simplifies complex external interface to match domain needs.

**Example: Complex shipping API**

```php
// Complex third-party shipping service
namespace ThirdParty\Shipping;

class ComplexShippingService
{
    public function initializeShipment(...) { }
    public function setOrigin(...) { }
    public function setDestination(...) { }
    public function addPackage(...) { }
    public function calculateRates(...) { }
    public function selectCarrier(...) { }
    public function generateLabel(...) { }
    public function schedulePickup(...) { }
    // 20 more methods...
}

// ACL Facade simplifies interface
namespace Infrastructure\Integration\Shipping;

use Domain\Order\ValueObjects\Address;
use Domain\Order\ValueObjects\Package;

class ShippingFacade
{
    public function __construct(
        private readonly ComplexShippingService $shippingService
    ) {}

    public function ship(Address $from, Address $to, Package $package): string
    {
        // Facade hides complexity and translates to domain concepts
        $shipment = $this->shippingService->initializeShipment();

        $this->shippingService->setOrigin([
            'street' => $from->street,
            'city' => $from->city,
            'state' => $from->state,
            'zip' => $from->zipCode,
        ]);

        $this->shippingService->setDestination([
            'street' => $to->street,
            'city' => $to->city,
            'state' => $to->state,
            'zip' => $to->zipCode,
        ]);

        $this->shippingService->addPackage([
            'weight' => $package->weightInOunces(),
            'length' => $package->length,
            'width' => $package->width,
            'height' => $package->height,
        ]);

        $rates = $this->shippingService->calculateRates($shipment);
        $cheapestCarrier = $this->selectCheapestRate($rates);

        $this->shippingService->selectCarrier($shipment, $cheapestCarrier);
        $label = $this->shippingService->generateLabel($shipment);
        $this->shippingService->schedulePickup($shipment);

        return $label->trackingNumber;
    }

    private function selectCheapestRate(array $rates): string
    {
        // Internal logic hidden from domain
        return collect($rates)->sortBy('price')->first()['carrier_id'];
    }
}
```

**Domain uses simple interface:**

```php
namespace Domain\Order\Services;

class OrderFulfillmentService
{
    public function __construct(
        private readonly ShippingFacade $shipping
    ) {}

    public function fulfillOrder(Order $order): void
    {
        // Simple one-line call to complex shipping system
        $trackingNumber = $this->shipping->ship(
            $order->getWarehouseAddress(),
            $order->getShippingAddress(),
            $order->getPackage()
        );

        $order->markShipped($trackingNumber);
    }
}
```

### 3. Translator Pattern

Bidirectional conversion between external and domain models.

**Example: Contact context to Sales context**

```php
// Sales context's own Contact representation
namespace Domain\Sales\ValueObjects;

final readonly class SalesContact
{
    public function __construct(
        public string $contactId,
        public string $displayName,
        public string $email,
        public string $company,
        public string $phoneNumber
    ) {}
}

// Translator between Contact context and Sales context
namespace Infrastructure\Integration\Contact;

use Domain\Sales\ValueObjects\SalesContact;

class ContactTranslator
{
    public function __construct(
        private readonly ContactGateway $contactGateway
    ) {}

    /**
     * Translate Contact context data to Sales context model
     */
    public function translate(string $contactId): ?SalesContact
    {
        $externalContact = $this->contactGateway->getContact($contactId);

        if (!$externalContact) {
            return null;
        }

        return $this->toSalesContact($externalContact);
    }

    /**
     * Batch translation for performance
     */
    public function translateMany(array $contactIds): array
    {
        $externalContacts = $this->contactGateway->getContacts($contactIds);

        return array_map(
            fn($contact) => $this->toSalesContact($contact),
            $externalContacts
        );
    }

    private function toSalesContact(array $external): SalesContact
    {
        // Translation logic - Sales context doesn't see Contact context structure
        return new SalesContact(
            contactId: $external['id'],
            displayName: $this->formatDisplayName($external),
            email: $external['email'] ?? '',
            company: $external['company_name'] ?? 'Unknown',
            phoneNumber: $this->formatPhoneNumber($external)
        );
    }

    private function formatDisplayName(array $contact): string
    {
        // Sales prefers "Last, First" format
        if (isset($contact['last_name']) && isset($contact['first_name'])) {
            return "{$contact['last_name']}, {$contact['first_name']}";
        }

        return $contact['name'] ?? 'Unknown';
    }

    private function formatPhoneNumber(array $contact): string
    {
        // Standardize phone format for Sales context
        $phone = $contact['phone'] ?? '';

        // Remove non-digits
        $digits = preg_replace('/\D/', '', $phone);

        // Format as (XXX) XXX-XXXX
        if (strlen($digits) === 10) {
            return sprintf('(%s) %s-%s',
                substr($digits, 0, 3),
                substr($digits, 3, 3),
                substr($digits, 6)
            );
        }

        return $phone;
    }
}
```

**Usage in Sales context:**

```php
namespace Domain\Sales\Services;

class OpportunityService
{
    public function __construct(
        private readonly ContactTranslator $contactTranslator
    ) {}

    public function createOpportunity(string $contactId): Opportunity
    {
        $salesContact = $this->contactTranslator->translate($contactId);

        if (!$salesContact) {
            throw new ContactNotFoundException($contactId);
        }

        return new Opportunity(
            id: uniqid(),
            contactId: $salesContact->contactId,
            displayName: $salesContact->displayName,
            email: $salesContact->email
        );
    }
}
```

## Complete ACL Implementation Example

**Scenario:** Billing context integrating with external Stripe payment API

### Step 1: Define Domain Interface

```php
// Domain/Billing/Ports/PaymentGatewayInterface.php
namespace Domain\Billing\Ports;

use Domain\Billing\ValueObjects\Money;
use Domain\Billing\ValueObjects\PaymentResult;

interface PaymentGatewayInterface
{
    public function charge(string $customerId, Money $amount): PaymentResult;
    public function refund(string $transactionId, Money $amount): PaymentResult;
    public function createCustomer(string $email, string $name): string;
}
```

### Step 2: Define Domain Value Objects

```php
// Domain/Billing/ValueObjects/Money.php
namespace Domain\Billing\ValueObjects;

final readonly class Money
{
    public function __construct(
        private int $amount,
        private string $currency
    ) {}

    public function getCents(): int
    {
        return $this->amount;
    }

    public function getCurrency(): string
    {
        return $this->currency;
    }

    public function format(): string
    {
        return sprintf('$%.2f', $this->amount / 100);
    }
}

// Domain/Billing/ValueObjects/PaymentResult.php
namespace Domain\Billing\ValueObjects;

final readonly class PaymentResult
{
    public function __construct(
        public bool $success,
        public ?string $transactionId,
        public string $message
    ) {}
}
```

### Step 3: Implement ACL Adapter

```php
// Infrastructure/Integration/Stripe/StripePaymentAdapter.php
namespace Infrastructure\Integration\Stripe;

use Domain\Billing\Ports\PaymentGatewayInterface;
use Domain\Billing\ValueObjects\Money;
use Domain\Billing\ValueObjects\PaymentResult;
use Stripe\StripeClient;
use Stripe\Exception\ApiErrorException;

class StripePaymentAdapter implements PaymentGatewayInterface
{
    public function __construct(
        private readonly StripeClient $stripe
    ) {}

    public function charge(string $customerId, Money $amount): PaymentResult
    {
        try {
            $charge = $this->stripe->charges->create([
                'customer' => $customerId,
                'amount' => $amount->getCents(),
                'currency' => strtolower($amount->getCurrency()),
            ]);

            return new PaymentResult(
                success: $charge->status === 'succeeded',
                transactionId: $charge->id,
                message: $charge->status
            );
        } catch (ApiErrorException $e) {
            return new PaymentResult(
                success: false,
                transactionId: null,
                message: $e->getMessage()
            );
        }
    }

    public function refund(string $transactionId, Money $amount): PaymentResult
    {
        try {
            $refund = $this->stripe->refunds->create([
                'charge' => $transactionId,
                'amount' => $amount->getCents(),
            ]);

            return new PaymentResult(
                success: $refund->status === 'succeeded',
                transactionId: $refund->id,
                message: $refund->status
            );
        } catch (ApiErrorException $e) {
            return new PaymentResult(
                success: false,
                transactionId: null,
                message: $e->getMessage()
            );
        }
    }

    public function createCustomer(string $email, string $name): string
    {
        $customer = $this->stripe->customers->create([
            'email' => $email,
            'name' => $name,
        ]);

        return $customer->id;
    }
}
```

### Step 4: Use in Domain

```php
// Domain/Billing/Services/BillingService.php
namespace Domain\Billing\Services;

use Domain\Billing\Ports\PaymentGatewayInterface;
use Domain\Billing\ValueObjects\Money;

class BillingService
{
    public function __construct(
        private readonly PaymentGatewayInterface $paymentGateway
    ) {}

    public function chargeCustomer(string $customerId, Money $amount): void
    {
        $result = $this->paymentGateway->charge($customerId, $amount);

        if (!$result->success) {
            throw new PaymentFailedException($result->message);
        }

        // Domain logic continues...
    }
}
```

### Step 5: Bind in Service Provider

```php
// Infrastructure/Providers/IntegrationServiceProvider.php
namespace Infrastructure\Providers;

use Illuminate\Support\ServiceProvider;
use Domain\Billing\Ports\PaymentGatewayInterface;
use Infrastructure\Integration\Stripe\StripePaymentAdapter;
use Stripe\StripeClient;

class IntegrationServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->singleton(StripeClient::class, function () {
            return new StripeClient(config('services.stripe.secret'));
        });

        $this->app->bind(
            PaymentGatewayInterface::class,
            StripePaymentAdapter::class
        );
    }
}
```

## When to Use ACL

### Use ACL when:

1. **Integrating with external systems**
   - Third-party APIs (Stripe, Twilio, SendGrid)
   - Legacy systems
   - External microservices

2. **External model doesn't fit domain**
   - Different terminology
   - Different structure
   - Too complex or too simple

3. **Protection is critical**
   - Frequent external changes
   - Multiple integrations for same capability
   - Domain purity is important

4. **Long-term maintainability matters**
   - Large codebase
   - Team growing
   - System evolving

### Don't use ACL when:

1. **Conformist is acceptable**
   - External model is good enough
   - Changes are rare
   - Translation overhead not justified

2. **Simple integration**
   - One-time data fetch
   - Temporary integration
   - Prototype/MVP

3. **Internal shared kernel**
   - Well-coordinated teams
   - Small, stable shared model
   - Both contexts change together

## Best Practices

1. **Keep ACL in Infrastructure layer** - Not in Domain
2. **Domain defines interface** - ACL implements it
3. **Use value objects** - For translation targets
4. **Handle errors gracefully** - External systems fail
5. **Cache when appropriate** - Reduce external calls
6. **Monitor ACL performance** - Integration bottlenecks
7. **Version external contracts** - Track changes
8. **Test ACL thoroughly** - Mock external systems

## Common Pitfalls

- ❌ Putting ACL in Domain layer
- ❌ Leaking external models into domain
- ❌ Over-engineering simple integrations
- ❌ No error handling
- ❌ Tightly coupled to external structure
- ❌ Missing translation for new fields
- ❌ Not using interfaces (directly coupling to adapter)

## Key Takeaways

- ACL protects domain from external influences
- Use Adapter, Facade, or Translator patterns
- Domain defines interface, Infrastructure implements
- Essential for external systems and cross-context integration
- Enables independent evolution of bounded contexts
- Trade-off: complexity vs protection
- Keep ACL in Infrastructure layer
