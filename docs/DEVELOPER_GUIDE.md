# ShopFlow Developer Setup Guide

This guide explains how to prepare a local development environment, configure Supabase and run ShopFlow.

## 1. Prerequisites

You need:

- Git.
- Flutter SDK with a Dart SDK that satisfies the `environment` constraint in `pubspec.yaml` (`^3.13.4` at the time of this guide).
- Android SDK and an emulator or Android device for Android development.
- A Supabase project.
- A code editor such as Visual Studio Code or Android Studio.

Check your installed tools:

```powershell
flutter --version
dart --version
flutter doctor
```

Resolve relevant Flutter and Android toolchain issues reported by `flutter doctor` before attempting an Android build.

## 2. Clone the Repository and Install Dependencies

```powershell
git clone https://github.com/QuantumCodr/shopflow-mobile.git
cd shopflow-mobile
flutter pub get
```

## 3. Configure Environment Variables

Create a local `.env` file from the example:

```powershell
Copy-Item .env.example .env
```

Open `.env` and enter the values from your Supabase project:

```dotenv
SUPABASE_URL=https://YOUR_PROJECT_ID.supabase.co
SUPABASE_PUBLISHABLE_KEY=YOUR_SUPABASE_PUBLISHABLE_KEY
```

The application reads these values in `lib/main.dart` and passes them to `Supabase.initialize()`.

Use a Supabase publishable key in the Flutter client. Never put a service-role key in application code or a client-side environment file. A distributed client application cannot keep service-role credentials secret.

Do not commit `.env`. The repository provides `.env.example` as a template. You can check whether your local file is ignored by Git with:

```powershell
git check-ignore .env
```

## 4. Prepare Supabase

1. Create a new Supabase project or select the project intended for development.
2. Review the root-level `SHOPFLOW_DATABASE.sql` file.
3. Run this file only against a new or empty Supabase project.
4. Configure Supabase Authentication and enable the email provider required by the application.
5. Configure the authentication redirect URLs described in the next section.
6. Verify that the expected tables, Row Level Security (RLS) policies and database functions exist.

`SHOPFLOW_DATABASE.sql` is the single canonical V1 fresh-install database file. It includes the database functions called by the current Flutter repositories:

- `receive_stock`
- `adjust_stock`
- `complete_sale`

The functions handle stock receiving, stock adjustments and completed sales through database operations.

**Important:** Do not run the fresh-install SQL over an existing database or use it as an incremental migration. It is intended for a fresh installation. Existing databases must be updated through properly reviewed migrations.

The repository may also contain the older `shopflow_supabase_fresh_install.sql` file. Treat it as legacy documentation or setup material, not as an alternative to the canonical database file. Do not execute both scripts.

## 5. Configure Authentication Redirects

ShopFlow uses Supabase Auth for account access and password recovery.

The current application uses different callback handling for web and native Android.

### Web authentication

For local browser development, start the web server using a stable origin:

```powershell
flutter run -d web-server --web-hostname localhost --web-port 7357
```

Open this address manually:

```text
http://localhost:7357
```

Add the following redirect URL to the Supabase Authentication URL Configuration:

```text
http://localhost:7357/
```

The web application handles authentication callbacks manually through `AuthGate`. Keep the same browser profile, hostname and port throughout a password-recovery flow.

Changing between `localhost` and `127.0.0.1`, changing ports or opening the recovery email in a different browser profile can prevent the browser from finding the original PKCE verifier.

### Android authentication

The current Android password-recovery redirect is:

```text
io.shopflow.app://reset-password
```

Add this URL to the allowed redirect URLs in Supabase Authentication.

The Android manifest also contains an intent filter for this scheme and host. If the redirect changes, keep the following in agreement:

- The redirect created by `AuthService`.
- The Android manifest intent filter.
- The allowed redirect URLs in Supabase.

Authentication email delivery and recovery behaviour must be tested against the actual Supabase project configuration.

## 6. Run the Application

### Android

Start an Android emulator or connect a device with USB debugging enabled.

List available devices:

```powershell
flutter devices
```

Run ShopFlow:

```powershell
flutter run
```

### Browser

Use the web-server command from the authentication section when you need a stable local origin for authentication callback testing:

```powershell
flutter run -d web-server --web-hostname localhost --web-port 7357
```

Then open `http://localhost:7357` in your browser.

## 7. Useful Development Commands

Install or refresh dependencies:

```powershell
flutter pub get
```

Format Dart source files:

```powershell
dart format lib
```

Analyze the Flutter project:

```powershell
flutter analyze
```

Run automated tests:

```powershell
flutter test
```

List connected devices:

```powershell
flutter devices
```

Run the application:

```powershell
flutter run
```

A successful static analysis result does not prove that Supabase authentication, database functions, checkout, email delivery or complete application workflows work correctly. Test affected workflows against a development Supabase project.

## 8. Project Structure

The main application source is organised as follows:

```text
lib/
  app.dart
  main.dart
  core/
    config/
    validation/
  features/
    authentication/
    categories/
    home/
    inventory/
    pos/
    products/
    reports/
    sales_history/
    settings/
    shell/
    shop_setup/
    stock_movements/
  shared/
    formatters/
    state/
    theme/
    time/
    widgets/

test/
docs/

.env.example
SHOPFLOW_DATABASE.sql
```

Most features follow a presentation, service, data/repository and models separation:

- `presentation/` contains screens and user interaction.
- `services/` contains validation and business-use-case coordination.
- `data/` contains repositories responsible for Supabase access.
- `models/` contains typed application data structures.

See [ARCHITECTURE.md](ARCHITECTURE.md) for a fuller explanation of the application layers and their responsibilities.

## 9. Offline Support

The current application relies on Supabase for its working data.

A complete local database cache and offline transaction synchronisation are not implemented. Do not assume that the presence of packages such as `sqflite` or `connectivity_plus` means that offline sales or inventory synchronisation is available.

Maintain an internet connection when performing important shop operations.

## 10. Before Submitting a Change

Before submitting code or documentation changes:

1. Format changed Dart files.
2. Run `flutter analyze`.
3. Run relevant automated tests.
4. Manually test affected workflows against a development Supabase project.
5. Update documentation when user-visible behaviour, setup, database contracts, security or architecture changes.
6. Confirm that no credentials, tokens or private user data are included in the commit.

Database changes should be reviewed separately from application changes. Verify new or modified functions, policies, constraints and repository contracts before treating a database feature as complete.