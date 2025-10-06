# Discourse Theme Component Code Rules

This document summarizes best practices for Discourse theme component development based on official Meta Discourse documentation and guides.

Sources (highly recommended):
- Theme Developer Quick Reference Guide
- Structure of themes and theme components
- Install the Discourse Theme CLI
- Add settings to your Discourse theme
- Adding metadata and screenshots to a Theme
- JS Plugin API (plugin-api.gjs)

---

## 1) Theme Component Structure Requirements

- `about.json` must include: `"component": true`
- Required fields: `name`, `component`, `authors`
- Optional (recommended): `about_url`, `license_url`, `theme_version`, `minimum_discourse_version`
- Typical file/folder structure (only create what you need):
  - `common/`, `desktop/`, `mobile/`
    - `common/common.scss`, `desktop/desktop.scss`, `mobile/mobile.scss`
    - `head_tag.html`, `header.html`, `after_header.html`, `body_tag.html`, `footer.html`
  - `javascripts/` (supports `.js`, `.gjs`, `.hbs`, `.raw.hbs`)
  - `locales/` (e.g., `en.yml`)
  - `assets/` (images, fonts, etc.)
  - `stylesheets/` (additional SCSS partials)
  - `settings.yml` (theme settings)

Notes:
- Use `screenshots/` (optional) for up to 2 screenshots; reference them in `about.json`.

---

## 2) JavaScript Best Practices

- Use the modern initializer pattern:
  - `import { apiInitializer } from "discourse/lib/api"`
  - Place initializers under: `javascripts/discourse/api-initializers/`
  - Use `.gjs` extension for modern Ember files
- Leverage the official Plugin API (`plugin-api.gjs`) and plugin outlets
- Avoid:
  - jQuery and `$(document).ready`
  - Direct DOM manipulation where an outlet/component/initializer exists
- Prefer Ember/discourse patterns (components, services, plugin API hooks) over ad‑hoc scripts

---

## 3) Settings Configuration

- Define settings in `settings.yml` at the repo root
- Supported types: `bool`, `integer`, `float`, `string`, `list`, `enum`, `upload`, `objects`
- Access:
  - In JS: `settings.settingName`
  - In SCSS: `$setting-name` (kebab-case)
- Localize setting descriptions in `locales/en.yml` under:
  - `theme_metadata.settings.<setting_key>`

Example `settings.yml` snippet:
```yaml
feature_enabled:
  type: bool
  default: false
choices:
  type: enum
  default: option_a
  choices:
    - option_a
    - option_b
```

---

## 4) Styling Guidelines

- Use SCSS in `common/common.scss`, `desktop/`, and/or `mobile/` as needed
- Prefer Discourse core variables (see `color_definitions.scss` in core) for consistent theming
- Access theme settings as SCSS variables using kebab-case, e.g. `$global-font-size`
- Keep CSS selectors scoped and avoid over‑specificity; prefer structure consistent with Discourse HTML

---

## 5) Assets and Localization

- Declare assets in `about.json` under the `assets` key:
  ```json
  {
    "assets": {
      "hero": "assets/hero.png"
    }
  }
  ```
- Reference assets in SCSS: `background-image: url($hero);`
- Localize strings in `locales/en.yml`; in JS/templates use `i18n(themePrefix("key"))`
- Provide `theme_metadata.description` and `theme_metadata.settings.*` descriptions in locales

---

## 6) Development Workflow

- Use Discourse Theme CLI for scaffolding and live sync:
  - `discourse_theme new <dir>`
  - `discourse_theme watch <dir>` (or `discourse_theme watch .` from within the repo)
- Prerequisites (recommended versions):
  - Ruby ≥ 2.7 (we use 3.3.9 via rbenv)
  - Node ≥ 22 (we use 22.x via fnm) and pnpm (via Corepack)
- Package manager: `pnpm` (respect `engines` in `package.json`)
- Note: Live stylesheet reloads are disabled on production Discourse instances; prefer a development instance for live reload and better errors

---

## 7) Version Compatibility

- Set `minimum_discourse_version` in `about.json` when relying on newer APIs
- Maintain `theme_version` for releases
- Test changes against a development Discourse instance whenever possible

---

## 8) Repository Best Practices

- Include a `LICENSE` file (MIT is common)
- Add a `screenshots/` folder with up to 2 images (≤ 1MB, ≤ 3840×2160, jpeg/gif/png)
  - Reference them in `about.json` via `"screenshots": ["screenshots/light.png", "screenshots/dark.png"]`
- Keep `README.md` updated with:
  - Description, installation (Git import URL), configuration (settings), compatibility notes
- Keep `about.json` metadata (`about_url`, `license_url`, authors) accurate

---

## Quick References

- Initializer skeleton (`.gjs`):
  ```js
  import { apiInitializer } from "discourse/lib/api";
  export default apiInitializer((api) => {
    // your code here
  });
  ```
- Access a setting in JS: `if (settings.feature_enabled) { /* ... */ }`
- Access a setting in SCSS: `font-size: #{$global-font-size}px;`
- Asset in SCSS: `background-image: url($hero);`

---

By adhering to these rules, we ensure maintainable, compatible, and idiomatic Discourse theme components aligned with core conventions.

