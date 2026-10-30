# Documentation replacement notes

This package is a replacement documentation set for ShopFlow. It contains a refreshed root README and a new `docs/` structure.

## Files in this package

```text
README.md
REBUILD_NOTES.md
docs/
  README.md
  USER_GUIDE.md
  DEVELOPER_GUIDE.md
  ARCHITECTURE.md
  DATABASE_AND_SECURITY.md
  CONTRIBUTING.md
  PROJECT_STATUS.md
```

## How to apply it

1. Keep the application source, platform folders, SQL files and `.env.example`.
2. Replace the repository root `README.md` with this package's `README.md`.
3. Replace the old documentation files in `docs/` with the new files in this package.
4. Retire the old numbered product-design documents and old ADR files only after checking whether any decision or requirement still needs to be carried forward. Their contents are not automatically preserved in this new practical documentation set.
5. Review the database status against the actual Supabase project before publishing the documentation as current.
6. Commit the documentation separately from application-code changes so the review is easy to follow.

The archive does not delete or modify any GitHub repository files by itself.
