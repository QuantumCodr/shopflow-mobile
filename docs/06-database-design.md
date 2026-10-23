# ShopFlow --- Database Design

**Status:** Logical model proposal; not yet an executable migration\
**Cloud database:** Supabase PostgreSQL\
**Local store:** SQLite cache

## 1. Design goals

-   Keep data normalized and relationships explicit.
-   Associate shop-owned records with a shop.
-   Preserve inventory history.
-   Support current product/inventory features without blocking future
    sales and purchasing.
-   Enforce data integrity in PostgreSQL, not only in the Flutter UI.
-   Keep shared identifiers stable across cloud and cache.

## 2. Logical entities

### `shops`

Represents a retail business/workspace.

Candidate fields: - `id` --- UUID primary key. - `name` --- required
shop name. - `created_at`, `updated_at` --- timestamps.

### `profiles`

Application profile associated with an authenticated Supabase user. The
Supabase Auth user ID is the identity source; profile data should not
duplicate credentials.

Candidate fields: - `id` --- UUID matching the Auth user ID. -
`display_name` --- optional display name. - timestamps.

### `shop_memberships`

Connects users to shops and defines their role. Even if V1 starts with
one owner, an explicit membership relationship supports later authorized
workers.

Candidate fields: - `id` --- UUID primary key. - `shop_id` --- foreign
key to `shops`. - `user_id` --- foreign key to the user/profile
identity. - `role` --- constrained role value such as owner or staff. -
timestamps. - Unique constraint on `(shop_id, user_id)`.

### `categories`

Product categories belonging to a shop.

Candidate fields: - `id`, `shop_id`, `name`, timestamps. - Optional
uniqueness rule for normalized category names within a shop, if desired.

### `products`

Catalogue information.

Candidate fields: - `id` --- UUID primary key. - `shop_id` --- required
shop scope. - `category_id` --- optional category reference. - `name`
--- required. - `sku` --- optional until SKU rules are finalized. -
`unit` --- required or given a documented default. - `cost_price` and
`selling_price` --- exact numeric/decimal types, not floating-point
storage. - `reorder_level` --- non-negative numeric quantity. -
`is_active` --- default true. - timestamps.

Business-specific constraints such as allowed price ranges and SKU
uniqueness must be finalized before the migration.

### `inventory`

Represents the current stock balance for a product at a shop or stock
location.

Candidate fields: - `id` --- UUID primary key. - `shop_id` ---
required. - `product_id` --- required. - `quantity_on_hand` --- numeric
with a documented precision. - timestamps. - Unique constraint for the
chosen inventory scope, initially one balance per product per shop.

The final model must choose one clear rule: either inventory is a
separate balance per product or the product record itself holds the
quantity. The recommended direction is a separate inventory balance plus
a movement ledger.

### `stock_movements`

An auditable record of inventory changes.

Candidate fields: - `id` --- UUID primary key. - `shop_id`, `product_id`
--- required. - `movement_type` --- constrained value, such as opening
balance, adjustment, receipt or sale. - `quantity_delta` --- signed
quantity change. - `reason` --- optional/required according to movement
type. - `reference_id` --- optional link to a related business record. -
`created_by` --- authenticated user reference where applicable. -
`created_at` --- timestamp.

Movement records should normally be append-only for ordinary users.
Corrections should be represented by a compensating movement rather than
silently rewriting history.

## 3. Future entities (not all required for V1)

### `suppliers`

Shop-scoped supplier records.

### `purchases` and `purchase_items`

Supplier purchase headers and lines, with clear receipt behavior. Stock
should increase when a purchase is received, not merely when a draft
purchase is created.

### `sales` and `sale_items`

Sale header and line items. Stock deduction and movement creation must
occur in one database transaction.

### `payments`

Payment records related to sales if payment tracking is included in a
later scope.

### `expenses`

Shop expense records, if supported by validated requirements.

Do not create unused tables merely to make the schema look
comprehensive. Add them when their workflows and rules are sufficiently
defined.

## 4. Relationship sketch

``` mermaid
erDiagram
    SHOPS ||--o{ SHOP_MEMBERSHIPS : has
    PROFILES ||--o{ SHOP_MEMBERSHIPS : belongs
    SHOPS ||--o{ CATEGORIES : defines
    SHOPS ||--o{ PRODUCTS : owns
    CATEGORIES o|--o{ PRODUCTS : groups
    PRODUCTS ||--o| INVENTORY : has_balance
    PRODUCTS ||--o{ STOCK_MOVEMENTS : records
    SHOPS ||--o{ INVENTORY : scopes
    SHOPS ||--o{ STOCK_MOVEMENTS : scopes
```

This is a logical relationship sketch, not a final SQL diagram. Exact
keys and constraints must be reflected in migrations.

## 5. Integrity and security rules

-   Every shop-owned record must have a valid shop relationship.
-   Product, inventory, movement and category references must be
    consistent with the same shop. Do not rely only on matching IDs
    supplied by the client.
-   Use foreign keys, unique constraints, check constraints and
    appropriate indexes.
-   Enforce shop access with RLS policies and authenticated membership
    checks.
-   Ensure users cannot assign themselves an owner role or add
    themselves to arbitrary shops through an unprotected client write.
-   Decide whether a stock balance is derived from movements, maintained
    transactionally alongside them, or periodically reconciled. The
    chosen rule must prevent balance/ledger divergence.
-   Deactivate products rather than deleting records referenced by
    history.
-   Store prices using PostgreSQL `numeric` with an explicitly chosen
    precision/scale.
-   Use stable UUIDs for cloud IDs.

## 6. Inventory consistency

A stock adjustment should update the balance and create its movement in
one database transaction, ideally through a carefully authorized
database function or equivalent transactional server-side operation. If
one write succeeds and the other fails, inventory becomes unreliable.

For future sales, stock validation and deduction must be
concurrency-safe. A client-side read followed by an independent update
is insufficient to prevent two devices selling the same last item.

## 7. SQLite cache mapping

SQLite should cache only the fields and records needed by offline
viewing. It should preserve cloud UUIDs, include
synchronization/freshness metadata and avoid becoming an alternative
authority.

A cache design may include: - Cached products and relevant inventory
balances. - Cache metadata with last successful refresh timestamp. -
Optional tombstone/deactivation state needed to avoid showing stale
active records.

The exact cache schema can differ from PostgreSQL where appropriate, but
mapping rules must be documented and tested.

## 8. Migration policy

-   Keep schema changes in version-controlled migrations under
    `supabase/migrations/`.
-   Do not rely on manual dashboard edits as the only record of schema
    changes.
-   Review each migration for constraints, RLS and safe rollout
    behavior.
-   Test migrations against a development project before release.
-   Never commit production credentials or real customer data.

## 9. Decisions required before SQL implementation

1.  Final product fields and SKU policy.
2.  Supported quantity precision and units.
3.  Currency and monetary precision.
4.  Whether stock is tracked in a separate `inventory` table
    (recommended) and the exact balance/ledger consistency strategy.
5.  Initial role and membership model.
6.  RLS policy design and authorized stock-adjustment mechanism.
7.  Timestamp and deletion/deactivation conventions.
