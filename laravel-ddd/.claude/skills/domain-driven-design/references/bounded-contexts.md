# Bounded Contexts in Domain-Driven Design

## What is a Bounded Context?

A **Bounded Context** is a central pattern in Domain-Driven Design that defines explicit boundaries around a domain model. Within these boundaries, terms have specific meanings, and the model is consistent and unified.

**Key characteristics:**
- Clear linguistic boundaries - terms mean specific things within the context
- Autonomous and independently deployable
- Owns its own data and business logic
- Has its own ubiquitous language
- Can be developed and scaled independently

## Why Bounded Contexts Matter

**Without bounded contexts:**
- Terms become ambiguous (does "Customer" mean the same in Sales vs Support?)
- Models become bloated with conflicting requirements
- Changes ripple unpredictably across the system
- Teams step on each other's toes

**With bounded contexts:**
- Clear ownership and responsibilities
- Independent development and deployment
- Reduced complexity within each context
- Explicit integration points
- Better team organization

## How to Identify Bounded Contexts

### 1. Linguistic Boundaries

Look for terms that mean different things in different parts of the business:

**Example: "Contact" in CRM**
- **Sales context**: Contact = potential customer with opportunity pipeline
- **Support context**: Contact = existing customer with support tickets
- **Billing context**: Contact = account holder with payment information

Each context has different responsibilities for the same concept.

### 2. Business Capabilities

Group functionality by what the business does:

**CRM System contexts:**
- **Contact Management**: Store and manage customer information
- **Sales**: Track opportunities and close deals
- **Support**: Handle customer issues and tickets
- **Billing**: Manage invoices and payments
- **Marketing**: Run campaigns and track engagement

Each capability is a candidate for a bounded context.

### 3. Team Organization

Align contexts with team structure:

**If you have:**
- Sales team → Sales context
- Support team → Support context
- Billing team → Billing context

This enables autonomous team ownership.

### 4. Change Patterns

Look for parts of the system that change together:

**E-commerce example:**
- **Catalog context**: Product information, categories, search
- **Order context**: Shopping cart, checkout, order processing
- **Inventory context**: Stock levels, warehousing, fulfillment
- **Shipping context**: Delivery, tracking, carriers

Products change independently of orders, orders change independently of shipping.

### 5. Data Ownership

Identify clear data ownership boundaries:

**CRM database tables:**
- **Contact context owns**: contacts, contact_details, contact_preferences
- **Sales context owns**: opportunities, pipeline_stages, forecasts
- **Billing context owns**: invoices, payments, subscriptions

No shared tables between contexts.

## Context Size and Scope

### Too Small
Contexts that are too small create unnecessary complexity:

```
❌ ContactBasicInfo context
❌ ContactAddress context
❌ ContactPreferences context

✓ Contact context (includes all of the above)
```

### Too Large
Contexts that are too large lose the benefits of DDD:

```
❌ CRM context (everything in one context)

✓ Contact context
✓ Sales context
✓ Support context
✓ Billing context
```

### Right-Sized
A context should:
- Represent a cohesive business capability
- Be manageable by a single team
- Have clear responsibilities
- Change independently of other contexts

## Ubiquitous Language Per Context

Each context has its own ubiquitous language:

### Contact Management Context

```php
namespace Domain\Contact\Entities;

// "Contact" in this context means a person/company we interact with
class Contact
{
    private string $id;
    private string $name;
    private string $email;
    private ContactStatus $status; // active, inactive, archived

    public function archive(): void
    {
        $this->status = ContactStatus::Archived;
    }
}
```

### Sales Context

```php
namespace Domain\Sales\Entities;

// "Contact" in this context is just an ID reference
// "Opportunity" is the main concept here
class Opportunity
{
    private string $id;
    private string $contactId; // Reference to Contact context
    private Money $estimatedValue;
    private PipelineStage $stage;

    public function moveToNextStage(): void
    {
        $this->stage = $this->stage->next();
    }
}
```

Notice: Each context has different concepts and terminology.

## When to Split Contexts

Split into separate contexts when:

1. **Different teams own different parts**
   - Sales team vs Support team vs Billing team

2. **Terms mean different things**
   - "Customer" means different things in different areas

3. **Different change rates**
   - Catalog changes frequently, Orders are stable

4. **Different scalability needs**
   - Search needs to scale differently than Checkout

5. **Different data consistency requirements**
   - Orders need strong consistency, Recommendations can be eventual

## When to Merge Contexts

Merge contexts when:

1. **They always change together**
   - If every Product change requires a Category change, they might belong together

2. **No clear linguistic boundary**
   - Terms mean the same thing in both contexts

3. **Same team ownership**
   - Same team maintains both contexts

4. **Excessive coupling**
   - Contexts constantly need data from each other

## CRM Example: Bounded Contexts

### Contact Management Context

**Responsibility:** Manage customer and contact information

**Entities:**
- Contact
- ContactDetails
- ContactPreferences

**Ubiquitous Language:**
- Contact: Person or company we interact with
- Archive: Mark contact as no longer active
- Preference: Contact's communication preferences

### Sales Context

**Responsibility:** Manage sales opportunities and pipeline

**Entities:**
- Opportunity
- Pipeline
- Forecast

**Ubiquitous Language:**
- Opportunity: Potential sale to a contact
- Stage: Position in sales pipeline (Lead, Qualified, Proposal, Closed)
- Forecast: Predicted revenue based on opportunities

### Support Context

**Responsibility:** Handle customer support requests

**Entities:**
- Ticket
- TicketComment
- SLA (Service Level Agreement)

**Ubiquitous Language:**
- Ticket: Customer issue or question
- Priority: Urgency level (Low, Medium, High, Critical)
- Resolve: Mark ticket as solved

### Billing Context

**Responsibility:** Manage invoices and payments

**Entities:**
- Invoice
- Payment
- Subscription

**Ubiquitous Language:**
- Invoice: Bill for services
- Payment: Money received from customer
- Subscription: Recurring billing arrangement

## Context Independence and Autonomy

Each bounded context should be:

### 1. Independently Deployable

```bash
# Can deploy Sales context without touching Contact context
deploy:sales
```

### 2. Own Its Data

```
Contact Context DB:
- contacts
- contact_details

Sales Context DB:
- opportunities
- pipeline_stages

No shared tables
```

### 3. Have Its Own API

```php
// Contact context exposes
GET /api/contacts/{id}
POST /api/contacts

// Sales context exposes
GET /api/opportunities/{id}
POST /api/opportunities
```

### 4. Make Independent Decisions

Sales context decides:
- How to structure opportunities
- What pipeline stages to use
- How to calculate forecasts

Without coordinating with Contact context.

## Example: Multi-Context Architecture

**Two Infrastructure organization patterns are available. Choose based on project scale:**

### Technical Organization (Small-Medium Projects, < 4 contexts)

```php
app/
├── Domain/
│   ├── Contact/              # Contact Management context
│   │   ├── Entities/
│   │   │   ├── Contact.php
│   │   │   └── ContactDetails.php
│   │   ├── Services/
│   │   │   └── ContactService.php
│   │   └── Repositories/
│   │       └── ContactRepositoryInterface.php
│   │
│   ├── Sales/                # Sales context
│   │   ├── Entities/
│   │   │   ├── Opportunity.php
│   │   │   └── Pipeline.php
│   │   ├── Services/
│   │   │   └── SalesService.php
│   │   └── Repositories/
│   │       └── OpportunityRepositoryInterface.php
│   │
│   └── Billing/              # Billing context
│       ├── Entities/
│       │   ├── Invoice.php
│       │   └── Payment.php
│       ├── Services/
│       │   └── BillingService.php
│       └── Repositories/
│           └── InvoiceRepositoryInterface.php
│
├── Application/
│   ├── Contact/
│   │   ├── UseCases/
│   │   └── DTOs/
│   ├── Sales/
│   │   ├── UseCases/
│   │   └── DTOs/
│   └── Billing/
│       ├── UseCases/
│       └── DTOs/
│
└── Infrastructure/           # ← TECHNICAL organization
    ├── Database/
    │   ├── Eloquent/        # All models together
    │   └── Repositories/    # All repository implementations together
    ├── Http/
    │   ├── Controllers/     # All controllers together
    │   └── Requests/        # All form requests together
    └── Integration/
        ├── Contact/         # Contact context gateway
        └── Sales/           # Sales context gateway
```

### Modular Organization (Large Projects, 7+ contexts, multiple teams)

```php
app/
├── Domain/
│   └── [Same as above]
│
├── Application/
│   └── [Same as above]
│
└── Infrastructure/           # ← MODULAR organization
    ├── Contact/             # Contact context infrastructure
    │   ├── Http/
    │   │   ├── Controllers/
    │   │   │   └── ContactController.php
    │   │   └── Requests/
    │   │       └── CreateContactRequest.php
    │   ├── Database/
    │   │   ├── Eloquent/
    │   │   │   └── ContactModel.php
    │   │   └── Repositories/
    │   │       └── EloquentContactRepository.php
    │   ├── Listeners/
    │   │   └── SendWelcomeEmailOnContactCreated.php
    │   └── Integration/
    │       └── CRM/          # Contact → External CRM
    │
    ├── Sales/               # Sales context infrastructure
    │   ├── Http/
    │   │   ├── Controllers/
    │   │   │   └── OpportunityController.php
    │   │   └── Requests/
    │   │       └── CreateOpportunityRequest.php
    │   ├── Database/
    │   │   ├── Eloquent/
    │   │   │   └── OpportunityModel.php
    │   │   └── Repositories/
    │   │       └── EloquentOpportunityRepository.php
    │   ├── Listeners/
    │   │   └── CreateOpportunityOnContactCreated.php
    │   └── Integration/
    │       └── Contact/      # Sales → Contact gateway
    │           ├── ContactGateway.php
    │           └── ContactTranslator.php
    │
    ├── Billing/             # Billing context infrastructure
    │   └── [same structure as above]
    │
    └── Shared/              # Truly shared infrastructure
        ├── Http/
        │   └── Middleware/  # Auth, CORS, rate limiting
        └── Providers/       # Service providers
```

**Benefits of Modular Organization:**
- ✅ Clear team ownership (Contact team owns Infrastructure/Contact/)
- ✅ No merge conflicts between teams
- ✅ Independent deployment possible
- ✅ Explicit context boundaries at all layers
- ✅ Integration dependencies visible (Sales/Integration/Contact/ shows Sales depends on Contact)

**See [infrastructure.md](infrastructure.md) for detailed guidance on choosing between patterns.**

## Best Practices

1. **Start with fewer, larger contexts** - Split later if needed
2. **Align with team structure** - One team per context ideally
3. **Use ubiquitous language** - Terms should be clear within context
4. **Make boundaries explicit** - Clear separation in code and data
5. **Integrate through events** - Prefer loose coupling
6. **Document context map** - Show relationships between contexts

## Common Pitfalls

- ❌ Sharing entities across contexts
- ❌ Sharing database tables across contexts
- ❌ Direct method calls between contexts
- ❌ Too many small contexts (over-fragmentation)
- ❌ One massive context (missing DDD benefits)

## Key Takeaways

- Bounded contexts define linguistic and model boundaries
- Identify contexts by business capabilities, teams, and terminology
- Each context is autonomous and independently deployable
- Contexts integrate through explicit, well-defined interfaces
- Right-sizing is critical - not too small, not too large
