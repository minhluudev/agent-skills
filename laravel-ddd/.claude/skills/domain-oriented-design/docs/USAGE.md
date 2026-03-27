# Using the Domain Oriented Design Skill

## Activating the skill

Type `/domain-oriented-design` or describe your request in English. The skill will automatically detect what to generate.

---

## Common commands

### Scaffold a full feature
```
scaffold full feature for Product domain with CreateProductDTO fields name:string, price:float, category_id:int
```
Generates: DTO → Entity → Repository interface → RepositoryEloquent → Action → Request → Resource → Controller, and updates RepositoryServiceProvider.

### Create an Action
```
create action CreateProduct for Product domain with CreateProductDTO
create action UpdateOrder for Order domain with UpdateOrderDTO
```

### Create a DTO
```
generate DTO CreateProductDTO with fields name:string, price:float, is_active:bool
```

### Create an Entity
```
create entity Product with fields id:int, name:string, price:float
```

### Create a Repository
```
create repository for Product domain
create repository ProductRepository with method findBySlug
```

### Create a Controller
```
generate controller for Product domain V1
generate controller CreateProductController for Product domain V2
```

### Create a ViewModel
```
create ViewModel ProductViewModel for Product domain
```

### Create a QueryBuilder (alternative to Repository for simpler projects)
```
create QueryBuilder ProductQueryBuilder for Product domain
```

### Create a Domain Exception
```
create exception ProductNotFoundException for Product domain
```

---

## Real workflow examples

### 1. Order placement feature (Order domain)

```
scaffold full feature for Order domain with CreateOrderDTO fields user_id:int, product_id:int, quantity:int, note:string
```

Output:
```
laravel-app/app/
├── Domain/Order/
│   ├── Actions/CreateOrderAction.php
│   ├── DTO/CreateOrderDTO.php
│   ├── Entities/OrderEntity.php
│   └── Repositories/OrderRepository.php
├── Http/
│   ├── Controllers/Api/V1/Order/CreateOrderController.php
│   ├── Requests/Order/CreateOrderRequest.php
│   └── Resources/Order/OrderResource.php
└── Infrastructures/Repositories/OrderRepositoryEloquent.php
```

### 2. Action calling another Action (Composition)
```
create action CreateOrder for Order domain, this action also calls ImportInventoryAction
```

### 3. Using QueryBuilder instead of Repository (simple project)
```
create QueryBuilder ProductQueryBuilder for Product domain with methods whereActive and whereByCategory
```

---

## Supported field types

| Type | PHP Type |
|------|----------|
| `string` | `string` |
| `int` | `int` |
| `float` | `float` |
| `bool` | `bool` |
| `array` | `array` |
| `?string` | `?string` (nullable) |
| `?int` | `?int` (nullable) |

---

## Naming conventions

| Component | Convention | Example |
|-----------|-----------|---------|
| Action | `{Verb}{Noun}Action` | `CreateProductAction` |
| DTO | `{Verb}{Noun}DTO` | `CreateProductDTO` |
| Entity | `{Noun}Entity` | `ProductEntity` |
| Repository (interface) | `{Noun}Repository` | `ProductRepository` |
| Repository (impl) | `{Noun}RepositoryEloquent` | `ProductRepositoryEloquent` |
| Controller | `{Verb}{Noun}Controller` | `CreateProductController` |
| Request | `{Verb}{Noun}Request` | `CreateProductRequest` |
| Resource | `{Noun}Resource` | `ProductResource` |
| ViewModel | `{Noun}ViewModel` | `ProductViewModel` |
| QueryBuilder | `{Noun}QueryBuilder` | `ProductQueryBuilder` |
| Exception | `{Description}Exception` | `ProductNotFoundException` |

---

## After creating a Repository

Register the binding in `laravel-app/app/Providers/RepositoryServiceProvider.php`:

```php
protected array $repositories = [
    UserRepository::class => UserRepositoryEloquent::class,
    ProductRepository::class => ProductRepositoryEloquent::class,  // add this line
];
```

The skill will automatically read and update this file when scaffolding a full feature.
