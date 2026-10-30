# ShopFlow Phase 2 — Future Data Model

**Project:** ShopFlow  
**Document type:** Product and database planning  
**Status:** Proposed — not implemented  
**Current baseline:** V1  
**Purpose:** Define how future business modules should extend the existing ShopFlow database.

## 1. Purpose

ShopFlow V1 focuses on the essential activities of a small retail shop:

- Managing products and categories.
- Recording inventory balances.
- Receiving and adjusting stock.
- Selling products through the POS.
- Reviewing sales history.
- Generating basic business reports.

The next stage of development will extend ShopFlow beyond basic sales and inventory management.

Phase 2 is intended to introduce:

1. Customer management.
2. Supplier management.
3. Purchase management.
4. Expense management.
5. Employee and access management.
6. Multiple shop and warehouse locations.

These are future modules. They are not part of the current V1 implementation, and this document does not introduce any database changes.

## 2. Existing V1 Database

The current database contains nine main application tables:

| Table | Current responsibility |
|---|---|
| `profiles` | User profile information. |
| `shops` | Shop details and ownership. |
| `categories` | Product categories. |
| `products` | Product catalogue. |
| `product_categories` | Product and category relationships. |
| `inventory` | Current product stock balances. |
| `stock_movements` | History of inventory changes. |
| `sales` | Completed sales. |
| `sale_items` | Products recorded in each sale. |

The existing design establishes several rules that Phase 2 must preserve:

- Each shop belongs to an authenticated owner.
- V1 supports one shop per owner.
- Shop data is protected using Row Level Security (RLS).
- Money is stored as integer minor units.
- Inventory quantities support up to three decimal places.
- POS quantities are whole numbers.
- Inventory and sales changes use trusted PostgreSQL functions.
- Historical sale items retain product and price snapshots.

New modules must extend these rules rather than bypass them.

## 3. Proposed Phase 2 Modules

### 3.1 Customer Management

**Purpose:** Maintain customer information and provide a useful purchase history.

Proposed capabilities:

- Register customers.
- Store names and contact information.
- Search and update customer records.
- Deactivate customers without deleting historical records.
- Associate optional customers with sales.
- Review customer purchase history.

Proposed table: `customers`

| Field | Purpose |
|---|---|
| `id` | Unique customer identifier. |
| `shop_id` | Shop the customer belongs to. |
| `full_name` | Customer name. |
| `phone` | Optional contact number. |
| `email` | Optional email address. |
| `address` | Optional address. |
| `notes` | Optional internal notes. |
| `is_active` | Whether the customer is active. |
| `created_at` | Record creation time. |
| `updated_at` | Last update time. |

**Relationship with V1:** Add an optional `customer_id` to `sales`.

A sale should still be allowed without a registered customer. This keeps checkout quick for ordinary walk-in customers.

Customer deletion should not erase sales history. Historical sales should remain available even if a customer is later deactivated or their account is removed.

### 3.2 Supplier Management

**Purpose:** Maintain information about businesses and individuals that supply products to a shop.

Proposed capabilities:

- Register suppliers.
- Store supplier contact details.
- Record supplier names and addresses.
- Search and update suppliers.
- Activate or deactivate suppliers.
- Review purchases associated with a supplier.

Proposed table: `suppliers`

| Field | Purpose |
|---|---|
| `id` | Unique supplier identifier. |
| `shop_id` | Shop associated with the supplier. |
| `name` | Supplier or business name. |
| `contact_person` | Optional contact person. |
| `phone` | Contact number. |
| `email` | Optional email address. |
| `address` | Optional business address. |
| `notes` | Additional information. |
| `is_active` | Whether the supplier is active. |
| `created_at` | Record creation time. |
| `updated_at` | Last update time. |

**Relationship with future modules:** A supplier can have multiple purchases. Each purchase should reference the supplier from whom the goods were ordered.

### 3.3 Purchase Management

**Purpose:** Record products ordered from suppliers and track the arrival of those products.

This module connects supplier management with inventory management.

Proposed capabilities:

- Create purchase orders.
- Select a supplier.
- Add products and quantities.
- Record supplier purchase prices.
- Track expected delivery.
- Record partial deliveries.
- Receive delivered products into inventory.
- Review purchase history.

Proposed tables:

**`purchases`**

Stores the main purchase record.

| Field | Purpose |
|---|---|
| `id` | Unique purchase identifier. |
| `shop_id` | Shop placing the order. |
| `supplier_id` | Supplier associated with the order. |
| `purchase_number` | Human-readable purchase reference. |
| `status` | Current purchase status. |
| `ordered_at` | Date the order was placed. |
| `expected_at` | Optional expected delivery date. |
| `created_at` | Record creation time. |
| `updated_at` | Last update time. |

**`purchase_items`**

Stores the products and quantities included in a purchase.

| Field | Purpose |
|---|---|
| `id` | Unique purchase item identifier. |
| `shop_id` | Associated shop. |
| `purchase_id` | Parent purchase. |
| `product_id` | Product being purchased. |
| `quantity_ordered` | Quantity ordered. |
| `quantity_received` | Total quantity received. |
| `unit_cost_minor` | Agreed unit purchase cost. |
| `line_total_minor` | Purchase line total. |

**`purchase_receipts`**

Records individual deliveries against a purchase. This supports suppliers delivering an order in multiple batches.

**`purchase_receipt_items`**

Records the products and quantities delivered in each receipt.

Suggested purchase statuses:

- `draft`
- `ordered`
- `partially_received`
- `received`
- `cancelled`

#### Purchase receiving workflow

1. Create a purchase.
2. Select a supplier.
3. Add products and ordered quantities.
4. Save or confirm the purchase order.
5. Record goods when they physically arrive.
6. Confirm the quantities received.
7. Update inventory and create stock movements.
8. Update the purchase receiving status.

A purchase order must not increase inventory simply because it was created.

Inventory should increase only when goods are received and confirmed.

The receiving operation should use a trusted PostgreSQL transaction. It must update purchase receipt records, inventory and stock movements together.

This prevents a situation where a purchase is marked as received but the stock balance was not updated.

### 3.4 Expense Management

**Purpose:** Track the operating costs of running a shop.

Proposed capabilities:

- Record expenses.
- Organise expenses into categories.
- Record payment method.
- Search expenses by date and category.
- Review expenses over a selected period.
- Include expense summaries in business reports.

Proposed tables:

**`expense_categories`**

Examples:

- Rent.
- Electricity.
- Water.
- Transport.
- Internet.
- Maintenance.
- Packaging.
- Other operating costs.

**`expenses`**

| Field | Purpose |
|---|---|
| `id` | Unique expense identifier. |
| `shop_id` | Shop responsible for the expense. |
| `category_id` | Expense category. |
| `description` | Explanation of the expense. |
| `amount_minor` | Amount in SLE minor units. |
| `payment_method` | How the expense was paid. |
| `expense_date` | Date the expense occurred. |
| `reference` | Optional receipt or payment reference. |
| `notes` | Additional information. |
| `created_at` | Record creation time. |

Expenses must be recorded separately from purchases and sales.

For example:

- Buying goods for resale is a purchase.
- Paying shop rent is an expense.
- Selling goods to a customer is a sale.

This separation will make future business reporting more meaningful.

## 4. Employee and Access Management

**Purpose:** Allow shop owners to give other people controlled access to ShopFlow.

The current V1 design assumes that the authenticated account owner controls the shop. It does not provide a complete employee or staff-permission system.

Phase 2 should introduce a membership-based access model.

Proposed tables:

**`shop_memberships`**

Connects authenticated users to shops and defines their roles.

| Field | Purpose |
|---|---|
| `id` | Membership identifier. |
| `shop_id` | Shop being accessed. |
| `user_id` | Supabase Auth user. |
| `role` | Assigned role. |
| `is_active` | Whether membership is active. |
| `created_at` | Membership creation time. |

Potential roles:

| Role | Intended responsibility |
|---|---|
| Owner | Full control of the shop. |
| Manager | Shop operations and management. |
| Cashier | POS and permitted sales activities. |
| Inventory Clerk | Stock receiving and inventory operations. |

An invitation workflow may later introduce a `shop_invitations` table to manage staff invitations safely.

### Important security change

The existing database uses `shops.owner_id` and owner-based RLS policies.

Introducing employees will require a broader authorization model.

The database should eventually use membership-aware authorization functions and permissions. Every role must be restricted to its intended operations.

Do not simply remove owner checks or allow every authenticated user to access a shop.

This change requires careful review of existing RLS policies and database functions.

## 5. Multiple Shop and Warehouse Locations

**Purpose:** Support businesses that operate several physical locations or warehouses.

The current inventory model stores one stock balance per product.

A multi-location design needs to distinguish stock held at different locations.

Proposed table: `locations`

| Field | Purpose |
|---|---|
| `id` | Unique location identifier. |
| `shop_id` | Parent shop or business. |
| `name` | Location name. |
| `code` | Optional location code. |
| `address` | Optional physical address. |
| `is_default` | Default stock location. |
| `is_active` | Whether the location is active. |
| `created_at` | Record creation time. |

### Inventory changes

The existing inventory relationship would need to change from:

`One product → One inventory balance`

to:

`One product → Multiple location inventory balances`

The proposed inventory identity would include:

- `shop_id`
- `product_id`
- `location_id`

This allows the same product to have different quantities at different locations.

### Stock transfers

A future `stock_transfers` module could record movements between locations.

A transfer should:

1. Identify the source location.
2. Identify the destination location.
3. Identify the products and quantities.
4. Record the transfer.
5. Deduct stock from the source.
6. Add stock to the destination.
7. Record both movements as one controlled operation.

A transfer must not accidentally increase total business inventory.

Multi-location support should be introduced only after the inventory model and location-level authorization have been properly designed.

## 6. Proposed Relationships

The following diagram describes the intended relationships between V1 and future Phase 2 modules.

```text
                         SHOP
                          |
          +---------------+----------------+
          |               |                |
       PRODUCTS        CUSTOMERS        SUPPLIERS
          |               |                |
          |               |              PURCHASES
          |               |                |
       INVENTORY        SALES          PURCHASE ITEMS
          |               |                |
          |           SALE ITEMS      PURCHASE RECEIPTS
          |               |                |
          +------- STOCK MOVEMENTS --------+
                          |
                       LOCATIONS

SHOP
 |
 +---- EXPENSE CATEGORIES
 |           |
 |        EXPENSES
 |
 +---- SHOP MEMBERSHIPS
             |
          EMPLOYEES
```

This is a conceptual relationship diagram. The final PostgreSQL relationships and constraints must be designed before implementation.

## 7. Data Integrity and Security Principles

All Phase 2 modules must follow the existing ShopFlow database standards.

### Shop ownership

Every new shop-owned record should carry a `shop_id`.

Relationships must prevent records from different shops being connected accidentally.

For example, a purchase must not reference a supplier belonging to another shop.

### Row Level Security

RLS must protect customer, supplier, purchase, expense and employee-related records.

Authorization must be enforced by PostgreSQL, not only by Flutter screens.

### Database transactions

Operations that modify multiple related records should use trusted database functions.

Examples:

- Receiving purchased stock.
- Recording purchase receipts.
- Completing payments against purchases.
- Transferring stock between locations.

### Money

Continue storing monetary values as integer minor units.

For the current SLE convention:

100 minor units = SLE 1.00.

### Quantities

Continue to use appropriate numeric precision for inventory quantities. Any change to fractional POS quantities must update Flutter models, services, repositories and PostgreSQL functions together.

### Historical records

Do not delete historical business records simply because a customer, supplier, employee or product becomes inactive.

Use appropriate archive or deactivation behaviour and preserve transaction history.

### Privacy

Collect only customer and supplier information needed for the business workflow.

Control access to contact information and avoid exposing unnecessary personal data through reports or staff accounts.

## 8. Proposed Implementation Order

Phase 2 should be delivered in manageable stages.

| Stage | Modules | Main outcome |
|---|---|---|
| 2A | Customers | Customer records and optional customer-linked sales. |
| 2B | Suppliers | Supplier records and supplier search. |
| 2C | Purchasing | Purchase orders, delivery records and stock receiving. |
| 2D | Expenses | Expense categories, expense records and expense reports. |
| 2E | Employees | Staff memberships, roles and permissions. |
| 2F | Locations | Multiple stock locations and transfers. |

Purchasing depends on supplier management. Employee permissions should be designed before allowing multiple people to perform sensitive operations.

Multi-location inventory is placed later because it changes the existing inventory structure and affects stock receiving, adjustments, POS and reporting.

The stages may be reordered after reviewing business priorities and technical dependencies.

## 9. Migration Strategy

Phase 2 must not be implemented by repeatedly running the V1 fresh-install database file.

The existing file:

`SHOPFLOW_DATABASE.sql`

remains the canonical V1 fresh-install definition.

When Phase 2 development begins:

1. Design the required tables and relationships.
2. Review how each module interacts with V1.
3. Define constraints, indexes and RLS policies.
4. Define any required PostgreSQL functions.
5. Prepare incremental migrations for existing databases.
6. Test migrations against a copy or separate development database.
7. Verify that existing V1 data remains intact.
8. Update Flutter models, repositories, services and screens.
9. Add automated tests for the new business rules.
10. Update the documentation.

Once the Phase 2 schema becomes an established release, the canonical fresh-install SQL should also be updated to represent the complete supported schema for new installations.

## 10. Features Outside This Proposal

The following are possible future extensions, not commitments for the immediate Phase 2 scope:

- Customer loyalty and rewards.
- Supplier payment management and accounts payable.
- Sales returns and refunds.
- Tax and advanced financial reporting.
- Staff attendance and payroll.
- Barcode scanning.
- Warehouse management.
- Online ordering and delivery.
- Multi-currency support.
- Business analytics and forecasting.

Each extension should have its own requirements and security review before implementation.

## 11. Final Direction

ShopFlow should grow from a basic retail management application into a connected business management system.

The intended progression is:

**V1:** Products, inventory, POS, sales and reports.

**Phase 2:** Customers, suppliers, purchasing, expenses, employees and locations.

**Future development:** Advanced financial management, logistics, integrations and business intelligence.

The guiding principle is to expand ShopFlow without sacrificing data integrity, security, usability or maintainability.

Build each module around a clear business workflow, keep its database relationships understandable and test it before introducing the next layer of complexity.