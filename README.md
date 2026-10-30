# ShopFlow

**ShopFlow** is a Flutter application for managing the everyday activities of a small retail shop. It brings the product catalogue, stock, checkout, sales records and business reports into one workspace.

> **Project stage:** Active development. The application should not yet be treated as production-ready. Some database operations required by the current Flutter code still need to be aligned with the checked-in SQL bootstrap and verified against a fresh Supabase project.

## What ShopFlow includes

- Account registration, sign-in and password-management screens.
- First-time shop setup and shop settings.
- Product catalogue and category management.
- Inventory balances, stock receiving and stock adjustments.
- Point of Sale (POS) cart and checkout interface.
- Sales history and business reports.
- A home dashboard with daily sales, transaction count, low-stock items and recent sales.

The screens and service/repository code for these areas are present in the application. Their end-to-end availability depends on the Supabase schema, policies and database functions being correctly installed.

## Technology

| Area | Technology |
|---|---|
| Application | Flutter / Dart |
| Authentication | Supabase Auth |
| Main database | Supabase PostgreSQL |
| Configuration | `flutter_dotenv` and a local `.env` file |
| State refresh between feature screens | `ShopFlowEvents` |

PostgreSQL is the authoritative data store. The current source does not contain a completed SQLite cache or offline transaction-sync implementation. Do not assume ShopFlow can safely complete sales while disconnected.

## Getting started

### Requirements

- Flutter SDK and Dart SDK compatible with the constraints in `pubspec.yaml`.
- Android Studio or another Android SDK installation for Android builds.
- A Supabase project with the required database schema, Row Level Security policies and database functions.
- Git.

### Local setup

1. Clone the repository:

   ```powershell
   git clone https://github.com/QuantumCodr/shopflow-mobile.git
   cd shopflow-mobile
   ```

2. Install the Dart and Flutter packages:

   ```powershell
   flutter pub get
   ```

3. Create the local environment file:

   ```powershell
   Copy-Item .env.example .env
   ```

4. Open `.env` and provide the Supabase project URL and publishable key:

   ```dotenv
   SUPABASE_URL=https://YOUR_PROJECT_ID.supabase.co
   SUPABASE_PUBLISHABLE_KEY=YOUR_SUPABASE_PUBLISHABLE_KEY
   ```

5. Configure the Supabase database using the instructions in [Database and security](docs/DATABASE_AND_SECURITY.md). The SQL bootstrap is intended for an empty project only. Do not run it as an update against a database containing data.

6. Check the project and run the application:

   ```powershell
   dart format lib
   dart analyze
   flutter run
   ```

For a browser test using a stable local origin, run:

```powershell
flutter run -d web-server --web-hostname localhost --web-port 7357
```

Then open `http://localhost:7357` in the browser profile you intend to use for the test. Keep the hostname and port unchanged during a PKCE authentication flow.

## Documentation

Start with the document that matches your role:

- [Shop user guide](docs/USER_GUIDE.md) — everyday shop workflows.
- [Developer setup guide](docs/DEVELOPER_GUIDE.md) — local setup, configuration and commands.
- [Architecture overview](docs/ARCHITECTURE.md) — application structure and data flow.
- [Database and security](docs/DATABASE_AND_SECURITY.md) — tables, money representation, RLS and required database functions.
- [Contributing guide](docs/CONTRIBUTING.md) — code and documentation practices.
- [Project status and known limitations](docs/PROJECT_STATUS.md) — verified capabilities, open work and release blockers.

The documentation index is available at [docs/README.md](docs/README.md).

## Security basics

- Never commit `.env`, passwords, access tokens, customer data or other secrets.
- The Flutter client must use the Supabase publishable key, not a service-role key.
- Keep authorization decisions in PostgreSQL Row Level Security policies and carefully reviewed database functions. Hiding a button in the UI is not access control.
- Do not run fresh-install SQL on an existing production database. Use reviewed, incremental migrations for schema changes.

## Current limitations

Read [Project status](docs/PROJECT_STATUS.md) before setting up a new database or relying on POS and stock-adjustment operations. In particular, the current Flutter repositories call `adjust_stock` and `complete_sale`, but those functions are not present in the checked-in `SHOPFLOW_DATABASE.sql` bootstrap.

## License

No license file is currently included in the repository. Until a license is selected and added, do not assume that the public repository grants permission to reuse, redistribute or modify its code.
