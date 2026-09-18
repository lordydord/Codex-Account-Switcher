# Pool Sufficiency Forecast — Design

**Date:** 2026-08-20  
**Status:** Approved in product discussion; visual direction C selected

## Context

The lower pool card currently compares a linear exhaustion estimate with only the earliest account reset. This can produce a definitive “Не хватает до сброса” even when the probabilistic forecast disagrees, and it does not model how many accounts reset or when each account resets during the week.

The card should answer one question: whether the currently added accounts are sufficient for the user's recent average work pace, given every account's current weekly balance and individual reset date.

The dynamic countdown shown elsewhere remains unchanged and is not duplicated in this card.

## Approved behavior

### Forecast horizon and pace

- Forecast the next rolling seven days from `now`.
- Use observed gross consumption over the latest available history, capped at seven days. Balance increases caused by resets or newly added capacity do not count as negative consumption.
- With at least two comparable samples but less than seven days of elapsed history, calculate the same forecast and label it `Предварительный прогноз` / `Preliminary forecast`.
- With seven or more days of usable history, omit the preliminary label and treat the rolling seven-day pace as established.
- With fewer than two comparable samples or no positive observed consumption, show the existing collecting state instead of inventing a quota-based pace.

### Event simulation

- Start with the current remaining percentage of every active account.
- Preserve an optional weekly reset date on every `PoolAccountSample`; keep decoding old history records that do not contain this field.
- Simulate constant consumption at the observed pool-points-per-day pace through the next seven days.
- Before each reset, spend from accounts whose reset occurs sooner. This represents the maximum usable capacity available to an account switcher and avoids wasting balance that is about to reset.
- At an account's reset event, restore that account to 100%. Simultaneous reset events restore every affected account.
- An account with an unknown reset date contributes its current remaining balance but no assumed replenishment.
- The verdict is `Не хватает до сброса` / `Not enough until reset` if the simulated pool reaches zero before any required replenishment event or before the end of the seven-day horizon. Otherwise it is `Хватает до сброса` / `Enough until reset`.
- The forecast must therefore respect both constraints: the gaps between reset events and the total capacity available during the complete seven-day horizon.

### Forecast output

The pure forecast model returns enough information for presentation without repeating calculation logic in the UI:

- verdict kind: enough, not enough, or collecting;
- whether the forecast is preliminary;
- observed pace and history span;
- expected seven-day demand;
- usable capacity during the seven-day simulation;
- coverage ratio (`usable capacity / expected demand`);
- first projected exhaustion date, when applicable;
- reset events inside the horizon, grouped by time with account counts;
- current account count and approximate account count required for the observed pace.

The required account count is an explanatory approximation: `ceil(expected seven-day demand / 100)`. It does not replace the event simulation used for the verdict.

## Approved presentation: option C

Replace the current three-event scale inside `PoolVerdictCardView` with a compact hybrid forecast while retaining the existing card size, corner treatment, semantic colors, and titles.

### Header

- Primary title remains exactly `Хватает до сброса` or `Не хватает до сброса` (localized in English as today).
- Secondary line:
  - preliminary: `Предварительный прогноз · темп за N дн.`;
  - established: `Средний темп за 7 дней`.
- Right summary:
  - enough: signed positive reserve percentage, for example `+18%`, caption `запас`;
  - not enough: signed negative coverage gap, for example `−16%`, caption `дефицит`.
- Percentages are rounded to whole numbers. The card does not show precise token or pool-point amounts.

### Capacity track

- One horizontal track represents 100% of the expected seven-day demand.
- The fill represents forecast usable capacity, capped visually at the track width.
- A thin terminal marker indicates the required capacity.
- Enough uses the existing mint semantic color; not enough uses the existing coral/red semantic color.
- The track is explanatory only; verdict computation remains in the pure forecast model.

### Reset indicators

- Beneath the track, show up to three compact reset indicators ordered by time, such as `2 д 22 ч · ×2`.
- `×N` is shown only when multiple accounts reset at that time; a single reset shows only its interval.
- If more than three reset groups occur, the final indicator summarizes the remainder as `ещё N` / `N more`.
- Unknown reset dates are not fabricated or displayed.

### Account summary

- At the right of the track show `7 / ≈9` with the caption `аккаунтов / нужно`.
- The first number is the active account count. The second is the approximate count required for the observed seven-day demand.
- In the collecting state, keep the current collecting title/detail and do not show the capacity track, reset indicators, or account requirement.

### Accessibility

- Expose the title, preliminary/established status, rounded reserve or deficit, current versus required account count, and the number of known reset events in one readable accessibility label.
- Do not rely on color alone: signed percentage, title, and account summary carry the same meaning in text.

## Data and compatibility

- Add `resetsAt: Date?` to `PoolAccountSample` with backward-compatible decoding.
- `PoolHistorySample.resetsAt` may remain during migration for old records and existing callers, but the new forecast reads per-account dates from the newest usable sample.
- `makeLive` and `makeCurrent` populate each account's reset date from `weekly.resetAt` or the existing reset-date formatter fallback.
- No history migration or destructive rewrite is required. Legacy samples remain useful for pace calculation; only the live/current sample must contain individual reset dates for the event simulation.

## Verification

Add focused tests for:

- preliminary state with two samples spanning less than seven days;
- established state with at least seven days of usable history;
- collecting state with insufficient or zero-consumption history;
- resets for one, two, and multiple accounts at distinct and identical times;
- depletion before the first reset despite sufficient total weekly capacity;
- enough capacity across every reset gap and the full seven-day horizon;
- unknown reset date contributing current balance without replenishment;
- backward decoding of history without per-account reset dates;
- whole-number reserve/deficit formatting, reset grouping, overflow summary, and Russian/English localization;
- AppKit card structure and accessibility content.

Run the repository's targeted tests, full test suite, and build. Per the user's instruction, do not perform visual verification; the user will inspect the installed application.

## Out of scope

- Changes to the daily spending chart.
- Changes to the separate reset countdown.
- A probabilistic confidence band or best/worst-case range.
- Exact token-cost display in the verdict card.
- Automatic account purchasing or removal recommendations.
