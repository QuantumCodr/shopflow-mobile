# ShopFlow --- Product Requirements Document

**Status:** Draft for implementation planning\
**Version:** 0.1\
**Platform:** Android first

## 1. Purpose

This document defines the first release's user-facing capabilities and
the conditions under which they are considered complete. It is
intentionally limited to the product catalogue and inventory foundation.

## 2. User and context

The primary user is a shop owner or manager using an Android phone to
maintain product and stock records. V1 assumes one shop and one primary
device, but stored data must be associated with a shop and access must
be enforced in the database so the product can grow safely.

## 3. User stories and acceptance criteria

### US-01 --- Set up a shop

As a shop owner, I want to enter basic shop information so that my
records belong to the correct shop.

**Acceptance criteria** - The user must be authenticated before
protected shop data is created. - Required fields are validated before
submission. - A successful setup is confirmed only after the cloud
confirms it. - If setup fails, the user receives a useful message and
can safely retry after the outcome is known. - The shop is associated
with the authenticated owner through an authorized relationship.

### US-02 --- View products

As a shop owner, I want to view my product catalogue so that I can find
product details quickly.

**Acceptance criteria** - The screen shows products belonging to the
current shop that are not deactivated by default. - Each row shows the
agreed key fields, such as name, selling price and stock status. -
Loading, empty, error and cached/offline states are distinguishable. - A
refresh updates the view from the authoritative cloud source when
connected.

### US-03 --- Add a product

As a shop owner, I want to add a product so that I can maintain an
accurate catalogue.

**Acceptance criteria** - Required fields are clearly indicated. - Name
and numeric fields are validated before submission. - Prices and
quantities reject invalid values. - Duplicate SKU behavior is defined
and enforced within the appropriate shop scope if SKU is used. - The
save action shows progress and prevents accidental repeated taps while
the request is in progress. - The UI reports success only after the
cloud confirms the write. - If a request has an uncertain outcome, the
app checks for the resulting record before retrying a potentially
duplicative operation.

### US-04 --- Edit a product

As a shop owner, I want to correct product details without creating a
duplicate product.

**Acceptance criteria** - The existing product is loaded into the
form. - Valid changes are saved to the cloud and reflected in the
catalogue after confirmation. - Validation errors identify fields that
need attention. - A failed or uncertain write is not falsely shown as
successful.

### US-05 --- Deactivate a product

As a shop owner, I want to stop using a product without erasing history
that may reference it.

**Acceptance criteria** - Deactivation requires a clear user action and
appropriate confirmation. - A deactivated product is hidden from the
default active catalogue. - Historical stock movements or future
transactions retain valid references. - Reactivation can be supported if
the product rules allow it; permanent deletion is not the default
behavior.

### US-06 --- View inventory

As a shop owner, I want to see available quantities so that I can
monitor stock.

**Acceptance criteria** - Quantity is associated with a product and
shop. - Stock changes are represented by recorded movements or
adjustments, not silent unexplained overwrites. - The app prevents
invalid negative quantities unless a future, explicitly approved
business rule permits them. - A stock adjustment records the quantity
change, time, actor where available, and reason. - Inventory values are
refreshed from the cloud when connected.

### US-07 --- Identify low stock

As a shop owner, I want to identify products that need replenishment.

**Acceptance criteria** - A product's reorder level is stored as part of
its configuration or agreed inventory settings. - A product is marked
low stock when its available quantity is less than or equal to the
reorder level. - The interface does not treat missing or stale values as
definitively current.

### US-08 --- View cached data offline

As a shop owner, I want to view previously confirmed records when my
connection is unavailable.

**Acceptance criteria** - The app may show cached products and inventory
data. - Cached data includes a last-successful-refresh time or
equivalent freshness indicator. - Offline mode is visibly identified. -
V1 does not accept offline product, inventory or sales writes. - The UI
does not imply that cached data is current when it may be stale.

### US-09 --- Handle network and authentication failures

As a shop owner, I want clear feedback when a request fails.

**Acceptance criteria** - A temporary network error does not
automatically sign the user out. - Authentication expiration is handled
separately from network unavailability. - Protected operations are
rejected when authentication or authorization is invalid. - For writes
with an uncertain result, the app verifies the cloud state before
retrying when possible.

## 4. Functional requirements

-   **FR-01:** The app shall provide an Android-first mobile interface.
-   **FR-02:** The app shall authenticate users before protected cloud
    operations.
-   **FR-03:** Each shop-owned record shall be scoped to a shop.
-   **FR-04:** The app shall support product creation, reading, updating
    and deactivation.
-   **FR-05:** The app shall support inventory viewing and reasoned
    stock adjustments.
-   **FR-06:** The app shall show low-stock status according to the
    configured reorder level.
-   **FR-07:** The app shall use Supabase as the authoritative source
    for shared records.
-   **FR-08:** The app shall use SQLite to cache previously confirmed
    data for local viewing.
-   **FR-09:** V1 shall not queue or replay offline writes.
-   **FR-10:** The app shall display meaningful loading, empty, error,
    offline and stale-data states.
-   **FR-11:** Database authorization shall prevent users from reading
    or modifying records outside their permitted shop scope.
-   **FR-12:** Product deactivation shall preserve references needed by
    historical records.

## 5. Non-functional requirements

### Security

-   Do not ship a Supabase service-role key or other server secret in
    the client.
-   Use authenticated requests and least-privilege RLS policies.
-   Validate and constrain data at the database boundary as well as in
    the UI.
-   Do not log credentials, access tokens or sensitive business data.

### Reliability and data integrity

-   Cloud-confirmed writes are the basis for authoritative state.
-   Multi-record critical operations introduced later must be
    transactional.
-   Use stable cloud UUIDs for records shared between devices or
    services.
-   Treat request timeouts as potentially uncertain outcomes, not proof
    that the write failed.

### Usability and accessibility

-   Use clear labels and plain-language errors.
-   Maintain readable text, sufficient contrast and comfortable touch
    targets.
-   Avoid requiring users to understand technical database terminology.
-   Make destructive or irreversible actions difficult to trigger
    accidentally.

### Maintainability

-   Keep UI, business rules and data access separated.
-   Use consistent naming and formatting.
-   Include tests for important business rules and data-integrity
    behavior.
-   Document meaningful architectural decisions.

### Performance

-   Show loading feedback for asynchronous operations.
-   Avoid unnecessary full-screen reloads where a focused update is
    appropriate.
-   Use pagination or search if catalogue size makes loading every
    record inefficient.

## 6. V1 exclusions

No offline transaction queue, sales processing, payment processing,
accounting claims, advanced forecasting, barcode integrations, or
desktop release requirement.

## 7. Requirement traceability

Requirements should map to user stories, implementation tasks and tests.
A feature is not complete merely because its screen exists; acceptance
criteria and relevant failure states must also be covered.

## 8. Open questions

-   Final required product fields and SKU uniqueness policy.
-   Quantity precision and supported units.
-   Currency and price formatting.
-   Whether inventory is created automatically with a product or through
    a separate setup step.
-   Shop setup and account recovery details.
-   Minimum Android version and target devices.
