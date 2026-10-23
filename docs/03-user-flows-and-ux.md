# ShopFlow --- User Flows and UX Specification

**Status:** Draft\
**Purpose:** Define the main user journeys and required interface states
before full implementation.

## 1. UX principles

-   Keep common tasks easy to find.
-   Use familiar mobile patterns and plain language.
-   Avoid unnecessary setup questions.
-   Make the next action clear.
-   Give immediate feedback for taps, saves and errors.
-   Distinguish saved cloud data from cached data.
-   Never disguise a failed or uncertain save as success.
-   Preserve user-entered form data when a recoverable error occurs.

## 2. Application navigation

Proposed initial navigation:

``` mermaid
flowchart TD
    A[App launch] --> B{Authenticated session?}
    B -- No --> C[Welcome / Sign in]
    C --> D[Authenticate]
    D --> E{Shop configured?}
    B -- Yes --> E
    E -- No --> F[Guided shop setup]
    F --> G[Optional first product]
    G --> H[Home dashboard]
    E -- Yes --> H
    H --> I[Products]
    H --> J[Inventory]
    H --> K[Settings]
    I --> L[Add / Edit product]
    J --> M[Stock adjustment]
```

The final authentication screens and onboarding sequence should be
validated before detailed implementation. Account creation may be
integrated into the welcome flow.

## 3. First launch and onboarding

1.  Show a concise welcome screen explaining the app's purpose.
2.  Allow the user to register or sign in.
3.  Explain and collect the minimum shop details needed.
4.  Save the shop profile through an authenticated cloud operation.
5.  Offer a guided first-product step, with a clear option to skip.
6.  Open the dashboard.
7.  Explain the primary navigation and how to add products, without
    forcing a long tutorial.

If a cloud save fails, retain entered values where safe and explain how
to retry. If the outcome is uncertain, verify the resulting record
before repeating creation.

## 4. Dashboard

The dashboard should prioritize: - Product count. - Low-stock count. -
Quick action to add a product. - Entry point to the product catalogue. -
Entry point to inventory. - A clear connection or data-freshness
indicator when relevant.

Counts must come from real data once integrated. During prototyping,
sample values must be visibly treated as sample data and must not imply
real shop records exist.

## 5. Product catalogue flow

``` mermaid
flowchart TD
    A[Open Products] --> B{Cached or cloud data available?}
    B -- Cloud reachable --> C[Load authoritative products]
    B -- Offline --> D[Show cached products if available]
    C --> E[Display list and freshness]
    D --> E
    E --> F[Search / select product]
    E --> G[Add product]
    F --> H[Product details]
    H --> I[Edit or deactivate]
    G --> J[Validate form]
    J --> K{Valid?}
    K -- No --> L[Show field errors]
    L --> J
    K -- Yes --> M[Submit to cloud]
    M --> N{Confirmed?}
    N -- Yes --> O[Update cache and catalogue]
    N -- No --> P[Show error or verify uncertain outcome]
```

### Product list states

-   **Loading:** progress indicator and no false empty state.
-   **Populated:** product name and agreed summary fields.
-   **Empty:** explain that no products have been added and provide an
    Add Product action.
-   **Error:** explain the issue and provide a retry where appropriate.
-   **Offline with cache:** show cached data with last refresh
    information.
-   **Offline without cache:** explain that products cannot be loaded
    until a connection is available.

## 6. Add/edit product form

The form should: - Group related fields logically. - Mark required
fields. - Use appropriate keyboards for numeric input. - Validate values
and show errors near relevant fields. - Prevent accidental duplicate
submissions while saving. - Preserve form input on recoverable
failures. - Distinguish successful save from failed or uncertain save.

Exact fields will be finalized in the database and UI specification.
Candidate fields include name, SKU, category, unit, cost price, selling
price and reorder level.

## 7. Inventory and stock adjustment flow

1.  Open Inventory or a product's inventory details.
2.  Show available quantity and freshness state.
3.  Choose Adjust stock.
4.  Enter the adjustment amount and reason.
5.  Validate the input and explain the effect of the adjustment.
6.  Submit to the cloud.
7.  Confirm the result only after successful persistence.
8.  Refresh the displayed quantity and movement history.

A movement should preserve an audit trail. A user should not need to
infer why a quantity changed from a number that was silently
overwritten.

## 8. Settings

Initial settings may include shop profile, account/session actions,
basic preferences and application information. Do not expose unfinished
controls that appear operational but do nothing.

## 9. Shared interaction states

Every asynchronous feature should consider: - Loading - Success -
Validation error - Network failure - Authorization failure -
Unknown/uncertain write outcome - Empty result - Cached/stale result

A connectivity indicator is informative but not authoritative: a device
may report a network connection while the service itself is unavailable.

## 10. UX validation

Before release, ask representative users to complete practical tasks: -
Set up a shop. - Add and find a product. - Correct a product detail. -
Adjust stock and explain the resulting quantity. - Identify low-stock
products. - Interpret the offline/stale-data indicator.

Observe confusion and task completion instead of relying only on whether
users say they like the interface.
