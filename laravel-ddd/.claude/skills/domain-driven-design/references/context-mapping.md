# Context Mapping in Domain-Driven Design

## What is a Context Map?

A **Context Map** is a visual representation showing the relationships and integration patterns between bounded contexts in a system. It makes explicit how contexts depend on each other and how they communicate.

**Purpose:**
- Visualize context dependencies
- Document integration patterns
- Identify upstream/downstream relationships
- Guide architectural decisions
- Facilitate team communication

## Upstream/Downstream Relationships

### Upstream Context
- Provides data or services
- Changes independently
- Little influence from downstream
- Example: Contact Management providing contact data to Sales

### Downstream Context
- Consumes data or services
- Affected by upstream changes
- Must adapt to upstream decisions
- Example: Sales consuming contact data from Contact Management

### Visualizing Relationships

```
Contact Management (Upstream)
        ↓
    Sales (Downstream)
        ↓
    Billing (Downstream)
```

## Context Mapping Patterns

### 1. Partnership Pattern

**Definition:** Two contexts in a partnership have a mutual dependency and must coordinate planning and development.

**When to use:**
- Both teams need features from each other
- Coordinated releases are acceptable
- Strong collaboration between teams

**Characteristics:**
- Bidirectional dependency
- Joint planning required
- Synchronized releases
- Mutual benefit

**Example: Sales ↔ Marketing**

```php
// Sales context needs Marketing campaigns
namespace Domain\Sales\Services;

class OpportunityService
{
    public function __construct(
        private readonly MarketingCampaignService $marketingService
    ) {}

    public function createFromCampaign(string $campaignId): Opportunity
    {
        // Sales depends on Marketing
        $campaign = $this->marketingService->getCampaign($campaignId);
        // Create opportunity from campaign
    }
}

// Marketing context needs Sales feedback
namespace Domain\Marketing\Services;

class CampaignService
{
    public function __construct(
        private readonly SalesConversionService $salesService
    ) {}

    public function trackPerformance(string $campaignId): CampaignMetrics
    {
        // Marketing depends on Sales
        $conversions = $this->salesService->getConversions($campaignId);
        // Calculate campaign ROI
    }
}
```

**Context Map:**
```
Sales ←→ Marketing
(Partnership)
```

### 2. Shared Kernel Pattern

**Definition:** Two contexts share a subset of the domain model. The shared part requires careful coordination.

**When to use:**
- Small, well-defined shared concepts
- Strong coordination between teams acceptable
- Cost of duplication > cost of coordination

**Characteristics:**
- Shared code/models between contexts
- Changes require both teams' approval
- Typically value objects or common entities
- Minimize shared surface area

**Example: Shared Address Value Object**

```php
// Shared between Contact and Billing contexts
namespace Domain\Shared\ValueObjects;

final readonly class Address
{
    public function __construct(
        public string $street,
        public string $city,
        public string $state,
        public string $zipCode,
        public string $country
    ) {}

    public function equals(Address $other): bool
    {
        return $this->street === $other->street
            && $this->city === $other->city
            && $this->state === $other->state
            && $this->zipCode === $other->zipCode
            && $this->country === $other->country;
    }

    public function format(): string
    {
        return "{$this->street}, {$this->city}, {$this->state} {$this->zipCode}, {$this->country}";
    }
}
```

**Usage in Contact context:**
```php
namespace Domain\Contact\Entities;

use Domain\Shared\ValueObjects\Address;

class Contact
{
    private Address $mailingAddress;
    // ...
}
```

**Usage in Billing context:**
```php
namespace Domain\Billing\Entities;

use Domain\Shared\ValueObjects\Address;

class Invoice
{
    private Address $billingAddress;
    // ...
}
```

**Context Map:**
```
Contact ←→ Shared Kernel ←→ Billing
      (Address, Email, Phone)
```

**Warning:** Keep shared kernel minimal. Too much sharing defeats the purpose of bounded contexts.

### 3. Customer-Supplier Pattern

**Definition:** Downstream context (customer) depends on upstream context (supplier). Downstream can influence upstream priorities through requests/negotiation.

**When to use:**
- Clear provider/consumer relationship
- Downstream needs influence upstream
- Formal planning between teams
- Upstream serves multiple downstreams

**Characteristics:**
- Upstream provides services/APIs
- Downstream influences upstream roadmap
- Regular planning meetings
- SLAs or contracts between teams

**Example: Contact Management (Supplier) → Sales (Customer)**

```php
// Contact context (upstream/supplier) provides API
namespace Infrastructure\Http\Controllers;

class ContactApiController extends Controller
{
    public function __construct(
        private readonly GetContactUseCase $getContact
    ) {}

    // API endpoint for downstream consumers
    public function show(string $id): JsonResponse
    {
        $contact = $this->getContact->execute($id);

        return response()->json([
            'id' => $contact->getId(),
            'name' => $contact->getName(),
            'email' => $contact->getEmail(),
            'status' => $contact->getStatus(),
        ]);
    }
}

// Sales context (downstream/customer) consumes API
namespace Infrastructure\Integration\Contact;

use Illuminate\Support\Facades\Http;

class ContactGateway
{
    public function __construct(
        private readonly string $contactApiUrl
    ) {}

    public function getContact(string $id): ?array
    {
        $response = Http::get("{$this->contactApiUrl}/contacts/{$id}");

        if ($response->failed()) {
            return null;
        }

        return $response->json();
    }
}
```

**Context Map:**
```
Contact Management (Supplier/Upstream)
        ↓ API
    Sales (Customer/Downstream)
```

**Process:**
- Sales team requests new API features from Contact team
- Contact team prioritizes based on all customers' needs
- Regular sync meetings to align on roadmap

### 4. Conformist Pattern

**Definition:** Downstream context completely conforms to the upstream model without translation.

**When to use:**
- Upstream model is good enough
- Cost of translation not justified
- Upstream changes infrequently
- Small downstream context

**Characteristics:**
- No translation layer
- Directly uses upstream models
- Simpler but more coupling
- Vulnerable to upstream changes

**Example: Billing conforms to Contact**

```php
// Billing context uses Contact model directly
namespace Domain\Billing\Services;

use Domain\Contact\Entities\Contact; // Direct import from Contact context

class InvoiceService
{
    public function createInvoice(Contact $contact, Money $amount): Invoice
    {
        // Directly using Contact entity from upstream context
        return new Invoice(
            uniqid(),
            $contact->getId(),
            $contact->getName(), // Using Contact's structure directly
            $contact->getEmail(),
            $amount
        );
    }
}
```

**Context Map:**
```
Contact Management (Upstream)
        ↓ Conformist
    Billing (Downstream - conforms to Contact model)
```

**Trade-offs:**
- ✓ Simpler (no translation)
- ✓ Less code to maintain
- ✗ Tightly coupled
- ✗ Upstream changes break downstream

### 5. Anti-Corruption Layer (ACL) Pattern

**Definition:** Downstream context uses a translation layer to protect itself from upstream changes and foreign models.

**When to use:**
- Upstream model doesn't fit downstream needs
- Protecting from upstream changes is critical
- Integrating with external/legacy systems
- Downstream model should remain pure

**Characteristics:**
- Translation/adapter layer
- Isolates downstream from upstream
- More code but less coupling
- Recommended for most integrations

**Example: Sales using ACL to protect from Contact changes**

```php
// Sales context defines its own Contact representation
namespace Domain\Sales\ValueObjects;

final readonly class SalesContact
{
    public function __construct(
        public string $contactId,
        public string $fullName,
        public string $emailAddress
    ) {}
}

// Anti-Corruption Layer translates Contact to SalesContact
namespace Infrastructure\Integration\Contact;

use Domain\Sales\ValueObjects\SalesContact;

class ContactTranslator
{
    public function __construct(
        private readonly ContactGateway $gateway
    ) {}

    public function getAsContact(string $contactId): ?SalesContact
    {
        $rawContact = $this->gateway->getContact($contactId);

        if (!$rawContact) {
            return null;
        }

        // Translation layer protects Sales context from Contact structure
        return new SalesContact(
            contactId: $rawContact['id'],
            fullName: $rawContact['name'],
            emailAddress: $rawContact['email']
        );
    }
}

// Sales context uses its own model
namespace Domain\Sales\Services;

use Infrastructure\Integration\Contact\ContactTranslator;

class OpportunityService
{
    public function __construct(
        private readonly ContactTranslator $contactTranslator
    ) {}

    public function createOpportunity(string $contactId): Opportunity
    {
        $salesContact = $this->contactTranslator->getAsContact($contactId);
        // Sales works with SalesContact, not Contact entity
    }
}
```

**Context Map:**
```
Contact Management (Upstream)
        ↓ ACL
    Sales (Downstream - protected by translation layer)
```

See [anti-corruption-layer.md](anti-corruption-layer.md) for detailed ACL patterns.

### 6. Open Host Service Pattern

**Definition:** Upstream context defines a protocol/API for access, making it easy for multiple downstreams to integrate.

**When to use:**
- Multiple downstream consumers
- Public API or service
- Well-defined integration protocol
- Versioned API contract

**Characteristics:**
- Standardized API/protocol
- Documentation for consumers
- Versioning strategy
- Often RESTful or GraphQL

**Example: Contact Management as Open Host**

```php
// Contact context provides versioned REST API
namespace Infrastructure\Http\Controllers\Api\V1;

class ContactController extends Controller
{
    /**
     * @api {get} /api/v1/contacts/:id Get Contact
     * @apiVersion 1.0.0
     * @apiName GetContact
     * @apiGroup Contact
     */
    public function show(string $id): JsonResponse
    {
        // Standardized API response
        return response()->json([
            'data' => [
                'id' => $contact->getId(),
                'type' => 'contact',
                'attributes' => [
                    'name' => $contact->getName(),
                    'email' => $contact->getEmail(),
                ],
            ],
        ]);
    }
}
```

**Context Map:**
```
        Contact Management (Open Host Service)
                    ↓ REST API
        ┌───────────┼───────────┐
        ↓           ↓           ↓
     Sales      Support     Billing
```

### 7. Published Language Pattern

**Definition:** Contexts integrate using a shared, well-documented data format or protocol.

**When to use:**
- Industry standard formats (JSON-LD, XML schemas)
- Multiple systems need same format
- Stable, documented protocol
- Often combined with Open Host Service

**Characteristics:**
- Standardized data format
- Comprehensive documentation
- Version management
- Often industry standard

**Example: Contact events using CloudEvents specification**

```php
namespace Infrastructure\Integration\Events;

/**
 * CloudEvents specification v1.0
 * https://cloudevents.io/
 */
class ContactCreatedEvent
{
    public function __construct(
        public readonly string $specversion = '1.0',
        public readonly string $type = 'com.crm.contact.created.v1',
        public readonly string $source = '/contacts',
        public readonly string $id,
        public readonly string $time,
        public readonly array $data
    ) {}

    public function toCloudEvent(): array
    {
        return [
            'specversion' => $this->specversion,
            'type' => $this->type,
            'source' => $this->source,
            'id' => $this->id,
            'time' => $this->time,
            'datacontenttype' => 'application/json',
            'data' => $this->data,
        ];
    }
}
```

### 8. Separate Ways Pattern

**Definition:** No integration between contexts. Each goes its own way.

**When to use:**
- No business value in integration
- Cost > benefit
- Truly independent capabilities
- Temporary state during migration

**Characteristics:**
- No dependencies
- Complete independence
- Possible data duplication
- Simplest but limits functionality

**Example: Internal Tools context and Core Business context**

```
Core Business (CRM)
    (no integration)

Internal Tools (Time Tracking, Expenses)
    (no integration)
```

No code sharing, no API calls, completely separate.

## CRM System Context Map Example

### Full Context Map

```
Contact Management (Open Host Service - Upstream)
    ↓ REST API (Customer-Supplier)
    ├→ Sales (Customer - uses ACL)
    │   ↓ Domain Events
    │   └→ Billing (Conformist)
    │
    ↓ REST API (Customer-Supplier)
    └→ Support (Customer - uses ACL)

Marketing ←→ Sales (Partnership)

Shared Kernel: Address, Email, Phone ValueObjects
    ├→ Contact uses
    ├→ Sales uses
    └→ Billing uses
```

### Relationships Explained

1. **Contact Management → Sales**
   - Pattern: Customer-Supplier + ACL
   - Sales requests features from Contact
   - Sales uses ACL to protect from Contact changes

2. **Sales → Billing**
   - Pattern: Conformist + Event-driven
   - Billing conforms to Sales models
   - Billing listens to OpportunityClosed events

3. **Contact Management → Support**
   - Pattern: Customer-Supplier + ACL
   - Support requests features from Contact
   - Support uses ACL for ticket integration

4. **Sales ↔ Marketing**
   - Pattern: Partnership
   - Bidirectional dependency
   - Coordinated planning for campaign→opportunity flow

5. **Shared Kernel**
   - Pattern: Shared Kernel
   - Address, Email, Phone shared across contexts
   - Small, stable value objects

## Choosing the Right Pattern

| Pattern | Coupling | Complexity | Independence | Use When |
|---------|----------|------------|--------------|----------|
| Partnership | High | Medium | Low | Mutual dependency, coordinated teams |
| Shared Kernel | High | Low | Low | Small shared concepts, tight coordination |
| Customer-Supplier | Medium | Medium | Medium | Clear provider/consumer, influence possible |
| Conformist | Medium | Low | Low | Upstream model acceptable, simplicity valued |
| ACL | Low | High | High | Protection critical, upstream model doesn't fit |
| Open Host | Low | Medium | High | Multiple consumers, public API |
| Published Language | Low | Medium | High | Industry standards, broad integration |
| Separate Ways | None | Low | Highest | No integration value |

## Best Practices

1. **Document your context map** - Keep it up to date
2. **Make integration explicit** - No hidden dependencies
3. **Prefer loose coupling** - Use ACL and events when possible
4. **Minimize shared kernel** - Keep it small and stable
5. **Version your APIs** - Support multiple downstream versions
6. **Regular reviews** - Context maps evolve with the system

## Common Pitfalls

- ❌ No context map (implicit relationships)
- ❌ Too much shared kernel (defeats bounded contexts)
- ❌ Conformist when ACL is needed (tight coupling)
- ❌ Partnership everywhere (coordination overhead)
- ❌ Direct database access between contexts

## Key Takeaways

- Context maps visualize bounded context relationships
- Eight patterns from tight coupling (Partnership) to no integration (Separate Ways)
- Upstream/downstream defines who depends on whom
- Choose patterns based on coupling tolerance, complexity, and independence needs
- ACL recommended for most integrations to protect domain purity
- Document and maintain your context map as architecture evolves
