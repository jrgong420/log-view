---
id: discourse-api-initializers
title: API Initializers and Plugin API
type: rule
severity: required
category: javascript
applies_to: [discourse-theme, js, gjs, initializers]
tags: [initializers, plugin-api, apiInitializer]
last_updated: 2025-10-07
sources:
  - https://meta.discourse.org/t/theme-developer-tutorial-6-using-the-js-api/357801
  - https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/plugin-api.gjs
  - https://meta.discourse.org/t/modernizing-inline-script-tags-for-templates-js-api/366482
---

# API Initializers and Plugin API

## Intent

API initializers are the entry point for theme JavaScript code. They provide access to Discourse's Plugin API, which offers methods for customizing and extending Discourse functionality. This is the **required pattern** for all theme JavaScript as of 2025.

## When This Applies

- When adding any JavaScript functionality to a theme
- When accessing Discourse's Plugin API
- When registering plugin outlets, transformers, or other customizations
- When responding to page changes or app events

## Do

### ✅ Use apiInitializer Pattern (Modern - Required)

**File location**: `javascripts/discourse/api-initializers/init-{theme-name}.gjs`

```javascript
import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  // Your code here
  console.log("Theme initialized");
});
```

### ✅ Access Plugin API Methods

```javascript
import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  // Get current user
  const currentUser = api.getCurrentUser();
  
  // Get site settings
  const siteSettings = api.container.lookup("service:site-settings");
  
  // Get site info
  const site = api.container.lookup("service:site");
  
  console.log("User:", currentUser?.username);
  console.log("Mobile view:", site.mobileView);
});
```

### ✅ Register Multiple Customizations

```javascript
import { apiInitializer } from "discourse/lib/api";
import CustomBanner from "../components/custom-banner";

export default apiInitializer((api) => {
  // Render component in outlet
  api.renderInOutlet("discovery-list-container-top", CustomBanner);
  
  // Register value transformer
  api.registerValueTransformer("post-class", ({ value, context }) => {
    return [...value, "custom-class"];
  });
  
  // Listen to page changes
  api.onPageChange((url, title) => {
    console.log("Page changed to:", url);
  });
  
  // Add custom post menu button
  api.addPostMenuButton("custom-action", (post) => {
    return {
      action: "customAction",
      icon: "star",
      title: "Custom Action",
      position: "first"
    };
  });
});
```

### ✅ Use Conditional Initialization

```javascript
import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  const currentUser = api.getCurrentUser();
  const siteSettings = api.container.lookup("service:site-settings");
  
  // Only initialize for logged-in users
  if (!currentUser) {
    console.log("User not logged in, skipping initialization");
    return;
  }
  
  // Only initialize if setting is enabled
  if (!siteSettings.my_feature_enabled) {
    console.log("Feature disabled, skipping initialization");
    return;
  }
  
  // Initialize feature
  console.log("Initializing feature for:", currentUser.username);
});
```

### ✅ Import and Use Components

```javascript
import { apiInitializer } from "discourse/lib/api";
import WelcomeBanner from "../components/welcome-banner";
import CustomButton from "../components/custom-button";

export default apiInitializer((api) => {
  api.renderInOutlet("discovery-list-container-top", WelcomeBanner);
  api.renderInOutlet("topic-above-post-stream", CustomButton);
});
```

### ✅ Access Services via Container

```javascript
import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  const router = api.container.lookup("service:router");
  const currentUser = api.container.lookup("service:current-user");
  const siteSettings = api.container.lookup("service:site-settings");
  const site = api.container.lookup("service:site");
  
  console.log("Current route:", router.currentRouteName);
  console.log("User:", currentUser?.username);
  console.log("Mobile:", site.mobileView);
});
```

### ✅ Use Modern ES6 Imports

```javascript
import { apiInitializer } from "discourse/lib/api";
import { i18n } from "discourse-i18n";
import { schedule } from "@ember/runloop";
import Component from "@glimmer/component";

export default apiInitializer((api) => {
  const greeting = i18n(themePrefix("greeting"));
  console.log(greeting);
  
  api.onPageChange(() => {
    schedule("afterRender", () => {
      console.log("DOM ready");
    });
  });
});
```

## Don't

### ❌ Don't Use Inline Script Tags (Removed Sept 2025)

```html
<!-- REMOVED - no longer works -->
<script type="text/discourse-plugin" version="0.8">
  const api = require("discourse/lib/plugin-api").default;
  api.onPageChange(() => {
    console.log("Page changed");
  });
</script>
```

Use file-based `.gjs` initializers instead.

### ❌ Don't Use require() Syntax

```javascript
// DEPRECATED - old syntax
const api = require("discourse/lib/plugin-api").default;
const I18n = require("discourse-i18n").default;
```

```javascript
// GOOD - modern ES6 imports
import { apiInitializer } from "discourse/lib/api";
import { i18n } from "discourse-i18n";
```

### ❌ Don't Use withPluginApi Directly in Themes

```javascript
// OLD - plugin pattern, not needed for themes
import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "my-theme",
  initialize() {
    withPluginApi("0.8", (api) => {
      // ...
    });
  }
};
```

```javascript
// GOOD - use apiInitializer for themes
import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  // ...
});
```

### ❌ Don't Access DOM Before It's Ready

```javascript
// BAD - DOM might not be ready
export default apiInitializer((api) => {
  const element = document.querySelector(".my-element");
  element.textContent = "Hello"; // Might be null!
});
```

```javascript
// GOOD - use onPageChange with schedule
import { apiInitializer } from "discourse/lib/api";
import { schedule } from "@ember/runloop";

export default apiInitializer((api) => {
  api.onPageChange(() => {
    schedule("afterRender", () => {
      const element = document.querySelector(".my-element");
      if (element) {
        element.textContent = "Hello";
      }
    });
  });
});
```

## Common Plugin API Methods

### Page Lifecycle
- `api.onPageChange(callback)` - Called when page content changes
- `api.onAppEvent(eventName, callback)` - Listen to app events

### Rendering
- `api.renderInOutlet(outletName, component)` - Render component in outlet
- `api.renderBeforeWrapperOutlet(outletName, component)` - Render before wrapper
- `api.renderAfterWrapperOutlet(outletName, component)` - Render after wrapper

### Transformers
- `api.registerValueTransformer(name, callback)` - Register value transformer
- `api.registerBehaviorTransformer(name, callback)` - Register behavior transformer

### Post Customization
- `api.addTrackedPostProperties(...properties)` - Track post properties
- `api.addPostMenuButton(name, callback)` - Add post menu button
- `api.addPostClassesCallback(callback)` - Add CSS classes to posts

### User & Site
- `api.getCurrentUser()` - Get current user object
- `api.container.lookup(serviceName)` - Access Ember services

### Decorators (Use Sparingly)
- `api.decorateCooked(callback)` - Modify cooked post content
- `api.modifyClass(className, modifications)` - Modify Ember classes (risky)

## Patterns

### Good: Feature with Multiple Customizations

```javascript
import { apiInitializer } from "discourse/lib/api";
import { schedule } from "@ember/runloop";
import CustomBanner from "../components/custom-banner";

export default apiInitializer((api) => {
  const siteSettings = api.container.lookup("service:site-settings");
  
  // Guard: only initialize if enabled
  if (!siteSettings.custom_feature_enabled) {
    return;
  }
  
  // Render component
  api.renderInOutlet("discovery-list-container-top", CustomBanner);
  
  // Add post classes
  api.registerValueTransformer("post-class", ({ value, context }) => {
    if (context.post.custom_field) {
      return [...value, "custom-post"];
    }
    return value;
  });
  
  // Listen to page changes
  api.onPageChange((url, title) => {
    schedule("afterRender", () => {
      console.log("Page loaded:", title);
    });
  });
  
  // Add tracked properties
  api.addTrackedPostProperties("custom_field", "custom_status");
});
```

### Good: Conditional Feature Initialization

```javascript
import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  const currentUser = api.getCurrentUser();
  const site = api.container.lookup("service:site");
  const siteSettings = api.container.lookup("service:site-settings");
  
  // Multiple guard conditions
  if (!currentUser) {
    console.log("[Theme] User not logged in");
    return;
  }
  
  if (!currentUser.admin && !currentUser.moderator) {
    console.log("[Theme] User is not staff");
    return;
  }
  
  if (site.mobileView) {
    console.log("[Theme] Mobile view, using different initialization");
    initializeMobileFeature(api);
    return;
  }
  
  // Desktop staff initialization
  initializeDesktopFeature(api);
});

function initializeMobileFeature(api) {
  // Mobile-specific code
}

function initializeDesktopFeature(api) {
  // Desktop-specific code
}
```

### Good: Organized Multi-File Theme

```javascript
// javascripts/discourse/api-initializers/init-my-theme.gjs
import { apiInitializer } from "discourse/lib/api";
import { setupBanners } from "../lib/banners";
import { setupPostCustomizations } from "../lib/post-customizations";
import { setupNavigation } from "../lib/navigation";

export default apiInitializer((api) => {
  const siteSettings = api.container.lookup("service:site-settings");
  
  if (!siteSettings.my_theme_enabled) {
    return;
  }
  
  setupBanners(api);
  setupPostCustomizations(api);
  setupNavigation(api);
});

// javascripts/discourse/lib/banners.js
export function setupBanners(api) {
  // Banner-related code
}

// javascripts/discourse/lib/post-customizations.js
export function setupPostCustomizations(api) {
  // Post customization code
}

// javascripts/discourse/lib/navigation.js
export function setupNavigation(api) {
  // Navigation code
}
```

## Diagnostics/Verification

### Logging Initialization

```javascript
import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  console.log("[Theme] Initializing...");
  console.log("[Theme] Current user:", api.getCurrentUser()?.username);
  console.log("[Theme] Current route:", api.container.lookup("service:router").currentRouteName);
  
  // Your initialization code
  
  console.log("[Theme] Initialization complete");
});
```

### Testing Initialization

1. ✅ Check browser console for initialization logs
2. ✅ Verify initializer runs on page load
3. ✅ Test conditional initialization (logged in/out, different settings)
4. ✅ Verify components render correctly
5. ✅ Check for JavaScript errors in console

### Common Issues

**Initializer not running**:
- Check file is in correct location: `javascripts/discourse/api-initializers/`
- Verify file has `.gjs` or `.js` extension
- Check for syntax errors
- Clear browser cache

**Components not rendering**:
- Verify outlet name is correct
- Check component import path
- Verify component is exported as default

## References

- [Theme Developer Tutorial: JS API](https://meta.discourse.org/t/357801)
- [Plugin API Source](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/plugin-api.gjs)
- [Modernizing Inline Scripts](https://meta.discourse.org/t/366482)
- [Using the Plugin API](https://meta.discourse.org/t/41281)

