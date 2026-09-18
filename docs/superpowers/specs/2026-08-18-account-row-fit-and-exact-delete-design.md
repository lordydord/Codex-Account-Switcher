# Account Row Fit and Exact Delete Design

## Goal

Keep every account-row control visible at the actual `NSTableView` content width, tint the reset-chance bolt yellow, and make swipe deletion target exactly the selected account.

## Layout

- Derive the right-side progress, percentage, and confirmation-button frames from the row view's actual width rather than the panel's nominal 520-point width.
- Reserve a right inset inside every row so the percentage and buttons remain clear of the table edge and overlay scroller.
- Keep the current typography and button sizes. Move the confirmation controls left as a single trailing-aligned group.
- Give the email/prompt area the width left over before that trailing group, preventing overlap at the minimum supported row width.
- Keep the panel's outer dimensions unchanged.

## Reset Chance Icon

- Render the existing `bolt.fill` symbol with a warm system-yellow tint.
- Do not change the card, title, forecast values, or spacing.

## Exact Account Removal

- Build `codex-auth remove` arguments from the selected account's full email, not its display selector/index.
- Reject active accounts, empty values, flag-like values, and any request that could become `--all`.
- Preserve direct row-to-account mapping from the native table action.
- Keep deletion immediate after pressing the revealed native Delete action.

## Verification

- Unit-test removal arguments with two similar emails and confirm the selected full email is passed unchanged.
- Add layout-policy tests proving the percentage and both confirmation buttons fit within representative and minimum row widths.
- Keep the AppKit row mapping tests for selection and deletion.
- Run the complete test suite, full macOS build, install verification, and binary checksum comparison.
- Do not perform a visual review; the user will inspect the installed build.
