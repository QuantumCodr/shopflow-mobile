# ShopFlow --- Product Vision and Project Charter

**Status:** Draft for review\
**Product:** ShopFlow\
**Platform:** Android first\
**Owner:** Project maintainer\
**Last updated:** 2026-10-20

## 1. Vision

ShopFlow aims to give small retail businesses a straightforward way to
organize products and understand what stock they have, using a mobile
application that is practical, understandable and dependable.

## 2. Problem statement

Small shops may rely on memory, handwritten notes or disconnected
records to track products and stock. These methods can make it difficult
to find product details, identify low stock, maintain consistent records
and understand changes in inventory.

ShopFlow will provide a structured digital workspace for product
information and stock records, beginning with a focused mobile
experience.

This is the product hypothesis. It should be validated with intended
users rather than treated as a claim about every shop.

## 3. Target users

### Primary user for V1

A shop owner or manager who needs to maintain a product catalogue and
monitor stock using an Android phone.

### Future users

Authorized shop workers, additional shops, and users who need sales,
purchasing, expense or reporting features. These are future directions,
not promises that every capability will ship in V1.

## 4. Value proposition

ShopFlow should help a shop owner answer basic operational questions
quickly:

-   What products do I have recorded?
-   What does each product cost and sell for?
-   How much stock is available?
-   Which products need attention because stock is low?
-   When and why did stock change?

## 5. Product principles

1.  **Useful before extensive:** Deliver a small, usable product before
    expanding scope.
2.  **Clear by default:** Use plain language, visible actions and
    understandable errors.
3.  **Trustworthy records:** Do not report a cloud write as successful
    until success is confirmed.
4.  **Security by design:** Protect shop data with authenticated access
    and database-enforced authorization.
5.  **Offline awareness:** Let users view cached information when
    possible, while clearly identifying its freshness.
6.  **Explainable engineering:** Prefer maintainable code and explicit
    business rules over cleverness.
7.  **Inclusive and accessible:** Use readable text, adequate touch
    targets, clear contrast and straightforward navigation.
8.  **Evidence-led growth:** Use feedback and observed needs to guide
    new features.

## 6. Initial product scope

### In scope for the first usable release

-   Android-first application shell and navigation.
-   Account authentication and association of an authenticated user with
    a shop.
-   Guided shop setup.
-   Product catalogue: list, view, add, edit and deactivate products.
-   Product fields and validation defined in the requirements and
    database documents.
-   Basic inventory quantities and stock movement history.
-   Low-stock indicators based on a configured reorder level.
-   Supabase-backed reads and writes with suitable RLS policies.
-   SQLite cache of previously confirmed cloud data for offline viewing.
-   Clear loading, empty, error, stale-cache and connection states.
-   Basic automated tests and setup documentation.

### Explicitly out of scope for initial release

-   Offline sales or inventory writes with later synchronization.
-   A pending-write queue or automatic replay of transactions.
-   Payment processing, rent collection, e-commerce storefront or
    delivery marketplace.
-   Payroll, accounting-grade financial statements or tax compliance
    claims.
-   Multi-warehouse optimization, barcode hardware integrations or
    complex purchasing automation.
-   A desktop release as a launch requirement.
-   Advanced analytics and forecasting.

Sales and reporting may be added after the product and inventory
foundation is reliable.

## 7. Constraints and assumptions

-   Android phones are the first target.
-   The initial operating scenario is one shop owner and one device.
-   The architecture should not prevent later support for multiple
    authorized users and shops.
-   Supabase is the authoritative shared data store.
-   SQLite is a cache, not an independent source of truth.
-   V1 critical writes require connectivity and cloud confirmation.
-   Authentication initially requires internet access.
-   The product should avoid requiring large inventory purchases,
    complex hardware or expensive infrastructure.
-   Currency, locale, shop terminology and product units must be
    configurable or explicitly chosen before release.

## 8. Success criteria

The first usable release should demonstrate that a shop owner can:

1.  Sign in and establish a shop profile.
2.  Add a valid product and see the confirmed record in the catalogue.
3.  Edit and deactivate a product without deleting historical
    references.
4.  record a stock adjustment with a reason and see the updated
    quantity.
5.  Identify products at or below their reorder level.
6.  View previously cached catalogue and inventory data when offline,
    with a visible freshness indicator.
7.  Understand when a save fails and whether the result needs
    verification.
8.  Use the main workflows without unexplained crashes or data
    inconsistencies.

Quantitative targets (for example, completion time, test coverage or
supported Android versions) should be set after early user testing and
release constraints are known.

## 9. Risks

-   Poor network reliability can interrupt writes; the interface must
    distinguish failure from an uncertain outcome.
-   Inadequate RLS policies could expose one shop's data to another
    user.
-   Incorrect stock calculations can undermine trust.
-   Too much scope could delay a useful first release.
-   Local cache data can become stale and must not be presented as
    current without qualification.
-   Unvalidated assumptions about currency, units and shop workflows may
    create rework.

## 10. Governance

This document defines product direction. Requirements describe
observable behavior; architecture and decision records explain
implementation choices. When a significant decision changes, update the
relevant documents and record the reason.

## 11. Open decisions

-   Final product name, visual identity and license.
-   Initial currency and formatting rules.
-   Whether shop creation is completed during sign-up or immediately
    after sign-in.
-   Exact product field requirements and whether SKU is optional.
-   Supported Android version range.
-   Initial pilot users and measurable usability targets.
