# ADR-0001: Supabase is the authoritative source of truth

-   **Status:** Proposed
-   **Date:** 2026-10-20

## Context

ShopFlow needs persistent shared records and may later support multiple
devices and authorized users. A local-only database would make sharing
and recovery harder. The application also needs some offline viewing
capability.

## Decision

Supabase PostgreSQL is authoritative for shared business records. SQLite
stores a local cache of previously confirmed cloud data for offline
viewing and read performance.

V1 does not support offline writes or a pending synchronization queue.

## Consequences

### Positive

-   One authoritative record set for shared data.
-   Simpler consistency model for the initial release.
-   Offline viewing remains possible for cached records.

### Trade-offs

-   Critical writes require connectivity and cloud confirmation.
-   Cached information may be stale and must be labelled.
-   A request timeout may leave the write outcome uncertain; the app
    must verify before retrying potentially duplicative operations.

## Revisit when

Offline transaction entry becomes a validated requirement and the
project is ready to design conflict resolution, idempotency,
synchronization and audit behavior.
