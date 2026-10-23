# ShopFlow --- Testing Strategy

**Status:** Initial strategy for V1

## 1. Objectives

Testing should protect user-visible behavior, business rules, data
integrity and access control. Tests should be meaningful and
maintainable, not added solely to produce a high test count.

## 2. Test levels

### Unit tests

Test isolated Dart logic such as: - Product validation and
normalization. - Low-stock calculation. - Quantity adjustment rules. -
Currency/quantity formatting helpers. - Service-level business rules
using controlled dependencies.

### Widget tests

Test important UI behavior: - Required-field validation. -
Disabled/loading save state. - Empty and error states. - Product list
rendering. - Navigation selection and key interactions. - Visible
stale/offline indicators.

### Repository and integration tests

Test data mapping and interactions with persistence using controlled
test dependencies or a dedicated development backend: - Cloud response
mapping. - Cache update after confirmed reads/writes. - Cache fallback
behavior when cloud reads fail. - Cache freshness metadata. - Handling
of uncertain write outcomes. - SQLite schema creation and upgrades.

### Security tests

Test RLS and database constraints with multiple users and shops. Do not
rely on tests run only as the privileged project owner.

### Manual device tests

Test on an Android emulator and, when available, a real device: - Small
screen sizes and text scaling. - Keyboard behavior in forms. - Loss and
restoration of connectivity. - App restart and cache persistence. -
Session expiration. - Error messages and recovery paths.

## 3. Critical scenarios

1.  Valid product is saved and appears after cloud confirmation.
2.  Invalid name, price or quantity is rejected.
3.  A failed cloud read does not appear as a genuine empty catalogue.
4.  Cached records can be displayed offline with freshness information.
5.  Offline writes are not silently accepted or queued in V1.
6.  A request timeout does not trigger a blind duplicate write.
7.  Deactivation preserves historical references.
8.  Stock adjustment and movement creation either both succeed or
    neither is committed.
9.  Users cannot access another shop's data.
10. Future sale processing prevents overselling and duplicate
    transaction submission.

## 4. Test doubles and dependency boundaries

Use interfaces or small abstractions where they help isolate business
behavior from external systems. Do not create unnecessary mock layers
for every class. Prefer testing meaningful service behavior and
integration boundaries rather than testing trivial repository methods in
isolation without added value.

## 5. Development checks

Before committing a focused change: - Run `dart format` on changed Dart
files. - Run `flutter analyze`. - Run relevant tests with
`flutter test`. - Manually test user-facing behavior when the change
affects interaction, layout, persistence or connectivity.

## 6. Test data

Use synthetic data. Never use real customer data, credentials or
production exports in automated tests. Tests should be repeatable and
should not depend on the current production database.

## 7. Release criteria

A release candidate should have: - No known critical data-integrity or
authorization defect. - Passing automated tests for the main
workflows. - Reviewed RLS policies and constraints. - Tested cache
behavior and stale-data messaging. - Verified error handling for network
and authentication failures. - No privileged secrets in the client or
repository. - Updated setup and user documentation.
