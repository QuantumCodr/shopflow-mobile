# ShopFlow database and security

## 1. Database platform

ShopFlow uses Supabase PostgreSQL as its authoritative application database. Supabase Auth provides account authentication. The Flutter client uses a publishable key and relies on Row Level Security (RLS) and carefully scoped database functions to control access.

The main checked-in bootstrap is `SHOPFLOW_DATABASE.sql`. Its header states that it is for a fresh database only. Do not run it against an existing installation as an update or migration. Changes to an existing database must be delivered through incremental, reviewed migrations that preserve existing data.

## 2. Main tables

The current canonical bootstrap creates these application tables:

| Table | Purpose |
|---|---|
| `profiles` | Application profile linked to a Supabase Auth user. |
| `shops` | Shop identity, owner, currency and active status. |
| `categories` | Categories belonging to a shop. |
| `products` | Product details, SKU, unit, cost/selling prices and reorder level. |
| `product_categories` | Many-to-many relationship between products and categories. |
| `inventory` | Current quantity balance for each product. |
| `stock_movements` | Signed ledger of stock changes. |
| `sales` | Sale header, generated sale number, totals, payment and status. |
| `sale_items` | Product and price snapshots for each sale line. |

### Important relationships

- A profile represents an authenticated user.
- V1 currently enforces one shop per owner using a unique `shops.owner_id`.
- Categories and products are scoped to a shop.
- Products and categories are related through `product_categories`; `products` does not have a `category_id` column in the canonical schema.
- Inventory records belong to a product and shop.
- Sales belong to a shop. Sale items reference their sale and product within the same shop.

## 3. Money representation

Monetary columns use integer minor units, not decimal currency values. In the current SLE convention:

- SLE 1.00 = 100 minor units.
- SLE 12.50 = 1,250 minor units.
- SLE 8,000.00 = 800,000 minor units.

Relevant database column names include `cost_price_minor`, `selling_price_minor`, `subtotal_minor`, `discount_minor`, `total_minor`, `amount_paid_minor`, `change_minor`, `unit_price_minor`, `unit_cost_minor` and `line_total_minor`.

Keep calculations in integers and use `lib/shared/formatters/sle_money.dart` for conversion and display. Do not store money as floating-point values.

## 4. Quantity and stock movements

Inventory quantity uses `NUMERIC(14,3)` and is constrained to be non-negative. Stock movements use a signed `quantity_delta`:

- Positive values represent stock entering inventory.
- Negative values represent stock leaving inventory.

The movement types defined in the SQL bootstrap include `opening_stock`, `stock_in`, `sale`, `adjustment_in`, `adjustment_out`, `damaged` and `returned`.

The current inventory service validates quantities to a maximum of three decimal places. The current POS implementation supports whole-number quantities only and rejects fractional stock when loading POS availability.

## 5. Database functions and application contract

The checked-in `SHOPFLOW_DATABASE.sql` defines these functions:

- `owns_shop` — ownership helper used by policies.
- `handle_new_user` — creates the application profile when an Auth user is created.
- `initialize_product_inventory` — initializes inventory for a new product.
- `receive_stock` — validates and records stock receiving as a database operation.

The current Flutter code also calls two functions that are not defined in the checked-in bootstrap:

| Function called by Flutter | Calling repository | Status in checked-in bootstrap |
|---|---|---|
| `receive_stock` | `InventoryRepository` | Defined and granted to `authenticated`. |
| `adjust_stock` | `InventoryRepository` | Missing. |
| `complete_sale` | `PosRepository` | Missing. |

This is a deployment blocker for a fresh installation. Do not grant direct client writes to inventory, stock movements, sales or sale items as a shortcut. Implement and review the missing functions so that authorization, quantity validation, stock locking, receipt values and related ledger records are handled atomically.

The POS client sends product IDs and quantities, plus a payment amount. PostgreSQL must obtain authoritative prices and validate available stock, payment, shop ownership and all resulting records within one transaction. A sale must not be considered successful merely because the client calculated a total.

## 6. Row Level Security and grants

The bootstrap enables RLS on application tables and defines policies that scope data to the authenticated user and the user's shop. The intended access pattern is:

- Profiles: an authenticated user can access their own profile.
- Shops: a user can access and manage their own shop within the defined policies.
- Categories and products: access is limited to the user's shop.
- Product/category assignments: access is scoped to the same shop.
- Inventory, stock movements, sales and sale items: direct authenticated access is read-only in the bootstrap; writes are intended to happen through trusted database functions.

RLS policies are the security boundary. Client-side checks, hidden controls or a guessed shop ID must never be treated as authorization.

## 7. Authentication and client configuration

The Flutter application reads:

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`

from `.env`. The publishable key is intended for client-side use in combination with RLS. A service-role key bypasses normal RLS protections and must never be placed in the Flutter app or committed to the repository.

Password recovery uses Supabase Auth and a redirect URL. Browser-based PKCE flows depend on the verifier stored in the browser's storage for the origin that initiated the request. Keep the same browser profile, hostname and port during development tests. Native Android recovery requires a matching Android URL intent filter and an allowed custom-scheme redirect in Supabase Auth settings.

Email delivery settings and rate limits belong to the Supabase project configuration. Configure a suitable SMTP provider before relying on authentication email delivery for real users.

## 8. Fresh installation checklist

Before treating a new Supabase environment as usable:

- [ ] Confirm it is empty before applying the fresh-install bootstrap.
- [ ] Review the SQL file and execute it once.
- [ ] Confirm all expected tables exist.
- [ ] Confirm RLS is enabled on all application tables.
- [ ] Review the profile-creation and inventory-initialization triggers.
- [ ] Confirm `receive_stock` exists and is executable by `authenticated`.
- [ ] Implement and test `adjust_stock`.
- [ ] Implement and test `complete_sale` as one atomic transaction.
- [ ] Align product-unit validation between Dart and PostgreSQL.
- [ ] Test with an ordinary authenticated user, not an administrator or service-role key.

## 9. Schema alignment items

Two additional contracts need alignment between client validation and the SQL bootstrap:

1. `ProductService.units` currently accepts `dozen`, while the SQL product-unit check accepts `bag` but does not accept `dozen`.
2. POS quantity is currently integer-only, while inventory quantity supports up to three decimal places.

Resolve these deliberately in both code and schema before treating the affected inputs as fully supported.
