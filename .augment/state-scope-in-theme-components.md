# State Scope Guidelines for Discourse Theme Components

Purpose: Choose the correct scope (view-only, session, or persisted) to avoid bugs like unintended persistence or redirect loops.

## Scopes

- View-scoped (recommended for one-shot UX toggles)
  - Lifetime: current route/view only; cleared on next `api.onPageChange`
  - Implementation: module-level flags consumed once and reset; optionally keyed by topic id
  - Use for: suppress-next-action-after-user-click, temporary guards, one-time notices

- Session-scoped (use sparingly)
  - Lifetime: browser tab/window session via `sessionStorage`
  - Use for: per-session preferences that users expect to persist until tab is closed

- Persisted (use rarely in themes)
  - Lifetime: across sessions (e.g., `localStorage` or server settings)
  - Prefer server-side settings or user prefs when feasible

## Patterns

- One-shot suppression (view-only):

```js
let suppressNextAction = false;
let suppressedTopicId = null;

// On user action
suppressNextAction = true;
suppressedTopicId = topic.id;

// In onPageChange afterRender
if (suppressNextAction) {
  if (topic.id === suppressedTopicId) {
    suppressNextAction = false;
    suppressedTopicId = null;
    // skip one-time behavior
    return;
  } else {
    suppressNextAction = false;
    suppressedTopicId = null;
  }
}
```

## Do/Don't

- Do keep state minimal; prefer computed checks from URL or UI if possible.
- Do reset view-only flags deterministically (consume-and-clear) to avoid leakage.
- Don’t store view-only state in `sessionStorage`/`localStorage`.
- Don’t hard-depend on model fields that may not be ready during early render; combine URL + UI guards.

