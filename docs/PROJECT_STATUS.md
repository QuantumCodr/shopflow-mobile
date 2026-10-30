# ShopFlow Project Status

**Review date:** 30 October 2026  
**Repository:** `QuantumCodr/shopflow-mobile`  
**Branch reviewed:** `main`  
**Project stage:** Active development

## 1. Project Overview

ShopFlow is a Flutter application for managing everyday retail shop activities.

The current application includes authentication, shop setup, product and category management, inventory, Point of Sale, sales history, reports and settings.

The application has a working feature structure and a consolidated V1 database definition. However, the presence of screens, repositories or database functions does not automatically establish that every workflow is fully operational.

This document distinguishes implemented code from integration and testing work that remains outstanding.

## 2. Application Feature Status

| Feature | Current implementation | Remaining verification |
|---|---|---|
| Authentication | Registration, sign-in, signup confirmation and password management. | Complete password recovery testing on Android and web. |
| Shop setup | Shop creation and ownership checks. | Verify the complete registration-to-shop workflow. |
| Home dashboard | Sales summaries, recent sales and stock attention information. | Verify calculations against real database records. |
| Products | Product creation, editing, search and deactivation. | Verify validation, persistence and ownership restrictions. |
| Categories | Category creation, updating and product assignments. | Verify category relationships and authorization. |
| Inventory | Inventory viewing, stock receiving and stock adjustments. | Test both stock-changing database functions. |
| Stock movements | Movement history and reporting data retrieval. | Verify movement records created by receipts, adjustments and sales. |
| POS | Cart management and checkout interface. | Test complete checkout, stock deduction and receipt generation. |
| Sales history | Sales and sale-item retrieval. | Verify history against completed transactions. |
| Reports | Sales, inventory, category and movement reporting. | Verify calculations and reporting periods. |
| Settings | Shop and account settings. | Verify updates and password-related workflows. |

These features are represented in the current source code. Their complete operational status depends on successful integration testing.

## 3. Database Status

The canonical database file is:

`SHOPFLOW_DATABASE.sql`

It is intended to be the single V1 fresh-install database definition.

### 3.1 Database structure

The current SQL file defines nine application tables:

1. `profiles`
2. `shops`
3. `categories`
4. `products`
5. `product_categories`
6. `inventory`
7. `stock_movements`
8. `sales`
9. `sale_items`

It also defines:

- Primary and foreign key relationships.
- Data constraints and indexes.
- Row Level Security on all nine application tables.
- Nineteen RLS policies.
- Six database functions.
- Two database triggers.

### 3.2 Database functions

The consolidated SQL includes all three business functions called by the Flutter repositories.

| Function | Calling repository | Definition in canonical SQL |
|---|---|---|
| `receive_stock` | `InventoryRepository` | Included |
| `adjust_stock` | `InventoryRepository` | Included |
| `complete_sale` | `PosRepository` | Included |

The additional functions are:

- `owns_shop` — checks shop ownership.
- `handle_new_user` — creates a profile for a newly registered user.
- `initialize_product_inventory` — creates an initial inventory balance for a new product.

### 3.3 Database verification status

The SQL file has been inspected for its expected tables, functions, policies, triggers and application contracts.

However, it has not yet been confirmed through a complete fresh Supabase installation and end-to-end application test.

The following remain necessary:

- Execute the canonical SQL against a separate, empty development Supabase project.
- Confirm that the script completes without database errors.
- Verify the deployed tables, constraints, policies and functions.
- Test stock receiving and adjustment.
- Test successful and unsuccessful POS transactions.
- Confirm that failed transactions do not leave partial database changes.
- Test access restrictions with separate authenticated users.

**Database structure is defined; runtime verification is still outstanding.**

### 3.4 Duplicate bootstrap file

The repository still contains:

`shopflow_supabase_fresh_install.sql`

This is an older alternative bootstrap and does not contain the complete current database functions or the current product-unit list.

Do not execute both SQL files.

The intended canonical database file is `SHOPFLOW_DATABASE.sql`. The older alternative should be removed or archived after checking that no contributor workflow depends on it.

## 4. Application and Database Alignment

The following important contracts have been aligned in the canonical SQL and current Flutter source.

### Product units

The current `ProductService.units` list and canonical PostgreSQL constraint use:

- `piece`
- `kg`
- `g`
- `litre`
- `ml`
- `pack`
- `box`
- `bottle`
- `dozen`

The old `bag` option is not part of the current V1 list.

### Money

Money is stored in integer minor units.

There are 100 minor units in SLE 1.00.

The Flutter models and database use integer monetary values rather than floating-point currency storage.

### Quantities

Inventory quantities support up to three decimal places.

The current POS implementation uses whole-number quantities. It rejects fractional stock rather than silently truncating it.

Fractional POS selling remains a future enhancement.

### Shop ownership

V1 supports one shop per authenticated owner.

The database uses `shops.owner_id` to associate a shop with its owner. The current authorization model does not yet provide employee roles or staff membership.

## 5. Authentication Status

Supabase Auth is used for registration, sign-in and password management.

The current source includes:

- Authentication services and repository.
- Authentication event handling through `AuthGate`.
- Password recovery and password update screens.
- Browser callback handling for web authentication.
- Android custom-scheme deep-link configuration.

Password recovery still requires successful end-to-end testing.

Verification should cover:

1. Requesting a recovery email.
2. Receiving and opening a valid recovery link.
3. Returning to the application.
4. Showing the password-update screen.
5. Updating the password successfully.
6. Signing in using the new password.

Test the web and Android flows separately.

Email delivery also depends on the SMTP and authentication settings configured in the Supabase project.

## 6. Offline Support

Supabase PostgreSQL remains the authoritative data store.

Although `sqflite` and `connectivity_plus` are listed in `pubspec.yaml`, the current application does not contain a completed SQLite cache, offline write queue or transaction synchronization implementation.

Current operating assumptions:

- Data operations use Supabase.
- Critical writes require successful cloud confirmation.
- Offline sales are not supported.
- Offline inventory transactions are not supported.
- Automatic synchronization of pending transactions is not implemented.

Offline support should be introduced only after its data consistency, conflict handling and security requirements have been designed and tested.

## 7. Testing Status

The checked-in `test/widget_test.dart` is currently empty.

The project needs a more complete automated test suite.

Priority areas include:

### Unit tests

- SLE money parsing and formatting.
- Product and category validation.
- Inventory quantity validation.
- Stock adjustment rules.
- POS cart calculations.
- Receipt response parsing.
- Business date calculations.

### Integration tests

- Authentication and shop setup.
- Product and category persistence.
- Stock receiving.
- Stock adjustments.
- POS checkout and receipt generation.
- Sales history and reports.
- Database transaction rollback behaviour.

### Security tests

- A user cannot read another owner's shop records.
- A user cannot write into another shop.
- Inventory and sales cannot be modified through unauthorized direct client requests.
- Database functions reject unauthenticated or unauthorized operations.

A successful `dart analyze` does not establish that these workflows work correctly against Supabase.

## 8. Licensing and Repository Status

The repository currently has no `LICENSE` file.

A license should be selected and added before presenting ShopFlow as an officially licensed open-source project.

The following repository items should also be kept consistent:

- One canonical database bootstrap file.
- Updated developer and database documentation.
- No committed `.env` files or privileged secrets.
- Documentation that reflects the actual application and database.
- Tests that demonstrate important business and security behaviour.

## 9. Recommended Next Work

The recommended development priorities are:

1. Test `SHOPFLOW_DATABASE.sql` on a fresh development Supabase project.
2. Remove or archive the outdated alternative SQL bootstrap.
3. Verify registration, shop setup and password recovery.
4. Test stock receiving and stock adjustments.
5. Test POS checkout, receipt generation and transaction rollback.
6. Add focused automated tests for important business rules.
7. Verify RLS using multiple ordinary authenticated users.
8. Review dashboard and report calculations against real records.
9. Decide whether SQLite caching is required for a future release.
10. Select and add an appropriate project license.

## 10. Release Readiness

ShopFlow should not be considered production-ready solely because its screens are implemented or its code passes static analysis.

A feature is ready when its presentation, service, repository, database operation, authorization, error handling and relevant tests work together.

The immediate goal is to establish a dependable V1 foundation: a reproducible Supabase setup, secure shop ownership, reliable inventory operations and correctly recorded sales.