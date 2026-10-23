# ADR-0002: Android-first release

-   **Status:** Proposed
-   **Date:** 2026-10-20

## Context

The project needs a focused first platform to keep development and
testing manageable while the product and Flutter skills are being
developed.

## Decision

Prioritize Android phones for initial design, implementation and device
testing. Keep the codebase structured so other Flutter targets can be
considered later, but do not treat desktop support as a V1 requirement.

## Consequences

-   Test layouts, forms, navigation, persistence and connectivity on
    Android.
-   Native SQLite behavior must be validated on Android rather than
    inferred from a browser run.
-   Avoid platform-specific assumptions in business logic where a
    portable implementation is straightforward.

## Revisit when

There is validated demand for desktop or another platform and the core
mobile workflow is stable.
