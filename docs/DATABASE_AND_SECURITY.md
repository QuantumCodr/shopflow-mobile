# ShopFlow Database and Security

**Database:** Supabase PostgreSQL  
**Authentication:** Supabase Auth  
**Currency:** Sierra Leonean Leone (SLE)  
**Database version:** V1  
**Status:** Consolidated fresh-install design; execution and end-to-end verification still required.

## 1. Database Overview

ShopFlow uses Supabase PostgreSQL as its authoritative database. Supabase Auth manages user authentication, while PostgreSQL handles data integrity, ownership, access control and business operations.

The database is defined in one SQL file:

`SHOPFLOW_DATABASE.sql`

This file contains the complete V1 database setup:

- Tables and relationships.
- Constraints and indexes.
- Row Level Security (RLS) policies.
- Authentication and product triggers.
- Database functions for stock receiving, stock adjustments and POS checkout.
- Post-installation verification queries.

### Installation rule

The SQL file is a fresh-install bootstrap.

Execute it once in a new, empty Supabase project. Do not execute it against an existing database containing ShopFlow records.

Changes to an existing database must use incremental migrations that preserve existing data.

## 2. Database Tables

The V1 database contains nine main application tables.

| Table | Purpose |
|---|---|
| `profiles` | Stores application profile information linked to Supabase Auth users. |
| `shops` | Stores shop information, owner, currency and active status. |
| `categories` | Stores product categories belonging to a shop. |
| `products` | Stores product details, SKU, unit, prices and reorder level. |
| `product_categories` | Connects products and categories through a many-to-many relationship. |
| `inventory` | Stores the current stock balance for each product. |
| `stock_movements` | Records stock entering or leaving inventory. |
| `sales` | Stores completed sales, sale numbers, payment information and totals. |
| `sale_items` | Stores the products and price snapshots belonging to each sale. |

### 2.1 Important relationships

**User and shop**

- A profile is associated with a Supabase Auth user.
- Each shop has one owner.
- V1 enforces one shop per owner through a unique `shops.owner_id` constraint.

**Products and categories**

- Products belong to a shop.
- Categories belong to a shop.
- A product can belong to multiple categories.
- A category can contain multiple products.
- `product_categories` maintains these assignments.

There is no `category_id` column in the products table.

**Products and inventory**

- Each product has one inventory balance.
- Inventory belongs to the same shop as its product.
- The inventory quantity cannot be negative.

**Sales and sale items**

- Each sale belongs to a shop.
- Each sale can contain multiple sale items.
- Every sale item references a product belonging to the same shop.
- Product names, selling prices and cost prices are recorded as snapshots so historical sales retain their original details.

## 3. Data Types and Business Rules

### 3.1 Money representation

ShopFlow stores monetary values as integers representing minor currency units.

For the current SLE convention:

| Display amount | Stored value |
|---|---:|
| SLE 1.00 | 100 |
| SLE 12.50 | 1,250 |
| SLE 8,000.00 | 800,000 |

Relevant database fields include:

- `cost_price_minor`
- `selling_price_minor`
- `subtotal_minor`
- `discount_minor`
- `total_minor`
- `amount_paid_minor`
- `change_minor`
- `unit_price_minor`
- `unit_cost_minor`
- `line_total_minor`

Calculations should use integer minor units rather than floating-point currency values.

In Flutter, use the shared SLE money formatter and parser in:

`lib/shared/formatters/sle_money.dart`

### 3.2 Product units

The allowed V1 product units are:

- `piece`
- `kg`
- `g`
- `litre`
- `ml`
- `pack`
- `box`
- `bottle`
- `dozen`

These values must remain consistent between `ProductService.units` and the PostgreSQL product-unit constraint.

### 3.3 Inventory quantities

Inventory uses PostgreSQL `NUMERIC(14,3)`.

This supports quantities with up to three decimal places.

Examples:

- `5`
- `2.5`
- `0.125`

The inventory balance must remain non-negative.

The inventory service validates received and adjusted quantities to a maximum of three decimal places.

### 3.4 POS quantities

The current POS implementation uses integer quantities.

Although the database can represent fractional inventory quantities, the current POS models and repository reject fractional stock when loading POS availability.

Fractional selling must not be assumed to work until the POS models, services, repository and database function are updated together.

## 4. Inventory and Stock Movements

ShopFlow maintains two related records:

**Inventory**

Stores the current available quantity for a product.

**Stock movements**

Records why the inventory quantity changed.

The `quantity_delta` column uses a signed quantity:

- Positive values represent stock entering inventory.
- Negative values represent stock leaving inventory.

The V1 movement types are:

| Movement type | Meaning |
|---|---|
| `opening_stock` | Initial stock balance. |
| `stock_in` | Stock received. |
| `sale` | Stock deducted through a completed sale. |
| `adjustment_in` | Stock increased through an adjustment. |
| `adjustment_out` | Stock reduced through an adjustment. |
| `damaged` | Stock removed because it was damaged. |
| `returned` | Stock added back through a return adjustment. |

The current stock balance should not be changed through arbitrary client-side updates.

Stock-changing operations must update the inventory balance and record the corresponding movement together in a database transaction.

## 5. Database Functions (RPC)

ShopFlow uses PostgreSQL functions for operations that must update multiple related records safely.

The Flutter repositories call these functions through Supabase RPC.

### 5.1 `owns_shop`

Purpose:

Checks whether the authenticated user owns the specified shop.

It is used by the RLS policies to restrict access to shop-owned records.

### 5.2 `receive_stock`

Called by:

`InventoryRepository.receiveStock()`

Purpose:

- Verifies the authenticated shop owner.
- Checks that the product belongs to the shop and is active.
- Validates the received quantity.
- Increases the inventory balance.
- Creates a positive stock movement.
- Returns the updated quantity and movement identifier.

The inventory update and movement insertion occur within the same database transaction.

### 5.3 `adjust_stock`

Called by:

`InventoryRepository.adjustStock()`

Purpose:

- Verifies shop ownership.
- Checks that the selected product belongs to the shop.
- Validates the movement type and quantity.
- Requires an adjustment reason.
- Determines whether stock should increase or decrease.
- Prevents the balance from becoming negative.
- Updates inventory and creates the corresponding movement record.

Supported adjustment types:

`adjustment_in`, `adjustment_out`, `damaged`, `returned`

The adjustment must either update the balance and movement record together or fail without committing either operation.

### 5.4 `complete_sale`

Called by:

`PosRepository.completeSale()`

Purpose:

Processes a POS transaction as one database operation.

The function:

1. Verifies shop ownership.
2. Validates the submitted sale items.
3. Checks that the products are active and belong to the shop.
4. Locks the relevant product and inventory records.
5. Retrieves authoritative product prices from PostgreSQL.
6. Checks available stock.
7. Calculates the subtotal, discount and total.
8. Validates the payment amount.
9. Creates the sale record.
10. Creates the sale-item records.
11. Deducts the sold quantities from inventory.
12. Creates negative stock movements.
13. Returns the sale receipt information.

The Flutter application submits product IDs and quantities rather than treating client-calculated prices as authoritative.

The current POS repository uses cash payments and zero discounts.

The receipt response must provide the fields expected by the Flutter application:

- `sale_id`
- `sale_number`
- `subtotal`
- `total`
- `payment`
- `change`

The database also returns the corresponding minor-unit fields where defined.

**Important:** A checkout must not be displayed as successful until the database operation succeeds and the application receives valid receipt information.

## 6. Row Level Security (RLS)

All nine application tables have Row Level Security enabled.

RLS ensures that an authenticated user cannot access another shop's records simply by changing a shop ID in a client request.

The intended access rules are:

| Table | Authenticated client access |
|---|---|
| `profiles` | Read and manage own profile. |
| `shops` | Read, create and update own shop. |
| `categories` | Read, create and update records in own shop. |
| `products` | Read, create and update records in own shop. |
| `product_categories` | Read, assign and remove category relationships in own shop. |
| `inventory` | Read own shop inventory. |
| `stock_movements` | Read own shop movement history. |
| `sales` | Read own shop sales. |
| `sale_items` | Read own shop sale items. |

The authenticated client does not receive direct write access to inventory, stock movements, sales or sale items.

Their mutations are handled by the authorized database functions.

### Security principles

- Authentication identifies the user.
- RLS controls which records the user can access.
- Database functions validate sensitive business operations.
- Constraints protect data integrity.
- Client-side validation improves usability but is not a security boundary.

Do not grant unrestricted table writes to solve an RPC or permission error.

## 7. Authentication and Configuration

The Flutter application reads the following values from the root `.env` file:

```dotenv
SUPABASE_URL=https://YOUR_PROJECT_ID.supabase.co
SUPABASE_PUBLISHABLE_KEY=YOUR_SUPABASE_PUBLISHABLE_KEY
```

The values are loaded in `lib/main.dart` and used to initialize Supabase.

### Key security rules

- Use the publishable key in the Flutter client.
- Never include the service-role key in the application.
- Never commit `.env`.
- Never expose database passwords or authentication tokens.
- Keep development and production Supabase projects separate.

### Password recovery

ShopFlow uses Supabase Auth for password recovery.

The current application uses the browser origin as the web redirect and the following custom scheme for Android:

`io.shopflow.app://reset-password`

For browser PKCE testing, use the same browser profile, hostname and port during the recovery flow.

Native Android password recovery also requires a matching Android deep-link intent filter and Supabase redirect configuration. The Android manifest must be checked before treating native recovery as configured.

For regular authentication email testing, configure an appropriate SMTP provider in Supabase.

## 8. Fresh Supabase Installation Checklist

Use this checklist when preparing a new development environment.

### Database installation

- [ ] Create a new Supabase project.
- [ ] Confirm that the database is empty before installation.
- [ ] Use the agreed canonical `SHOPFLOW_DATABASE.sql`.
- [ ] Execute the SQL bootstrap once.
- [ ] Confirm that all nine application tables exist.
- [ ] Confirm RLS is enabled on all nine tables.
- [ ] Confirm the ownership helper and triggers exist.
- [ ] Confirm that `receive_stock`, `adjust_stock` and `complete_sale` exist.
- [ ] Confirm that the authenticated role can execute the required RPC functions.

### Application connection

- [ ] Configure the local `.env` file.
- [ ] Use the correct Supabase project URL.
- [ ] Use the project's publishable key.
- [ ] Confirm that the Flutter application starts successfully.
- [ ] Register and authenticate a test user.
- [ ] Confirm that the profile is created.
- [ ] Complete shop setup.
- [ ] Confirm that the shop is associated with the authenticated owner.

### Business operation tests

- [ ] Create a product and confirm its inventory record is initialized.
- [ ] Create categories and assign products to them.
- [ ] Receive stock and verify the balance and movement history.
- [ ] Perform a stock adjustment and verify the result.
- [ ] Attempt an adjustment that would produce negative stock and confirm it is rejected.
- [ ] Complete a POS sale and verify the sale, sale items, inventory deduction and stock movements.
- [ ] Attempt a checkout with insufficient stock and confirm it is rejected.
- [ ] Confirm that failed transactions do not leave partial records.

### Security tests

- [ ] Test using an ordinary authenticated user.
- [ ] Confirm that one account cannot read another account's shop records.
- [ ] Confirm that unauthorized inventory and sales writes are rejected.
- [ ] Confirm that database functions reject unauthenticated calls.
- [ ] Do not use a service-role key to demonstrate ordinary client security.

The SQL file includes read-only post-installation verification queries. These check database structure and function availability but do not replace the business-operation and security tests above.

## 9. Current Limitations and Future Extensions

The V1 database is intentionally focused on the current retail management workflows.

The following are not included in the current schema:

- Customer management.
- Supplier management.
- Purchase orders and goods receiving workflows.
- Expense management.
- Employee records and staff permissions.
- Multiple warehouse locations.
- Advanced payment reconciliation.

These should be introduced through separately designed and reviewed database changes when their application workflows are ready.

V1 also does not provide a completed offline transaction synchronization system. Supabase remains the authoritative data store, and critical inventory and sales operations require a successful cloud response.

## 10. Database Change Management

`SHOPFLOW_DATABASE.sql` is the fresh-install database definition, not a script for repeatedly updating existing environments.

When the schema changes:

1. Identify the affected tables, functions, policies and Flutter repositories.
2. Update the database design and application contracts together.
3. Prepare a reviewed incremental migration for existing installations.
4. Test the change on a separate development Supabase project.
5. Verify RLS, constraints and transaction behaviour.
6. Update this document when the database behaviour or security model changes.

Do not silently edit the schema in a live Supabase project and leave the repository documentation behind.

The database, Flutter application and documentation should describe the same version of ShopFlow.