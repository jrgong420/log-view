# Discourse SPA Event Binding Rules

Purpose: Prevent stale listeners and missed events in Discourse single‑page app (SPA) themes/components.

## Core rules

- Use `api.onPageChange` and schedule work with `schedule("afterRender")` when targeting DOM that changes across routes.
- Prefer event delegation over direct element binding for UI that re-renders (e.g., legacy widgets like `posts-filtered-notice`).
  - Bind once at a stable ancestor (e.g., `document` or a container) and detect clicks via `event.target.closest()`.
  - Do not rely on querying and binding to ephemeral children on every render.
- Avoid one-time "bind guards" on containers (`dataset.bound = "1"`) when children are replaced by Ember; use delegation instead.
- Keep listener registration idempotent. If you must bind repeatedly, remove previous handlers or use a single global flag to bind only once.

## Patterns

- Good (delegation):

```js
let bound = false;
if (!bound) {
  document.addEventListener(
    "click",
    (e) => {
      const target = e.target?.closest?.(".my-widget button, .my-widget a");
      if (!target) return;
      // handle
    },
    true
  );
  bound = true;
}
```

- Risky (direct binding to transient child):

```js
const container = document.querySelector(".my-widget");
const btn = container?.querySelector("button");
btn?.addEventListener("click", handler, { once: true }); // may break after re-render
```

## Hooks and rendering

- Use `api.onAppEvent` when customizing content injected by Discourse components that fire app events (see Meta guidelines).
- For post stream customizations, prefer new Glimmer plugin outlets/transforms; if targeting legacy widgets, avoid `decorateWidget` when possible and keep to DOM-safe techniques.

## Logging & diagnostics

- Log on bind and on first event to confirm delegation is active.
- Include route/topic id in logs to aid debugging across page changes.

