# ShopFlow

**ShopFlow** is a Flutter application for managing the everyday activities of a small retail shop. It brings the product catalogue, inventory, checkout, sales records and business reports into one workspace.

> **Project stage:** Active development. ShopFlow is not yet production-ready. Its core application structure and V1 database definition are in place, but database installation, authentication, business workflows and security still require end-to-end verification.

## What ShopFlow Includes

- Account registration, sign-in and password-management screens.
- First-time shop setup and shop settings.
- Product catalogue and category management.
- Inventory balances, stock receiving and stock adjustments.
- Point of Sale (POS) cart and checkout.
- Sales history and business reports.
- A home dashboard with daily sales, transaction count, low-stock items and recent sales.

The application contains screens, services and repositories for these areas. Complete operation depends on correctly configured Supabase authentication, database schema, security policies and functions.

## Technology

| Area | Technology |
|---|---|
| Application | Flutter / Dart |
| Authentication | Supabase Auth |
| Main database | Supabase PostgreSQL |
| Configuration | `flutter_dotenv` and a local `.env` file |
| Shared feature refresh | `ShopFlowEvents` |

PostgreSQL is the authoritative data store. The current source does not contain a completed SQLite cache or offline transaction-sync implementation. ShopFlow cannot safely complete sales or inventory transactions while disconnected.

## Getting Started

### Requirements

- Flutter SDK and Dart SDK compatible with the constraints in `pubspec.yaml`.
- Android Studio or another Android SDK installation for Android development.
- A Supabase project.
- Git.

### Local Setup

1. Clone the repository:

   ```powershell
   git clone https://github.com/QuantumCodr/shopflow-mobile.git
   cd shopflow-mobile
   ```

2. Install the project dependencies:

   ```powershell
   flutter pub get
   ```

3. Create the local environment file:

   ```powershell
   Copy-Item .env.example .env
   ```

4. Open `.env` and provide your Supabase project URL and publishable key:

   ```dotenv
   SUPABASE_URL=https://YOUR_PROJECT_ID.supabase.co
   SUPABASE_PUBLISHABLE_KEY=YOUR_SUPABASE_PUBLISHABLE_KEY
   ```

5. Configure the Supabase database using [Database and Security](docs/DATABASE_AND_SECURITY.md).

   The canonical `SHOPFLOW_DATABASE.sql` file is intended for a new or empty Supabase project only. Do not run it over an existing database containing data.

6. Check and run the application:

   ```powershell
   dart format lib
   flutter analyze
   flutter test
   flutter run
   ```

### Browser Development

For browser testing with a stable local origin, run:

```powershell
flutter run -d web-server --web-hostname localhost --web-port 7357
```

Then open:

`http://localhost:7357`

Keep the hostname, port and browser profile unchanged during a PKCE authentication flow. See the [Developer Setup Guide](docs/DEVELOPER_GUIDE.md) for authentication redirect configuration.

## Database

`SHOPFLOW_DATABASE.sql` is the single canonical V1 fresh-install database definition.

It includes the application schema, indexes, Row Level Security policies, authentication and inventory triggers, and the three business functions used by the current Flutter repositories:

- `receive_stock` — receives stock and records the movement.
- `adjust_stock` — adjusts inventory and records the movement.
- `complete_sale` — validates and records a sale, updates inventory and records sale movements.

The SQL definition has been inspected, but a successful fresh installation and end-to-end test against a separate Supabase project are still required.

Do not execute the older `shopflow_supabase_fresh_install.sql` as an alternative setup script. Existing databases should be updated through reviewed incremental migrations.

## Documentation

Start with the document that matches your role:

- [Shop User Guide](docs/USER_GUIDE.md) — everyday shop workflows.
- [Developer Setup Guide](docs/DEVELOPER_GUIDE.md) — local setup, configuration and commands.
- [Architecture Overview](docs/ARCHITECTURE.md) — application structure and data flow.
- [Database and Security](docs/DATABASE_AND_SECURITY.md) — tables, money representation, RLS and database functions.
- [Contributing Guide](docs/CONTRIBUTING.md) — code and documentation practices.
- [Project Status](docs/PROJECT_STATUS.md) — implemented features, known limitations and remaining work.

The documentation index is available at [docs/README.md](docs/README.md).

## Security Basics

- Never commit `.env`, passwords, access tokens, customer data or other secrets.
- The Flutter client must use the Supabase publishable key, never a service-role key.
- Enforce authorization through PostgreSQL Row Level Security policies and carefully reviewed database functions.
- Do not rely on hiding a button in the interface as a security measure.
- Do not run fresh-install SQL against an existing production database. Use reviewed, incremental migrations for schema changes.

## Current Limitations

- A complete SQLite cache and offline transaction synchronization are not implemented.
- Fractional inventory quantities are supported, but POS currently accepts whole-number quantities only.
- Database installation and business workflows still require end-to-end verification.
- Password recovery requires testing on both web and Android.
- Automated test coverage remains incomplete.
- V1 supports one shop per account owner; employee roles and multi-shop access are not implemented.

See [Project Status](docs/PROJECT_STATUS.md) for the current implementation and verification checklist.

## License

ShopFlow is licensed under the **Apache License, Version 2.0**.

You may use, modify and distribute the project under the terms and conditions of this licence. See the [`LICENSE`](LICENSE) file for the complete licence text.

SPDX-License-Identifier: Apache-2.0