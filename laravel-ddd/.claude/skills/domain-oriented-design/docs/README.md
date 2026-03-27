# Domain Oriented Design Skill

This skill implements **Domain Oriented Design (DOD)** for Laravel projects

## What is DOD?

DOD is **not** Domain Driven Design (DDD). It is a simpler, more practical approach:
- Place **business logic (Domain)** at the center of the application
- Keep Laravel's MVC intact, add a Domain layer on top
- Minimize coupling between business logic and infrastructure
- No need to learn complex DDD concepts like aggregates or value objects

## Architecture Layers

### Application Layer (MVC — standard Laravel)
- Controllers: Thin transport — receive request → call Action → return response
- Requests: Validation + convert to DTO
- Resources: Format response
- ViewModels *(optional)*: Prepare data for View/API

### Domain Layer (pure business logic)
- **Actions**: Each use-case is one class, one `handle()` method — the heart of the application
- **DTO**: Typed objects replacing raw arrays — IDE-friendly, type-safe, readable
- **Entities**: Plain PHP Objects representing business concepts (separate from Eloquent models)
- **Repositories**: Interface declaring the contract, unaware of any database
- **Exceptions**: Business-level exceptions
- **QueryBuilders** *(optional)*: Alternative to Repository for simpler projects

### Infrastructure Layer
- Models: Eloquent models interacting with the database
- Repositories: Eloquent implementation of Repository interfaces

## Components and When to Use Them

| Component | When to use | File |
|-----------|-------------|------|
| **Action** | Every business use-case | `Domain/{Domain}/Actions/{Name}Action.php` |
| **DTO** | Passing data between layers | `Domain/{Domain}/DTO/{Name}DTO.php` |
| **Entity** | Domain objects with identity | `Domain/{Domain}/Entities/{Name}Entity.php` |
| **Repository** | Large projects needing isolation | `Domain/{Domain}/Repositories/{Name}Repository.php` |
| **QueryBuilder** | Small/medium projects, replaces Repository | `Domain/{Domain}/QueryBuilders/{Name}QueryBuilder.php` |
| **ViewModel** | Complex data preparation for view/API | `Http/ViewModels/{Domain}/{Name}ViewModel.php` |
| **Exception** | Business errors with meaningful names | `Domain/{Domain}/Exceptions/{Name}Exception.php` |

## Core Principles

1. **Dependency Injection** — Composition over Inheritance. Inject dependencies via constructor.
2. **Single Responsibility** — Each Action handles one and only one business operation.
3. **No Eloquent in Domain** — Domain layer never imports Eloquent. Use Repository interface or QueryBuilder only.
4. **Typed Data** — Use DTO instead of raw arrays. IDE-friendly, type-safe, easier to read.
5. **Validation in Requests** — Never validate inside DTO or Entity.
6. **Actions describe User Stories** — Reading the list of Actions tells you the features of the system.

## Comparison with domain-driven-design skill

| | `domain-driven-design` | `domain-oriented-design` |
|---|---|---|
| Paradigm | DDD (more complex) | DOD (simpler, practical) |
| Action method | `execute()` | `handle()` |
| Entity | May extend base class | POJO — no extends |
| ViewModel | Not included | Included (optional) |
| QueryBuilder | Not included | Included (replaces Repository) |
| Domain Exceptions | Not included | Included |
| Best for | Pure DDD projects | Practical Laravel projects |
