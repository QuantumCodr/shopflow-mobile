# ShopFlow --- Development Roadmap

**Status:** Proposed incremental plan\
**Planning principle:** Deliver small working increments and validate
each before expanding.

## Milestone 0 --- Product and learning foundation

**Deliverables** - Review product vision and V1 scope. - Learn essential
Dart syntax, classes and functions. - Understand widget trees, layout,
stateless/stateful widgets and forms. - Establish repository and
documentation conventions. - Run the app on an Android emulator.

**Exit criteria** - Developer can explain the basic app entry point and
widget hierarchy. - Documentation scope is reviewed. - Flutter analysis
passes.

## Milestone 1 --- UI prototype

**Deliverables** - Consistent theme and application shell. - Dashboard
layout. - Product catalogue using sample data. - Add/edit product forms
with validation. - Navigation between implemented screens. -
Empty/loading/error-state prototypes.

**Exit criteria** - Main flows are clickable and understandable. -
Sample data is clearly identified as sample data. - Layout works on the
target emulator size.

## Milestone 2 --- Cloud and account foundation

**Deliverables** - Supabase initialization and safe client
configuration. - Authentication flow. - Shop setup. - Version-controlled
database migration. - RLS policies and constraints. -
Development-environment setup instructions.

**Exit criteria** - Authenticated user can set up and access an
authorized shop. - Cross-shop access tests pass. - No privileged secret
is shipped in the client.

## Milestone 3 --- Product catalogue

**Deliverables** - Product list and details. - Add, edit and deactivate
operations. - Input validation and clear save states. -
Repository/service boundaries. - Unit, widget and integration tests for
key behavior.

**Exit criteria** - Product records persist in Supabase. - Authorization
and validation are enforced. - Failed and uncertain writes are handled
honestly.

## Milestone 4 --- Inventory foundation

**Deliverables** - Inventory balance representation. - Stock adjustment
workflow. - Stock movement history. - Low-stock indicators. -
Transactionally safe balance/movement updates.

**Exit criteria** - Adjustments preserve an auditable record. - Invalid
adjustments are rejected. - Balance and movement cannot diverge due to a
partial operation.

## Milestone 5 --- Local cache and resilience

**Deliverables** - SQLite cache schema and migration strategy. - Cache
refresh after confirmed cloud reads. - Cached product/inventory
viewing. - Last-refresh metadata. - Offline/stale UI and
connection-state behavior.

**Exit criteria** - Previously cached records are viewable offline. -
Stale data is clearly identified. - Offline writes are not queued or
misreported as saved.

## Milestone 6 --- Pilot readiness

**Deliverables** - End-to-end workflow testing. - Android device and
emulator checks. - Security and RLS review. - Error-state and
accessibility review. - Setup, troubleshooting and user guidance. -
Appropriate license decision and repository cleanup.

**Exit criteria** - Critical requirements have passing tests or
documented manual verification. - No known critical
security/data-integrity defects. - Pilot users can complete key tasks
without developer intervention.

## Later milestones (not V1 commitments)

-   Sales and sale items.
-   Atomic sale processing and stock deduction.
-   Payments and receipts if requirements justify them.
-   Purchasing and supplier workflows.
-   Reports and expenses.
-   Multi-user workflows and additional platforms.
-   Barcode support or other integrations based on validated demand.

## Work management

Break each milestone into small tasks. Each task should state its
intended behavior, dependencies, acceptance criteria and test approach.
Keep changes focused, avoid unrelated refactoring and update
documentation when decisions or behavior change.
