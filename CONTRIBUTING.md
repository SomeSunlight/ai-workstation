# Contributing

1. Work inside the WSL Linux filesystem, not under `/mnt/c`.
2. Keep installation entry points thin and move implementation into modules.
3. Preserve idempotency: a second run must be safe.
4. Never introduce an automatic destructive migration.
5. Update `config/versions.json`, documentation and tests together.
6. Run `./tools/release-check.sh` before committing.
