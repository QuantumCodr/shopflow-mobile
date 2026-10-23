# ShopFlow --- Data Access and Security

**Status:** Proposed baseline; review before protected operations are
enabled.

## 1. Security objective

ShopFlow must ensure that each authenticated user can access only the
shops and records they are authorized to use. Hiding records in the UI
is not authorization. The database must enforce access independently of
client behavior.

## 2. Authentication

-   Use Supabase Auth for account identity.
-   Authentication initially requires internet connectivity.
-   Distinguish a network/service failure from an expired or invalid
    session.
-   A failed network request must not automatically be interpreted as a
    sign-out.
-   Provide an appropriate sign-out path and avoid logging tokens or
    credentials.
-   Account recovery and session-expiration UX must be designed before
    release.

## 3. Client configuration and secrets

-   The Flutter client may use the Supabase project URL and
    publishable/anon client key intended for client applications.
-   Never embed a Supabase service-role key, database password or other
    privileged secret in the mobile application.
-   Treat all client input as untrusted.
-   Keep local development secrets out of Git; provide a safe example
    configuration without real values.
-   Review logs, crash reports and build artifacts for accidental secret
    exposure.

## 4. Authorization and RLS

Enable Row Level Security on exposed shop-owned tables and create
policies based on authenticated identity and verified shop membership.

Policies must cover the relevant operations individually: - SELECT -
INSERT - UPDATE - DELETE, only where deletion is allowed at all

For inserts and updates, ensure both the existing row and proposed row
belong to a shop the user may access. A client must not be able to
change `shop_id` to move a record into another tenant.

Membership and role changes require particular care. Users must not be
able to grant themselves access or elevate their own role through a
permissive policy. Test policies using at least two different users and
two shops.

## 5. Data validation

Validate data at multiple layers: - UI validation for immediate
feedback. - Service-level business rules for consistent application
behavior. - PostgreSQL constraints and authorized server-side operations
for integrity and security.

Client-side checks are not a security boundary.

## 6. Cloud write behavior

-   Show success only after cloud confirmation.
-   Disable or guard repeated submission while a request is in progress.
-   Use stable client-generated UUIDs where suitable.
-   For operations that may be repeated, consider idempotency keys or
    unique constraints.
-   Treat timeouts after submission as an unknown outcome when the
    server may have committed the operation.
-   Verify the resulting cloud state before retrying potentially
    duplicate or non-idempotent operations.

## 7. Inventory write security

Stock adjustments affect business-critical data. The authorized
operation must validate: - The user has permission for the shop. - The
product belongs to that shop. - The requested quantity and reason are
valid. - The resulting balance obeys the negative-stock policy. - The
balance update and movement insertion occur atomically.

Prefer a carefully designed database function or another transactionally
safe server-side operation where needed. Do not expose an unrestricted
function that lets callers manipulate arbitrary shop IDs or stock
balances.

## 8. Offline cache and privacy

-   Cache only data required for the product's offline-viewing behavior.
-   Identify cached data as potentially stale.
-   Do not accept offline writes in V1.
-   Consider device access, shared-device behavior and whether cached
    business data should be cleared at sign-out.
-   Avoid storing authentication secrets in the application database.
-   Define cache cleanup and schema migration behavior.

## 9. Error messages and logging

User-facing messages should be understandable and should not expose
internal database details. Development logs may include safe diagnostic
context but must exclude passwords, tokens, privileged keys and
unnecessary customer/business data.

## 10. Security test checklist

-   User A cannot read User B's shop data without membership.
-   User A cannot insert a record into an unauthorized shop.
-   User A cannot change a record's shop scope to bypass policy.
-   A user cannot grant themselves an owner role.
-   Invalid foreign-key relationships are rejected.
-   Stock adjustments cannot create an unauthorized or inconsistent
    balance.
-   Expired authentication is distinguished from network loss.
-   The application contains no service-role secret.
-   RLS policies are tested with multiple users, not only the project
    owner.

## 11. Release gate

Do not enable protected production data operations until RLS and
constraints have been reviewed and tested. A successful request from the
project owner account alone is not sufficient evidence of secure
authorization.
