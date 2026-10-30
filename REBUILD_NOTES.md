# Documentation Replacement Notes

This document records the replacement documentation set for ShopFlow. The package contains an updated root README and a refreshed `docs/` structure.

## 1. Files in the Documentation Set

```text
README.md
LICENSE
REBUILD_NOTES.md
SHOPFLOW_DATABASE.sql
docs/
  README.md
  USER_GUIDE.md
  DEVELOPER_GUIDE.md
  ARCHITECTURE.md
  DATABASE_AND_SECURITY.md
  CONTRIBUTING.md
  PROJECT_STATUS.md
  PHASE_2_DATA_MODEL.md
```

## 2. Applying the Documentation

1. Keep the application source code, platform folders, `.env.example` and required project configuration.
2. Replace the repository root `README.md` with the refreshed README.
3. Replace the existing documentation files in `docs/` with the reviewed versions.
4. Keep `SHOPFLOW_DATABASE.sql` as the single canonical V1 fresh-install database file. Do not treat an older duplicate SQL script as an alternative setup file.
5. Review older numbered product-design documents and Architecture Decision Records (ADRs) before retiring them. Carry forward any important requirements, decisions or constraints that are still relevant.
6. Check database documentation against the actual Supabase project. The checked-in SQL describes the intended fresh-install structure; it does not prove that an existing database has the same schema or functions.
7. Commit documentation changes separately from application-code or database changes so that the review history remains clear.

## 3. Scope and Limitations

This documentation replacement does not change application code, modify the Supabase database or automatically delete existing repository files.

It is a manual documentation update. Each replacement must be reviewed and committed to the repository.

## 4. Final Review

Before treating the documentation refresh as complete:

- Confirm that all listed files exist in the repository.
- Check that internal links point to the correct files.
- Confirm that setup instructions match the current project configuration.
- Confirm that database functions and security policies match the intended V1 application behaviour.
- Preserve relevant decisions from older design documents and ADRs.
- Clearly identify features or workflows that remain incomplete or unverified.

The goal is one clear, consistent documentation set that helps users, contributors and developers understand the current ShopFlow project without confusing planned features with implemented behaviour.