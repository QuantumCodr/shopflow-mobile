# Contributing to ShopFlow

ShopFlow is being developed with a preference for understandable code, small changes and clear business rules. Contributions should improve the application without making it harder to explain, test or maintain.

## 1. Before Changing Code

1. Read the relevant user workflow in the [user guide](USER_GUIDE.md).
2. Read the [architecture overview](ARCHITECTURE.md) to understand the feature layers.
3. Check [project status](PROJECT_STATUS.md) for known limitations and unfinished work.
4. Inspect the current code and deployed database before assuming that the checked-in schema matches the working environment.

## 2. Follow the Existing Feature Structure

Most features are separated into:

- `presentation/` for screens, forms and UI state.
- `services/` for validation and use-case coordination.
- `data/` for Supabase access through repositories.
- `models/` for typed data structures.

Keep SQL table access and Supabase calls in repositories. Keep business validation in services. Keep screens focused on user interaction, loading states and feedback.

Follow the existing structure when adding or changing features. Avoid introducing new architectural patterns without a clear reason.

## 3. Data and Security Rules

- Use Supabase Auth for the current user's identity.
- Enforce shop access in PostgreSQL through Row Level Security (RLS) and trusted database functions.
- Never put a service-role key in client code or in an application environment file.
- Do not rely on the UI to enforce authorization.
- Use trusted, atomic PostgreSQL functions for operations that update multiple related records, especially stock and sales.
- Do not enable broad direct-write permissions simply to make a screen work.
- Keep the app's database calls, function parameters and SQL definitions aligned.

`SHOPFLOW_DATABASE.sql` is the single canonical V1 fresh-install database file. Do not introduce another competing fresh-install SQL file. Changes to an existing database should be handled through an appropriate migration, not by rerunning the fresh-install file over existing data.

## 4. Money and Quantity Rules

- Store money as integer minor units. In the current SLE representation, 100 minor units equal SLE 1.00.
- Use the shared SLE money formatter and parser rather than introducing floating-point currency calculations.
- Treat inventory quantity and POS quantity as separate contracts until fractional sale support is implemented.
- Keep Dart validation and PostgreSQL constraints aligned.
- If a product unit, movement type or quantity rule changes, update both sides and document the change.

## 5. Time Rules

Use `ShopFlowTime` for business-day boundaries and timestamp conversion. ShopFlow currently treats Sierra Leone business time as UTC+00:00.

Avoid using the developer computer's local timezone to calculate business-day totals.

## 6. State and Refresh Behaviour

Where a screen depends on data that another feature can modify, follow the existing `ShopFlowEvents` data revision pattern where appropriate.

A refresh notification should trigger a new read from the repository or service. It must not be used as a substitute for persisting data.

## 7. Error Handling

- Validate user input before making a request.
- Return understandable messages for expected validation and repository failures.
- Preserve useful technical details in debug logs, but do not expose credentials, tokens or private data.
- Avoid silently swallowing failed database operations.
- For checkout, distinguish a rejected transaction from an ambiguous server response. Do not automatically submit the same transaction again when its first outcome is uncertain.

## 8. Tests and Development Checks

Before submitting a change, run these commands from the project root:

```powershell
dart format lib
flutter analyze
flutter test
```

Then manually test the affected workflow against a development Supabase project.

Static analysis does not prove that database operations, security policies or authentication redirects work correctly end to end.

Add tests for new validation rules, model parsing, calculations and state behaviour. For database changes, verify the affected functions, policies, constraints and schema against a development database.

## 9. Documentation Updates

Update the relevant documentation when a change affects:

- A user workflow or screen.
- Environment setup or platform configuration.
- Database tables, columns, constraints, RLS policies or functions.
- Business rules, monetary calculations or time handling.
- Architecture or project limitations.

Documentation should clearly state whether a behaviour is implemented, planned or still unverified.

## 10. Pull Request Checklist

Before submitting a contribution, check that:

- [ ] The change is focused and has a clear purpose.
- [ ] Existing architecture and naming conventions are followed.
- [ ] Input validation and error handling are included.
- [ ] Database security and transaction behaviour are reviewed where relevant.
- [ ] Formatting and static analysis pass.
- [ ] Relevant tests are added or updated.
- [ ] Documentation is updated where necessary.
- [ ] No secrets or real customer data are included.