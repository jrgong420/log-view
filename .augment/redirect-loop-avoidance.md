# Redirect Loop Avoidance in Discourse Themes

Purpose: Prevent re-navigation loops when changing URL parameters (e.g., `username_filters`).

## Core rules

- Idempotency: Ensure navigation code is a no-op when the target state is already applied.
  - Check URL parameters AND UI indicators (e.g., presence of `.posts-filtered-notice`).
- Early return before navigate:
  - If `username_filters` already present, do not call `window.location.replace`.
  - If UI already indicates filtered state, also bail out.
- Use real values only:
  - Avoid special tokens (like `owner`); set the actual username to keep server output stable.
- Defer until ready:
  - If required data (e.g., owner username) isn’t available yet, skip this cycle and try again on the next `onPageChange`.

## Sample guard pattern

```js
const url = new URL(window.location.href);
const currentFilter = url.searchParams.get("username_filters");
const hasFilteredNotice = !!document.querySelector(".posts-filtered-notice");

if (currentFilter || hasFilteredNotice) {
  // mark state, attach UI hooks if needed
  return;
}

// now safe to set and navigate
url.searchParams.set("username_filters", ownerUsername);
window.location.replace(url.toString());
```

## Logging & troubleshooting

- Log before attempting navigation (URL + reason) and on each guard path.
- Include topic id and category id in logs to correlate with settings.
- Add temporary diagnostics when debugging order-of-operations issues.

## When to avoid navigation

- During click handlers that immediately trigger a Discourse-provided navigation (e.g., notice buttons): prefer one-shot suppression flags instead of forcing a second navigation.

