# Codex Account Switcher Project Notes

This project is a sanitized public version of Graham's local Codex Account Switcher menu-bar app.

Rules for future work:

- Do not commit local Codex auth files, account registries, tokens, account IDs, email addresses, or build artifacts.
- Keep `build/`, `.swiftpm/`, `.build/`, and module caches ignored.
- The public toolbar account label must remain generic: use the first alphanumeric character from the email address unless the user sets a custom label in the app.
- Keep switching based on account email queries, not padded numeric selectors such as `01` or `02`.
- The app depends on `codex-auth`; do not vendor or copy private `~/.codex/accounts` data into the repository.
- Build verification is `./build.sh`.
- Install verification is `./install.sh`, then confirm the app runs from `/Applications/Codex Account Switcher.app`.
