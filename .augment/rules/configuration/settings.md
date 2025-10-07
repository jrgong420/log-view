---
id: discourse-theme-settings
title: Theme Settings Configuration
type: rule
severity: recommended
category: configuration
applies_to: [discourse-theme, settings, yaml]
tags: [settings, configuration, yaml, settings.yml]
last_updated: 2025-10-07
sources:
  - https://meta.discourse.org/t/how-to-add-settings-to-your-discourse-theme/82557
  - https://meta.discourse.org/t/theme-developer-quick-reference-guide/110448
---

# Theme Settings Configuration

## Intent

Define configurable settings for themes that site administrators can customize without modifying code. Settings provide a user-friendly way to enable/disable features, customize text, colors, and other theme options.

## When This Applies

- When creating configurable theme features
- When allowing administrators to customize theme behavior
- When providing options for colors, text, or numeric values
- When creating feature toggles

## Supported Setting Types

- `bool` - True/false checkbox
- `integer` - Whole number
- `float` - Decimal number
- `string` - Text input
- `list` - Pipe-separated list of values
- `enum` - Dropdown selection
- `upload` - File upload (images, etc.)
- `objects` - Structured JSON data

## Do

### ✅ Define Settings in settings.yml

```yaml
# settings.yml
feature_enabled:
  type: bool
  default: false
  description: "Enable the custom feature"

banner_text:
  type: string
  default: "Welcome to our community!"
  description: "Text to display in the banner"

max_items:
  type: integer
  default: 10
  min: 1
  max: 100
  description: "Maximum number of items to display"

banner_color:
  type: string
  default: "#3498db"
  description: "Banner background color (hex code)"

display_mode:
  type: enum
  default: "compact"
  choices:
    - compact
    - expanded
    - minimal
  description: "Display mode for the feature"

allowed_categories:
  type: list
  default: "general|support"
  description: "Pipe-separated list of allowed categories"

banner_image:
  type: upload
  default: ""
  description: "Upload a custom banner image"
```

### ✅ Access Settings in JavaScript

```javascript
import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  // Access via settings object
  if (settings.feature_enabled) {
    console.log("Feature is enabled");
    console.log("Banner text:", settings.banner_text);
    console.log("Max items:", settings.max_items);
    console.log("Display mode:", settings.display_mode);
  }
  
  // Parse list settings
  const categories = settings.allowed_categories.split("|");
  console.log("Allowed categories:", categories);
});
```

### ✅ Access Settings in Templates

```javascript
import Component from "@glimmer/component";

export default class CustomBanner extends Component {
  <template>
    {{#if settings.feature_enabled}}
      <div class="custom-banner" style="background-color: {{settings.banner_color}}">
        <h3>{{settings.banner_text}}</h3>
        <p>Showing up to {{settings.max_items}} items</p>
      </div>
    {{/if}}
  </template>
}
```

### ✅ Access Settings in SCSS

Settings are converted to kebab-case in SCSS:

```scss
// settings.yml: banner_padding (integer), enable_shadows (bool)

.custom-banner {
  padding: #{$banner-padding}px;
  
  @if $enable-shadows {
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  }
}
```

### ✅ Localize Setting Descriptions

```yaml
# locales/en.yml
en:
  theme_metadata:
    settings:
      feature_enabled: "Enable the custom feature to show banners"
      banner_text: "Customize the welcome message shown to users"
      max_items: "Control how many items are displayed (1-100)"
```

### ✅ Use Validation Constraints

```yaml
# settings.yml
user_limit:
  type: integer
  default: 50
  min: 1
  max: 1000
  description: "Maximum number of users"

opacity:
  type: float
  default: 0.8
  min: 0.0
  max: 1.0
  description: "Opacity level (0.0 to 1.0)"
```

## Don't

### ❌ Don't Use Settings for Sensitive Data

```yaml
# BAD - settings are visible to all admins
api_secret:
  type: string
  default: ""
  description: "API secret key"
```

Use server-side plugin settings or environment variables instead.

### ❌ Don't Hardcode Values That Should Be Settings

```javascript
// BAD - hardcoded value
const MAX_ITEMS = 10;

// GOOD - use setting
const maxItems = settings.max_items;
```

### ❌ Don't Forget Default Values

```yaml
# BAD - no default
feature_enabled:
  type: bool
  description: "Enable feature"

# GOOD - has default
feature_enabled:
  type: bool
  default: false
  description: "Enable feature"
```

## Patterns

### Good: Feature Toggle with Configuration

```yaml
# settings.yml
show_welcome_banner:
  type: bool
  default: true

welcome_message:
  type: string
  default: "Welcome to our community!"

banner_style:
  type: enum
  default: "info"
  choices:
    - info
    - success
    - warning

show_for_logged_in_only:
  type: bool
  default: false
```

```javascript
// JavaScript
import { apiInitializer } from "discourse/lib/api";
import WelcomeBanner from "../components/welcome-banner";

export default apiInitializer((api) => {
  if (!settings.show_welcome_banner) {
    return;
  }
  
  const currentUser = api.getCurrentUser();
  
  if (settings.show_for_logged_in_only && !currentUser) {
    return;
  }
  
  api.renderInOutlet("discovery-list-container-top", WelcomeBanner);
});
```

### Good: List Setting with Parsing

```yaml
# settings.yml
excluded_categories:
  type: list
  default: "meta|staff"
  description: "Categories to exclude (pipe-separated)"
```

```javascript
import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  const excludedCategories = settings.excluded_categories
    .split("|")
    .map(cat => cat.trim())
    .filter(cat => cat.length > 0);
  
  console.log("Excluded categories:", excludedCategories);
  
  // Use in filtering
  api.registerValueTransformer("topic-list-filter", ({ value, context }) => {
    const categorySlug = context.category?.slug;
    if (excludedCategories.includes(categorySlug)) {
      return false;
    }
    return value;
  });
});
```

### Good: Upload Setting for Images

```yaml
# settings.yml
custom_logo:
  type: upload
  default: ""
  description: "Upload a custom logo image"
```

```javascript
import Component from "@glimmer/component";

export default class CustomHeader extends Component {
  get logoUrl() {
    return settings.custom_logo || "/images/default-logo.png";
  }
  
  <template>
    {{#if settings.custom_logo}}
      <img src={{this.logoUrl}} alt="Custom Logo" class="custom-logo" />
    {{/if}}
  </template>
}
```

### Good: Objects Setting for Complex Data

```yaml
# settings.yml
custom_links:
  type: objects
  default: |
    - title: "Documentation"
      url: "https://example.com/docs"
      icon: "book"
    - title: "Support"
      url: "https://example.com/support"
      icon: "question-circle"
  schema:
    name: custom_link
    properties:
      title:
        type: string
      url:
        type: string
      icon:
        type: string
```

```javascript
import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  const links = settings.custom_links;
  
  links.forEach(link => {
    console.log(`Link: ${link.title} -> ${link.url} (${link.icon})`);
  });
});
```

## Diagnostics/Verification

### Testing Settings

1. ✅ Navigate to Admin → Customize → Themes → Your Theme → Settings
2. ✅ Verify all settings appear with correct types
3. ✅ Test changing each setting
4. ✅ Verify changes take effect immediately (or after refresh)
5. ✅ Test validation (min/max values, enum choices)
6. ✅ Check localized descriptions appear correctly

### Debugging Settings

```javascript
import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  console.log("[Theme Settings]");
  console.log("feature_enabled:", settings.feature_enabled);
  console.log("banner_text:", settings.banner_text);
  console.log("max_items:", settings.max_items);
  console.log("display_mode:", settings.display_mode);
  console.log("All settings:", settings);
});
```

## References

- [Add Settings to Your Theme](https://meta.discourse.org/t/82557)
- [Theme Developer Quick Reference](https://meta.discourse.org/t/110448)
- [Theme Settings Schema](https://meta.discourse.org/t/how-to-add-settings-to-your-discourse-theme/82557)

