# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Laravel project structured around Domain-Driven Design (DDD). The repository is in early stages — update this file as architecture and conventions are established.

## Common Commands

```bash
# Install dependencies
composer install

# Run development server
php artisan serve

# Run tests
php artisan test

# Run a single test file
php artisan test tests/Path/To/TestFile.php

# Run a single test method
php artisan test --filter=method_name

# Run migrations
php artisan migrate

# Lint / static analysis (if configured)
./vendor/bin/pint          # Laravel Pint (code style)
./vendor/bin/phpstan analyse  # PHPStan (static analysis)
```

## Architecture

This project follows DDD principles. As the codebase grows, document the domain boundaries, bounded contexts, and layer responsibilities here (e.g., how `Domain`, `Application`, `Infrastructure`, and `Presentation` layers are organized under `src/` or `app/`).
