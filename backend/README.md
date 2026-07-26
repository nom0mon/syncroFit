# SynchroFit Backend API

Laravel 12 REST API with Sanctum token authentication and MySQL 8.

## Requirements

- PHP 8.2+
- Composer 2.x
- MySQL 8.0+

## Setup

```bash
# Install dependencies
composer install

# Copy environment file and configure
cp .env.example .env
php artisan key:generate

# Create the database
mysql -u root -e "CREATE DATABASE synchrofit;"

# Run migrations
php artisan migrate

# Seed exercise library
php artisan db:seed

# Start the development server
php artisan serve
```

## Testing

Tests use SQLite in-memory for speed — no external database needed.

```bash
php artisan test
```

## API Response Format

All endpoints return a consistent JSON envelope:

```json
// Success (200 or 201)
{"success": true, "data": {...}, "message": "Optional message"}

// Error (4xx or 5xx)
{"success": false, "message": "Error description", "errors": null}

// Validation Error (422)
{"success": false, "message": "Validation failed", "errors": {"field": ["Error message"]}}
```

## Authentication

The API uses Laravel Sanctum for token-based auth. After login/register, include the token in subsequent requests:

```
Authorization: Bearer <token>
```
