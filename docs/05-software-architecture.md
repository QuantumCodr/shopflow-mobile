# ShopFlow --- Software Architecture

**Status:** Proposed architecture for V1\
**Primary client:** Flutter / Dart\
**Cloud platform:** Supabase\
**Local cache:** SQLite

## 1. Goals

-   Keep the application understandable while it grows.
-   Separate UI, business rules and persistence.
-   Make Supabase the authoritative store for shared records.
-   Support offline viewing of previously cached data.
-   Avoid premature complexity and unnecessary abstractions.
-   Protect shop data at the database boundary.

## 2. High-level architecture

``` mermaid
flowchart TD
    UI[Flutter screens and widgets]
    S[Services / business rules]
    R[Repositories]
    SB[Supabase Auth and PostgreSQL]
    C[SQLite local cache]
    UI --> S
    S --> R
    R <--> SB
    R <--> C
```

The arrows describe logical responsibilities, not necessarily direct
synchronous calls in every implementation. The UI should not issue SQL
or contain complex business rules.

## 3. Layer responsibilities

### Presentation layer

Responsibilities: - Render screens and reusable widgets. - Collect user
input. - Show loading, empty, success, error, offline and stale-data
states. - Invoke application actions and display their results.

Must not: - Contain direct SQL. - Make authorization decisions that the
server must enforce. - Silently report success before persistence is
confirmed.

### Service / use-case layer

Responsibilities: - Coordinate application workflows. - Validate and
normalize data beyond basic field formatting. - Enforce business rules
such as valid stock adjustments. - Coordinate repository calls and
translate errors into meaningful outcomes. - Keep multi-step behavior
explicit.

### Repository layer

Responsibilities: - Provide a consistent data-access interface to
services. - Fetch and write cloud data. - Maintain/update the SQLite
cache where appropriate. - Map persistence representations to
application models. - Handle query details without owning unrelated
business policy.

### Supabase

Responsibilities: - Authoritative storage for shared records. -
Authentication and server-enforced authorization. - Constraints,
relationships and transaction boundaries. - RLS enforcement for
shop-scoped data.

### SQLite

Responsibilities: - Persist a local cache of previously confirmed
data. - Permit offline viewing when cached records exist. - Record cache
freshness metadata. - Support local read performance.

SQLite is not an independent source of truth in V1. No offline write
queue or transaction synchronization is planned.

## 4. Proposed project structure

Grow toward a feature-oriented structure as features are implemented:

``` text
lib/
  main.dart
  app.dart
  core/
    config/
    errors/
    theme/
    connectivity/
  features/
    onboarding/
      presentation/
      services/
      data/
    products/
      models/
      presentation/
      services/
      data/
    inventory/
      presentation/
      services/
      data/
    settings/
      presentation/
      services/
      data/
```

This is a target direction, not a requirement to create empty folders
immediately. Keep files close to the feature they support, and introduce
abstractions when there is a real use for them.

## 5. Data flow

### Cloud read

1.  UI requests data through a service.
2.  Service calls a repository.
3.  Repository requests authoritative data from Supabase when connected.
4.  On success, repository updates the local cache.
5.  The result and freshness metadata are returned to the UI.
6.  If cloud access fails, the repository may return cached data with an
    explicit stale/offline status.

### Cloud write

1.  UI collects input and performs immediate form validation.
2.  Service applies business rules.
3.  Repository sends the write to Supabase.
4.  Supabase validates constraints and authorization.
5.  On confirmed success, repository updates the cache.
6.  UI reports success.

If the request times out or the connection disappears after submission,
the outcome may be uncertain. Verify whether the operation committed
before retrying a non-idempotent action.

## 6. State management

Start with Flutter's built-in state tools for local screen state,
including `StatefulWidget`/`setState` where appropriate. Introduce a
broader state-management package only when shared or complex
asynchronous state demonstrates a real need.

Do not add a package merely because it is popular. Document the reason
if a new state-management approach is adopted.

## 7. Identity and identifiers

-   Use stable UUIDs for cloud records shared across clients.
-   Do not use SQLite autoincrement IDs as cross-device identifiers.
-   Keep cloud identifiers stable in cached records.
-   Associate records with the relevant shop and enforce access through
    server-side policy.
-   Use timestamps consistently and document whether they are UTC.

## 8. Error handling

Represent important failure categories distinctly: - Validation
failure. - Network/service unavailable. - Authentication required or
expired. - Authorization denied. - Constraint/business-rule rejection. -
Unknown write outcome. - Cache unavailable or stale.

Avoid catching all exceptions and displaying a generic success-like
response. Preserve enough diagnostic information for development while
avoiding disclosure of secrets or sensitive data.

## 9. Critical transaction behavior for future sales

When sales are introduced, a sale and its line items, stock deductions
and stock movements must be processed atomically. The database must
prevent overselling under concurrent requests and protect against
duplicate submissions using a stable transaction identifier or
idempotency mechanism.

Do not implement a sale as a series of independent client-side writes
that can leave partial records.

## 10. Architecture quality checks

-   UI has no direct SQL.
-   Business rules are not duplicated across widgets.
-   Cloud access is authenticated and enforced by RLS.
-   Cache entries retain stable cloud IDs and freshness metadata.
-   Cloud-confirmed writes update the cache only after confirmation.
-   Uncertain writes are verified before retry.
-   Important rules are covered by tests.

shopflow_mobile/
│
├── android/
├── docs/
│
├── lib/
│   │
│   ├── main.dart
│   ├── app.dart
│   │
│   ├── app/
│   │   ├── app_dependencies.dart
│   │   └── app_router.dart
│   │
│   ├── core/
│   │   ├── config/
│   │   │   └── app_config.dart
│   │   │
│   │   ├── database/
│   │   │   ├── local_database.dart
│   │   │   └── migrations/
│   │   │
│   │   ├── network/
│   │   │   └── connectivity_service.dart
│   │   │
│   │   ├── error/
│   │   │   └── app_exception.dart
│   │   │
│   │   └── utils/
│   │
│   ├── features/
│   │   │
│   │   ├── authentication/
│   │   │   ├── models/
│   │   │   ├── repositories/
│   │   │   ├── services/
│   │   │   ├── viewmodels/
│   │   │   └── views/
│   │   │
│   │   ├── shop_setup/
│   │   │   ├── models/
│   │   │   ├── repositories/
│   │   │   ├── services/
│   │   │   ├── viewmodels/
│   │   │   └── views/
│   │   │
│   │   ├── home/
│   │   │   ├── viewmodels/
│   │   │   ├── views/
│   │   │   └── widgets/
│   │   │
│   │   ├── products/
│   │   │   ├── models/
│   │   │   ├── repositories/
│   │   │   ├── services/
│   │   │   ├── viewmodels/
│   │   │   ├── views/
│   │   │   └── widgets/
│   │   │
│   │   ├── inventory/
│   │   │   ├── models/
│   │   │   ├── repositories/
│   │   │   ├── services/
│   │   │   ├── viewmodels/
│   │   │   ├── views/
│   │   │   └── widgets/
│   │   │
│   │   ├── pos/
│   │   ├── sales/
│   │   ├── purchases/
│   │   ├── reports/
│   │   └── settings/
│   │
│   ├── data/
│   │   ├── repositories/
│   │   └── services/
│   │
│   └── shared/
│       ├── theme/
│       └── widgets/
│
├── test/
│   ├── features/
│   ├── data/
│   └── core/
│
├── pubspec.yaml
└── README.md

lib/
├── main.dart
├── app.dart
│
├── app/
│   ├── app_dependencies.dart
│   └── app_router.dart
│
├── core/
│   ├── config/
│   ├── database/
│   ├── error/
│   └── network/
│
├── features/
│   ├── authentication/
│   │   ├── models/
│   │   ├── repositories/
│   │   ├── services/
│   │   ├── viewmodels/
│   │   └── views/
│   │
│   ├── shop_setup/
│   ├── home/
│   ├── categories/
│   ├── products/
│   ├── inventory/
│   ├── stock_movements/
│   ├── pos/
│   ├── sales/
│   └── reports/
│
└── shared/
    ├── theme/
    └── widgets/