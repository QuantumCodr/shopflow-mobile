# ShopFlow Shop User Guide

This guide explains the main ShopFlow workspaces and the normal shop workflow. Exact labels may change as the interface develops.

## 1. Sign In and Set Up Your Shop

1. Open ShopFlow and register an account or sign in with your existing account.
2. Complete the shop setup screen when prompted.
3. Enter your shop name and save it.
4. Once your shop is created, ShopFlow opens the main workspace.

The current V1 database design supports one shop for each account owner. ShopFlow uses Sierra Leone leones (SLE) as the shop currency.

## 2. Navigate the Application

The main screen has a ShopFlow app bar. Use the menu button to open the **Command Centre**.

The Command Centre provides access to these workspaces:

- Home
- Point of Sale
- Products
- Inventory
- Categories
- Stock Movements
- Sales History
- Reports
- Settings

The main application shell keeps workspaces available as you move between them.

## 3. Home Dashboard

The dashboard gives you a quick overview of your shop. It currently brings together:

- Today's completed sales total.
- Number of completed transactions today.
- Products requiring stock attention, including low-stock and out-of-stock items.
- Recent completed sales.

Use the refresh gesture or refresh control to request the latest information. Dashboard figures depend on the availability of your shop data in Supabase.

## 4. Products

The Products workspace is where you maintain your shop catalogue.

A product can include:

- Product name.
- Optional SKU or stock-keeping code.
- Unit of measure.
- Cost price.
- Selling price.
- Reorder level.
- Active or inactive status.

Use search to find products by name or SKU. Create a product when adding a new item. Edit an existing product when its details or prices change. Deactivate a product when it should no longer appear among active products.

Deactivation is preferable to deleting a product that may be referenced by historical records.

Prices are entered as SLE amounts in the interface. The application stores money as integer minor units. For example, SLE 12.50 is stored as 1,250 minor units.

## 5. Categories

Categories help organise the product catalogue.

You can create and edit category names and descriptions, activate or deactivate categories, and manage product assignments.

A product may belong to more than one category. This allows the same product to appear in different relevant catalogue groupings.

## 6. Inventory

The Inventory workspace shows active products and their recorded stock quantities. It supports product search, stock receiving and stock adjustments.

### Receive Stock

Use the receiving action when new stock arrives.

1. Select the product.
2. Enter the quantity received.
3. Add a reason or reference if needed.
4. Submit the receiving action.

Enter a positive quantity. A successful operation increases the inventory balance and records the corresponding stock movement.

### Adjust Stock

Use an adjustment when the recorded balance needs to be corrected.

The current system recognises these movement types:

- `adjustment_in` — increases the recorded quantity.
- `adjustment_out` — decreases the recorded quantity.
- `damaged` — records stock removed because it is damaged.
- `returned` — records stock returned to inventory.

A reason is required for an adjustment. This helps make the stock history understandable.

The database checks that an adjustment does not reduce the available balance below zero.

### Stock Status

ShopFlow compares a product's available quantity with its reorder level to identify low-stock items. Out-of-stock products are also treated as requiring attention.

Inventory receiving and adjustment support quantities with up to three decimal places. The current POS supports whole-number sale quantities only.

## 7. Point of Sale

The Point of Sale (POS) workspace provides a product catalogue, search, cart and checkout flow.

A normal checkout works as follows:

1. Find an active product by name or SKU.
2. Add the product to the cart.
3. Review the selected products and quantities.
4. Enter the amount received from the customer.
5. Submit the sale.
6. Review the receipt returned after successful checkout.

The application performs preliminary checks, including that the cart is not empty, quantities are positive, products are not duplicated in the cart and the payment covers the displayed total.

The database performs the authoritative checks. It verifies the current product prices and available stock, calculates the sale total and change, and records the completed transaction.

A successful checkout also updates inventory and records the related stock movements as part of the database transaction.

The current POS supports whole-number quantities only. Do not use it to sell fractional quantities, even when inventory records a fractional balance.

## 8. Stock Movements

The Stock Movements workspace provides a history of recorded stock changes.

Movement entries identify the product, movement type, quantity change, date and any recorded reason.

The database uses this quantity convention:

- Positive quantity: stock added.
- Negative quantity: stock removed.

A completed sale records a negative stock movement for each product sold. Receiving stock and adjustments also create corresponding movement records.

## 9. Sales History

Sales History lets you review recorded transactions, including their dates, sale numbers, status, totals, payment and change amounts.

The current workspace supports reviewing recent sales and completed sales within a selected date range.

Treat this workspace as a sales review area. Do not assume that voids, refunds or edits to completed sales are available unless they are explicitly implemented in the current interface.

## 10. Reports

Reports provide selectable reporting periods:

- Last 7 days.
- Last 30 days.
- This month.

Depending on available data, reports may include:

- Daily sales.
- Transaction count.
- Average transaction value.
- Product performance.
- Category performance.
- Payment methods.
- Low-stock and out-of-stock items.
- Stock movement totals.

Report figures are calculated from records available in Supabase. They are intended to support shop management and should not be treated as audited financial statements.

## 11. Settings and Account Security

Settings currently include the shop name, signed-in account email, password-management actions and sign-out.

- Use the shop-name action to update the displayed shop name.
- Use the password action to change your password when signed in.
- Use password recovery when you cannot sign in or need a recovery link.
- Sign out when you have finished using your account on a shared device.

Password recovery is still undergoing development and verification. Email delivery and recovery-link behaviour depend on the Supabase project's authentication settings.

Never share a password-reset link with anyone. It contains a one-time authentication credential.

## 12. Currency, Time and Connectivity

- **Currency:** The current shop setup uses SLE.
- **Money:** 100 minor units represent SLE 1.00. Money is stored as integers to avoid floating-point rounding errors.
- **Business time:** ShopFlow currently uses UTC+00:00 for Sierra Leone business time.
- **Connectivity:** The application relies on Supabase for its working data. A complete offline cache and offline transaction synchronisation are not implemented. Maintain a reliable internet connection when making changes or completing sales.

## If Something Goes Wrong

- Refresh the relevant workspace and check your internet connection.
- Confirm that you are signed in to the intended account and shop.
- If shop verification fails, try again when your connection is available.
- If checkout or stock adjustment fails, avoid repeatedly submitting the same transaction. Check whether the database is available and contact the project administrator if the problem continues.
- For a password-reset problem, request a new email after the authentication email service is available. Do not reuse an old reset link.

### Database Setup Note for Administrators

The canonical V1 database setup file is `SHOPFLOW_DATABASE.sql`. It includes the database functions required for stock receiving, stock adjustments and POS checkout.

Use this file only when setting up a new or empty Supabase project. Do not run a fresh-install script over an existing database. Existing installations must be updated through appropriate database migrations.