# ADR-0003: Online writes with offline cache reading

-   **Status:** Proposed
-   **Date:** 2026-10-20

## Context

Full offline transaction synchronization introduces conflict resolution,
duplicate prevention, retry behavior and more complex consistency rules.
Those costs are not justified for the initial product scope.

## Decision

V1 requires connectivity for protected writes. SQLite stores previously
confirmed records for offline viewing only. No offline write queue or
automatic replay is included.

## Consequences

-   Users receive clear feedback when a write cannot be confirmed.
-   Cached data must show its last refresh time or equivalent stale
    status.
-   Network failure must not automatically be treated as session
    expiration.
-   The app must not blindly retry a request whose outcome may be
    uncertain.

## Revisit when

User research demonstrates that offline writes are essential and the
team can implement and test a robust synchronization design.
