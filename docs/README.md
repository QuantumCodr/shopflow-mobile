# ShopFlow Documentation

This folder contains the product and engineering documentation for ShopFlow. It is intended for three groups: shop users, contributors and developers maintaining the application.

## Read by Role

| I want to… | Read |
|---|---|
| Learn how to use the shop screens | [Shop user guide](USER_GUIDE.md) |
| Install and run the project | [Developer setup guide](DEVELOPER_GUIDE.md) |
| Understand how the code is organised | [Architecture overview](ARCHITECTURE.md) |
| Understand the database and access rules | [Database and security](DATABASE_AND_SECURITY.md) |
| Make a code or documentation contribution | [Contributing guide](CONTRIBUTING.md) |
| Check what is implemented and what remains | [Project status](PROJECT_STATUS.md) |

## Documentation Rules

1. Describe behaviour that exists in the code and database, not only the intended product design.
2. Mark planned, incomplete or unverified behaviour clearly.
3. Update the relevant guide when a feature, database contract, setup step or architectural decision changes.
4. Keep instructions short and reproducible. Include exact commands and file paths where useful.
5. Never include real credentials, user data, recovery links or access tokens.

## Source of Truth

For application behaviour, inspect the current Flutter source code. For database structure and permissions, inspect both the checked-in SQL and the SQL installed in the target Supabase project.

The checked-in database file, `SHOPFLOW_DATABASE.sql`, is the single canonical V1 fresh-install definition. It is intended for a new or empty Supabase project. It does not automatically describe the state of an existing or previously modified database.

The documentation was reviewed against the repository structure and available source files on **30 October 2026**. The current `main` branch includes the web authentication callback handling discussed during development. However, the presence of code in the repository does not by itself prove that password recovery, database functions or deployed Supabase settings have been tested successfully.

Before a production release, verify the application workflows against the deployed database and confirm that the Supabase authentication configuration matches the application.