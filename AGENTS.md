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
- Current local app update is v1.34 / build 134 plus local API-mode rollback: usage refresh freshness when values do not numerically change, clearer inactive-account usage styling without per-card freshness badges, switch previews, expanded health checks, GitHub update checking, macOS 27 menu-bar stability, tighter percentage padding, click-again-to-close panel behavior, three/four-account compact grid, ChatGPT-account-only switching, expired-login detection for 400/401 usage responses, safer Codex relaunch when helper processes remain, and refined inactive-account usage colours in the panel.

Potential v2.5 idea:

- Consider a separate "Cheap Agent" / Route B mode instead of trying to make a third-party model fully replace Codex Desktop.
- The app could store provider profiles in Keychain and launch a local helper that exposes only a limited, tested tool set: selected MCP calls, simple file/folder checks, Ego Browser or Chrome browser reads/clicks, page scraping, and harmless draft/check workflows.
- Treat each third-party model as capability-tested rather than trusted by default. Show capability states such as chat only, MCP-safe, browser-safe, and live-ops unsafe.
- Require smoke tests before enabling browser or MCP use: open/read a page, perform a harmless click/type, call one selected MCP, process the tool result, and continue coherently.
- Keep native Codex as the fallback and default for public, irreversible, account-sensitive, or upload/send tasks such as Traxsource, Kit, Prime, SoundCloud, Bandcamp, invoices, and account switching.
- Keep all provider keys, local routing files, account emails, and actual auth state out of the public repository.
