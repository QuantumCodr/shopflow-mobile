# ShopFlow developer setup guide

This guide is for developers setting up the project locally or preparing a development environment.

## 1. Prerequisites

- Git.
- Flutter SDK with a Dart SDK that satisfies the `environment` constraint in `pubspec.yaml` (`^3.13.4` at the time this guide was prepared).
- Android SDK and an emulator or Android device for Android development.
- A Supabase project.
- A code editor such as Visual Studio Code or Android Studio.

Check the installed tools:

```powershell
flutter --version
dart --version
flutter doctor
```

Resolve Android toolchain issues reported by `flutter doctor` before attempting an Android build.

## 2. Clone and install dependencies

```powershell
git clone https://github.com/QuantumCodr/shopflow-mobile.git
cd shopflow-mobile
flutter pub get
```

## 3. Configure environment variables

Create `.env` from the example file:

```powershell
Copy-Item .env.example .env
```

Set the values from your Supabase project:

```dotenv
SUPABASE_URL=https://YOUR_PROJECT_ID.supabase.co
SUPABASE_PUBLISHABLE_KEY=YOUR_SUPABASE_PUBLISHABLE_KEY
```

The app reads these values in `lib/main.dart` and passes them to `Supabase.initialize()`.

Use a Supabase publishable key in the client. Never put a Supabase service-role key in a Flutter application. Client applications are distributed to end users and cannot keep service-role credentials secret.

Do not commit `.env`. Check `.gitignore` before committing any local configuration file.

## 4. Prepare Supabase

1. Create or select the Supabase project for the environment.
2. Review `SHOPFLOW_DATABASE.sql` before executing it.
3. Use the bootstrap only on a fresh, empty project. Do not rerun it as a migration on a database that already contains data.
4. Configure Supabase Auth, including the required email provider and redirect URLs for the platforms being tested.
5. Verify Row Level Security is enabled and the expected policies and database functions exist.
6. Compare the deployed database functions with the operations called by the Flutter repositories. The app currently calls `receive_stock`, `adjust_stock` and `complete_sale`; the checked-in bootstrap currently defines only `receive_stock` among those three.

There are two SQL bootstrap-style files at the repository root. Do not execute both blindly. Treat `SHOPFLOW_DATABASE.sql` as the documented canonical bootstrap and review differences before using the alternative `shopflow_supabase_fresh_install.sql` file.

## 5. Run the app

### Android

Start an emulator or connect an Android device, then run:

```powershell
flutter run
```

To list connected devices:

```powershell
flutter devices
```

### Browser development

For authentication callback testing, use a stable web-server origin:

```powershell
flutter run -d web-server --web-hostname localhost --web-port 7357
```

Open `http://localhost:7357` manually in the browser profile where you will also open authentication emails. Keep the same browser profile, hostname and port throughout a PKCE flow. Changing between `localhost` and `127.0.0.1`, changing ports, or opening the link in an isolated browser profile can prevent the browser from finding the PKCE verifier stored for the original origin.

Add the exact local redirect pattern to Supabase Auth URL Configuration. Add the Android custom-scheme redirect separately when testing native Android deep links. The exact redirect must agree with the URL created by `AuthService` and the Android manifest.

## 6. Useful development commands

Format the application:

```powershell
dart format lib
```

Analyze the code:

```powershell
dart analyze
```

Run automated tests:

```powershell
flutter test
```

Run the application:

```powershell
flutter run
```

A clean `dart analyze` result confirms static analysis only. It does not prove that Supabase authentication, database functions, checkout, email delivery or the full app flow work end to end.

## 7. Project structure

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
SHOPFLOW_DATABASE.sql
shopflow_supabase_fresh_install.sql
```

Most features follow a presentation, service and data/repository separation. See [Architecture](ARCHITECTURE.md) for the responsibilities of each layer.

## 8. Before submitting a change

1. Format changed Dart files.
2. Run `dart analyze`.
3. Run relevant tests.
4. Manually test affected workflows against a development Supabase project.
5. Update the documentation when user-visible behaviour, setup, schema, security or architecture changes.
6. Confirm no secrets or private data are included in the commit.
