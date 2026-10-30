# ShopFlow shop user guide

This guide explains the main ShopFlow workspaces and the normal shop workflow. Exact labels may change as the interface develops.

## 1. Sign in and set up your shop

1. Open ShopFlow and register an account or sign in with your existing account.
2. Complete the shop setup screen when prompted.
3. Enter your shop name and save it.
4. Once the shop is created, ShopFlow opens the main workspace.

The current V1 database design allows one shop for each account owner. ShopFlow uses Sierra Leone leones (SLE) as the shop currency in the current shop setup flow.

## 2. Navigate the application

The main screen has a ShopFlow app bar. Use the menu button to open the **Command Centre**. It provides access to the main workspaces:

- Home
- Point of Sale
- Products
- Inventory
- Categories
- Stock Movements
- Sales History
- Reports
- Settings

The selected workspace remains available while navigating within the shell.

## 3. Home dashboard

The dashboard gives a quick view of the shop. It currently brings together:

- Today's completed sales total.
- Number of completed transactions today.
- Products requiring stock attention, including low-stock and out-of-stock items.
- The most recent completed sales.

Use the refresh gesture or refresh control when you need to request the latest information. Dashboard figures depend on the current shop data being available from Supabase.

## 4. Products

The Products workspace is where the shop catalogue is maintained.

A product can include:

- Product name.
- Optional SKU or stock-keeping code.
- Unit of measure.
- Cost price.
- Selling price.
- Reorder level.
- Active or inactive status.

Use search to find products by name or SKU. Create a product when adding a new item to the catalogue. Edit an existing product when its details or prices change. Deactivate a product when it should no longer appear among active products. Deactivation is preferable to deleting a product that may be referenced by historical records.

Prices are entered as SLE amounts in the interface. The application stores money as integer minor units; for example, SLE 12.50 is stored as 1,250 minor units.

## 5. Categories

Categories help organise the product catalogue. You can create and edit category names and descriptions, activate or deactivate categories, and manage product assignments.

A product may be assigned to more than one category. Category membership is stored separately from the product record in the `product_categories` relationship table.

## 6. Inventory

The Inventory workspace shows active products and their recorded stock quantities. It supports product search, stock receiving and stock adjustments.

### Receive stock

Use the receiving action when new stock arrives. Select the product, enter a positive quantity and optionally record a reason or reference. The database operation should increase the inventory balance and record a stock movement together.

### Adjust stock

Use an adjustment when the recorded balance needs to be corrected. The current service recognises these movement types:

- `adjustment_in` — increase the recorded quantity.
- `adjustment_out` — decrease the recorded quantity.
- `damaged` — record stock removed because it is damaged.
- `returned` — record returned stock.

Enter a reason so the stock history remains understandable. The adjustment operation depends on the `adjust_stock` PostgreSQL function. The checked-in fresh-install SQL does not currently define that function; confirm the function exists in your Supabase project before relying on adjustments.

### Stock status

The app compares a product's available quantity with its reorder level to identify low-stock items. Out-of-stock products are treated as requiring attention.

Inventory quantities support up to three decimal places in the receiving and adjustment service. The current POS does not support fractional sale quantities.

## 7. Point of Sale

The POS workspace provides a product catalogue, search, cart and checkout flow.

A normal checkout is intended to work as follows:

1. Find an active product by name or SKU.
2. Add it to the cart.
3. Review the selected products and quantities.
4. Enter the amount received from the customer.
5. Submit the sale.
6. Review the receipt returned by the database-backed operation.

The app performs preliminary checks, including that the cart is not empty, product quantities are positive, the same product is not duplicated in the cart and the payment covers the displayed total.

The database must perform the authoritative price, stock, payment and transaction checks. The current Flutter repository calls a PostgreSQL function named `complete_sale`. The checked-in fresh-install SQL does not yet define that function. A working POS deployment therefore requires a reviewed and tested `complete_sale` function in the target database.

The current POS supports whole-number quantities only. Do not use it to sell fractional quantities, even if inventory records a fractional balance.

## 8. Stock Movements

The Stock Movements workspace provides a history of recorded stock changes. Movement entries identify the product, movement type, quantity change, date and any recorded reason.

The database convention is positive quantity for stock added and negative quantity for stock removed. A sale should appear as a negative stock movement when the completed-sale transaction is implemented correctly.

## 9. Sales History

Sales History lets you review recorded transactions, including their dates, sale numbers, status, totals, payment and change amounts. The current repository includes read paths for recent sales and completed sales within a date range.

The checked-in UI should be treated as a history/review workspace. Do not assume that voids, refunds or edits to completed sales are available unless they are explicitly implemented in the current interface and database.

## 10. Reports

Reports currently provide selectable periods:

- Last 7 days.
- Last 30 days.
- This month.

The report service builds summaries from sales, inventory, categories and stock movements. Depending on available data, the report model includes daily sales, transaction count, average transaction value, product performance, category performance, payment methods, low-stock and out-of-stock items, and stock movement totals.

Figures are calculated from records available in Supabase. Report values should not be treated as audited financial statements.

## 11. Settings and account security

Settings currently include the shop name, the signed-in account email, password-management actions and sign-out.

- Use the shop-name action to update the displayed shop name.
- Use the password action to change the password when signed in.
- Use password recovery when you cannot sign in or need a recovery link.
- Sign out when you have finished using the account on a shared device.

Password recovery is still under development and verification. Email delivery limits and callback configuration depend on the Supabase project's authentication settings. Never share a password-reset link with anyone; it contains a one-time authentication credential.

## 12. Currency, time and connectivity

- Currency: the current setup flow uses SLE.
- Money: 100 minor units represent SLE 1.00. Money is stored as integers to avoid floating-point rounding errors.
- Business date: ShopFlow currently treats Sierra Leone business time as UTC+00:00.
- Connectivity: the current application relies on Supabase for its working data. A complete offline cache and offline transaction synchronization are not implemented. Keep a reliable internet connection when making changes or completing a sale.

## If something goes wrong

- Refresh the relevant workspace and check your internet connection.
- Confirm that you are signed in to the intended account and shop.
- If shop verification fails, try again when the connection is available.
- If checkout or stock adjustment fails, the required database function may be missing or out of sync with the app. Contact the project administrator rather than repeatedly submitting the same transaction.
- For a password-reset problem, request a new email after the authentication email service is available. Do not reuse an old reset link.
