# Branching & Non-Destructive Feature Workflow

This project uses a conservative, non-destructive approach for large
infrastructure changes. Follow these steps when working on the
`feature/complete-project-non-destructive` effort.

1. Create and switch to the feature branch locally (you've already done this):

```cmd
git checkout -b feature/complete-project-non-destructive
```

2. Always add new modules with `_v2` suffix or put new functionality in
   new files under `src/` and guard them using `src/core/feature_flags.py`.

3. Do NOT edit existing files directly. If you need to change behavior,
   wrap the new code behind a feature flag or add a `_v2` module and call it
   when the flag is enabled.

4. Before running migrations against Postgres, create a backup (example):

```cmd
# Dump current Postgres DB (replace variables accordingly)
pg_dump $POSTGRES_URL -Fc -f backups/pg_backup_$(date +%s).dump
# Also snapshot in-memory ContextStore (script to be added)
python scripts/backup_contextstore.py --out backups/contextstore_$(date +%s).json
```

5. CI will run compatibility tests with feature flags disabled to ensure
   existing endpoints behave unchanged. Add tests under `tests/compatibility/`.

6. When ready, open a PR from your feature branch. The `ci-non-destructive`
   workflow will run and must pass before merge.
