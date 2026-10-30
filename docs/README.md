# ShopFlow documentation

This folder contains the working product and engineering documentation for ShopFlow. It is written for three groups: shop users, contributors and developers maintaining the application.

## Read by role

| I want to… | Read |
|---|---|
| Learn how to use the shop screens | [Shop user guide](USER_GUIDE.md) |
| Install and run the project | [Developer setup guide](DEVELOPER_GUIDE.md) |
| Understand how the code is organised | [Architecture overview](ARCHITECTURE.md) |
| Understand the database and access rules | [Database and security](DATABASE_AND_SECURITY.md) |
| Make a code or documentation contribution | [Contributing guide](CONTRIBUTING.md) |
| Check what is implemented and what remains | [Project status](PROJECT_STATUS.md) |

## Documentation rules

1. Describe the behaviour that exists in the code and database, not only the intended product design.
2. Mark planned, incomplete or unverified behaviour clearly.
3. Update the relevant guide when a feature, database contract, setup step or architectural decision changes.
4. Keep instructions short and reproducible. Include exact commands and file paths where they help.
5. Never include real credentials, user data, recovery links or access tokens.

## Source of truth

For application behaviour, inspect the current Flutter source. For database structure and permissions, inspect the SQL installed in the target Supabase project as well as the checked-in bootstrap. The checked-in SQL is not guaranteed to match an already configured Supabase project.

The files in this documentation set were prepared against the repository structure inspected on 30 October 2026, together with the current local authentication files pasted during the development conversation. The local `main.dart` and `AuthGate` changes discussed for web password recovery were not yet reflected in the GitHub `main` branch snapshot inspected during this review. Before committing this documentation, push or otherwise reconcile the local application changes so the documented setup and the repository source describe the same version. Recheck database functions and deployed Supabase configuration before a production release.
