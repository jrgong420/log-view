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
## 2025 Platform Updates (dev-news)

- Inline script tags in themes are deprecated and scheduled for removal. Do not use `<script type="text/discourse-plugin">` or `<script type="text/x-handlebars">`. Move code into file-based JS under `javascripts/discourse/api-initializers/*.gjs` and use `.gjs`/`.hbs` components/connectors.
- Widget rendering system is reaching end-of-life (Q4 2025 default disable). Do not use `createWidget`, `decorateWidget`, `changeWidgetSetting`, `reopenWidget`, `attachWidgetAction`, or `MountWidget`. Migrate to Glimmer components and plugin outlets.
- Post stream modernization: Prefer plugin outlets (`api.renderBeforeWrapperOutlet` / `api.renderAfterWrapperOutlet`) and value transformers. Avoid modifying `.gjs` components with `api.modifyClass` unless explicitly supported by Core.
- Template overrides removal: Do not override core templates. Use wrapper plugin outlets instead of template overrides.
- Post attributes: Use `api.addTrackedPostProperties(...)` instead of `api.includePostAttributes(...)`.
- Verification: Test with `glimmer_post_stream_mode=auto`; resolve any console deprecations/warnings before release.
- Themeable site settings: If you need to flip Core UI settings per-theme, use `about.json` → `"theme_site_settings"`. Intended for UI-only toggles.

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

### Using Plugin Outlets

Plugin outlets are extension points in Discourse templates where you can inject custom content. They are the preferred way to add UI elements to Discourse.

**Finding Outlets**:
- Search Discourse core for `<PluginOutlet @name="outlet-name"`
- Use the [Plugin Outlet Locations](https://meta.discourse.org/t/plugin-outlet-locations-theme-component/100673) theme component
- Check GitHub: https://github.com/discourse/discourse

**Creating Connectors**:

1. **Directory structure**:
   ```
   javascripts/discourse/connectors/
   └── {outlet-name}/
       ├── {connector-name}.gjs  (component file)
       └── {connector-name}.hbs  (template-only, optional)
   ```

2. **Basic connector component** (`.gjs`):
   ```javascript
   import Component from "@glimmer/component";

   export default class MyConnector extends Component {
     <template>
       <div class="my-custom-content">
         {{@outletArgs.model.title}}
       </div>
     </template>
   }
   ```

3. **Conditional rendering with `shouldRender`**:
   ```javascript
   import Component from "@glimmer/component";
   import { getOwner } from "@ember/owner";

   export default class MyConnector extends Component {
     static shouldRender(outletArgs, helper) {
       const owner = getOwner(helper);
       const site = owner.lookup("service:site");

       // Only render on desktop
       return !site?.mobileView;
     }

     <template>
       <div>Desktop only content</div>
     </template>
   }
   ```

4. **Accessing outlet arguments**:
   - Outlets provide context via `@outletArgs`
   - Example: `@outletArgs.model`, `@outletArgs.topic`, etc.
   - Use `{{log @outletArgs}}` in template to inspect available args

**Best Practices**:
- Use unique connector names to avoid conflicts with other themes/plugins
- Prefer connectors over template overrides (which are deprecated)
- Use `shouldRender` for conditional logic instead of wrapping entire template in `{{#if}}`
- Test on both desktop and mobile if your connector should be device-specific

**Common Outlets**:
- `topic-above-post-stream` - Above the post stream in topics
- `topic-above-posts` - Above posts in a topic
- `before-topic-progress` - Before the topic progress indicator (mobile)
- `timeline-footer-controls-after` - After timeline footer controls (desktop)
- `topic-footer-buttons` - In the topic footer button area

**Documentation**: https://meta.discourse.org/t/32727

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

### Translation Keys and Labels

**Important**: When using translations with Discourse components, use the correct pattern:

1. **Define translations in `locales/en.yml`**:
   ```yaml
   en:
     js:
       my_component:
         button_label: "Click Me"
   ```

2. **In JavaScript/GJS components**, use `themePrefix()` helper:
   ```javascript
   import { i18n } from "discourse-i18n";

   // themePrefix is a global helper automatically injected by Discourse
   get translatedLabel() {
     return i18n(themePrefix("js.my_component.button_label"));
   }
   ```

3. **With DButton component**, use `@translatedLabel` for already-translated strings:
   ```gjs
   <DButton
     @translatedLabel={{this.translatedLabel}}
     @action={{this.myAction}}
   />
   ```

   Or use `@label` for untranslated keys (DButton will call i18n internally):
   ```gjs
   <DButton
     @label={{themePrefix "js.my_component.button_label"}}
     @action={{this.myAction}}
   />
   ```

**Note**: `themePrefix()` automatically prepends `theme_translations.{theme_id}.` to your key, so you don't need to include it manually.

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

