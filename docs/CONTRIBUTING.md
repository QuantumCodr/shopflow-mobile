# Contributing to ShopFlow

ShopFlow is being developed with a preference for understandable code, small changes and clear business rules. Contributions should improve the application without making it harder to explain, test or maintain.

## 1. Before changing code

1. Read the relevant user workflow in [the user guide](USER_GUIDE.md).
2. Read [the architecture overview](ARCHITECTURE.md) to understand the feature layers.
3. Check [project status](PROJECT_STATUS.md) for known limitations and unfinished database contracts.
4. Inspect the current code and deployed database before assuming that the checked-in schema matches the working environment.

## 2. Follow the existing feature structure

Most features are separated into:

- `presentation/` for screens, forms and UI state.
- `services/` for validation and use-case coordination.
- `data/` for Supabase access through repositories.
- `models/` for typed data structures.

Keep SQL table names and Supabase calls in repositories. Keep business validation in services. Keep screens focused on user interaction, loading states and feedback.

## 3. Data and security rules

- Use Supabase Auth for the current user's identity.
- Enforce tenant/shop access in PostgreSQL with RLS and database functions.
- Never add a service-role key to client code or `.env` distributed with the application.
- Do not rely on the UI to enforce authorization.
- Use trusted, atomic PostgreSQL functions for operations that update multiple related records, especially stock and sales.
- Do not enable broad direct-write permissions simply to make a screen work.

## 4. Money and quantity rules

- Store money as integer minor units. In the current SLE representation, 100 minor units equal SLE 1.00.
- Use the shared SLE money formatter/parser rather than introducing floating-point currency calculations.
- Treat inventory quantity and POS quantity as separate contracts until fractional sale support is implemented.
- Keep Dart validation and PostgreSQL constraints aligned. If a unit or movement type changes, update both sides and document the change.

## 5. Time rules

Use `ShopFlowTime` for business-day boundaries and timestamp conversion. ShopFlow currently treats Sierra Leone business time as UTC+00:00. Avoid using the developer computer's local timezone to calculate business-day totals.

## 6. State and refresh behaviour

Where a screen depends on data that another feature can modify, follow the existing `ShopFlowEvents` data revision pattern where appropriate. A refresh notification should trigger a new read from the repository/service; it should not be used as a substitute for persisting data.

## 7. Error handling

- Validate user input before making a request.
- Return understandable messages for expected validation and repository failures.
- Preserve technical details in debug logs where useful, but do not expose credentials, tokens or private data.
- Avoid silently swallowing failed database operations.
- For checkout, distinguish a rejected transaction from an ambiguous server response. Do not encourage an automatic second submission if the first outcome is uncertain.

## 8. Tests and checks

Before submitting a change, run:

```powershell
dart format lib
dart analyze
flutter test
```

Then manually test the affected workflow against a development Supabase project. Static analysis does not prove database operations or authentication redirects work end to end.

Add tests for new validation rules, model parsing, calculations and state behaviour. Add database verification for any new function, policy or schema change.

## 9. Documentation updates

Update the relevant documentation when a change affects:

- A user workflow or screen.
- Environment setup or platform configuration.
- Database tables, columns, constraints, RLS or functions.
- Business rules, monetary calculations or time handling.
- Architecture or project limitations.

Documentation should say whether a behaviour is implemented, planned or still unverified.

## 10. Pull request checklist

- [ ] Change is focused and has a clear purpose.
- [ ] Existing architecture and naming conventions are followed.
- [ ] Validation and error handling are included.
- [ ] Database security and transaction behaviour are reviewed where relevant.
- [ ] Formatting and static analysis pass.
- [ ] Relevant tests are added or updated.
- [ ] Documentation is updated.
- [ ] No secrets or real customer data are included.
