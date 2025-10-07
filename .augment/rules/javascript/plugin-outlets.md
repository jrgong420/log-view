---
id: discourse-plugin-outlets
title: Using Plugin Outlets in Discourse Themes
type: rule
severity: required
category: javascript
applies_to: [discourse-theme, gjs, plugin-outlets]
tags: [plugin-outlets, connectors, wrapper-outlets, glimmer]
last_updated: 2025-10-07
sources:
  - https://meta.discourse.org/t/using-plugin-outlet-connectors-from-a-theme-or-plugin/32727
  - https://meta.discourse.org/t/theme-developer-tutorial-4-using-outlets-to-insert-and-replace-content/357799
  - https://meta.discourse.org/t/outletargs-are-now-available-as-top-level-arguments/370678
---

# Using Plugin Outlets in Discourse Themes

## Intent

Plugin outlets are extension points in Discourse templates where you can inject custom content. They are the **primary and recommended way** to add UI elements to Discourse. Outlets provide access to contextual data and integrate seamlessly with Discourse's rendering system.

## When This Applies

- When adding custom UI elements anywhere in Discourse
- When inserting content before/after existing UI elements
- When replacing core UI elements (wrapper outlets)
- When you need access to contextual data (topic, post, user, etc.)

## Types of Plugin Outlets

### 1. Simple Outlets
Insert content at a specific point without replacing anything.

### 2. Wrapper Outlets
Wrap or replace existing core content.

### 3. Programmatic Outlets
Render components into outlets via `api.renderInOutlet()`.

## Do

### ✅ Find Available Outlets Using Developer Tools

Enable the developer toolbar:

```javascript
// In browser console
enableDevTools()
```

Click the 🔌 icon to see all outlets on the current page:
- **Green placeholders** = simple outlets
- **Blue placeholders** = wrapper outlet boundaries

Hover over outlets to see available `outletArgs`.

### ✅ Use File-Based Connectors (Recommended)

**Directory structure**:
```
javascripts/discourse/connectors/
└── {outlet-name}/
    └── {connector-name}.gjs
```

**Example**: `javascripts/discourse/connectors/topic-above-post-stream/custom-banner.gjs`

```javascript
import Component from "@glimmer/component";

export default class CustomBanner extends Component {
  <template>
    <div class="custom-banner">
      <h3>Welcome to {{@topic.title}}</h3>
      <p>Posted by @{{@topic.user.username}}</p>
    </div>
  </template>
}
```

### ✅ Access Outlet Args as Top-Level Arguments (Modern - 2025)

**New way** (recommended):
```javascript
<template>
  <div>Topic: {{@topic.title}}</div>
  <div>Category: {{@category.name}}</div>
</template>
```

**Old way** (still works):
```javascript
<template>
  <div>Topic: {{@outletArgs.topic.title}}</div>
  <div>Category: {{@outletArgs.category.name}}</div>
</template>
```

### ✅ Use shouldRender for Conditional Rendering

```javascript
import Component from "@glimmer/component";
import { service } from "@ember/service";

export default class DesktopOnlyBanner extends Component {
  static shouldRender(args, context) {
    // Access services via context (helper)
    const site = context.lookup("service:site");
    
    // Only render on desktop
    return !site?.mobileView;
  }
  
  <template>
    <div class="desktop-banner">
      Desktop only content
    </div>
  </template>
}
```

**Advanced shouldRender**:
```javascript
export default class ConditionalConnector extends Component {
  static shouldRender(args, context) {
    const currentUser = context.lookup("service:current-user");
    const siteSettings = context.lookup("service:site-settings");
    
    // Only render for logged-in users when feature is enabled
    return currentUser && siteSettings.my_feature_enabled;
  }
  
  <template>
    <div>Conditional content</div>
  </template>
}
```

### ✅ Use api.renderInOutlet for Programmatic Rendering

```javascript
import { apiInitializer } from "discourse/lib/api";
import CustomComponent from "../components/custom-component";

export default apiInitializer((api) => {
  api.renderInOutlet("discovery-list-container-top", CustomComponent);
});
```

**Inline template**:
```javascript
import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  const currentUser = api.getCurrentUser();
  
  api.renderInOutlet(
    "discovery-list-container-top",
    <template>
      <div class="welcome-banner">
        {{#if currentUser}}
          Welcome back, @{{currentUser.username}}!
        {{else}}
          Welcome to our community!
        {{/if}}
      </div>
    </template>
  );
});
```

### ✅ Use Wrapper Outlets to Replace Content

Wrapper outlets let you replace core content or wrap it with your own HTML.

**Replace entirely**:
```javascript
// Connector in: javascripts/discourse/connectors/home-logo-contents/custom-logo.gjs
import Component from "@glimmer/component";

export default class CustomLogo extends Component {
  <template>
    <img src="/assets/my-custom-logo.png" alt="Custom Logo" />
  </template>
}
```

**Wrap with additional content**:
```javascript
import Component from "@glimmer/component";

export default class LogoWrapper extends Component {
  <template>
    <div class="logo-wrapper">
      <span class="logo-prefix">🎉</span>
      {{yield}}  {{! Re-render the original content }}
      <span class="logo-suffix">✨</span>
    </div>
  </template>
}
```

### ✅ Use renderBeforeWrapperOutlet and renderAfterWrapperOutlet

For post-stream and other wrapper outlets:

```javascript
import { apiInitializer } from "discourse/lib/api";
import Component from "@glimmer/component";

export default apiInitializer((api) => {
  // Render before the wrapped content
  api.renderBeforeWrapperOutlet(
    "post-article",
    class extends Component {
      static shouldRender(args) {
        return args.post?.topic?.pinned;
      }
      
      <template>
        <div class="pinned-notice">📌 This topic is pinned</div>
      </template>
    }
  );
  
  // Render after the wrapped content
  api.renderAfterWrapperOutlet(
    "post-content-cooked-html",
    class extends Component {
      static shouldRender(args) {
        return args.post?.wiki;
      }
      
      <template>
        <div class="wiki-footer">📝 This post is a wiki</div>
      </template>
    }
  );
});
```

## Don't

### ❌ Don't Use Template Overrides (Removed June 2025)

```javascript
// REMOVED - template overrides no longer work
// templates/components/topic-list.hbs
```

Use wrapper outlets instead.

### ❌ Don't Use Inline Script Tags (Removed Sept 2025)

```html
<!-- REMOVED - inline scripts deprecated -->
<script type="text/x-handlebars" data-template-name="/connectors/outlet-name/connector">
  {{my-component}}
</script>
```

Use file-based `.gjs` connectors instead.

### ❌ Don't Wrap Entire Template in {{#if}}

```javascript
// BAD - use shouldRender instead
export default class MyConnector extends Component {
  <template>
    {{#if this.shouldShow}}
      <div>Content</div>
    {{/if}}
  </template>
}
```

```javascript
// GOOD - use static shouldRender
export default class MyConnector extends Component {
  static shouldRender(args, context) {
    return someCondition;
  }
  
  <template>
    <div>Content</div>
  </template>
}
```

### ❌ Don't Mutate Outlet Args

```javascript
// BAD - args are read-only
export default class MyConnector extends Component {
  constructor() {
    super(...arguments);
    this.args.topic.title = "New Title"; // Error!
  }
}
```

## Patterns

### Good: Accessing Multiple Outlet Args

```javascript
import Component from "@glimmer/component";

export default class TopicInfo extends Component {
  <template>
    <div class="topic-info">
      <h3>{{@topic.title}}</h3>
      <p>Category: {{@category.name}}</p>
      <p>Tags: {{@topic.tags}}</p>
      <p>Posts: {{@topic.posts_count}}</p>
    </div>
  </template>
}
```

### Good: Using Services in Connectors

```javascript
import Component from "@glimmer/component";
import { service } from "@ember/service";

export default class UserSpecificContent extends Component {
  @service currentUser;
  @service siteSettings;
  
  get canSeeContent() {
    return this.currentUser?.admin || this.siteSettings.public_feature;
  }
  
  <template>
    {{#if this.canSeeContent}}
      <div class="admin-notice">
        Admin-only content for {{this.currentUser.username}}
      </div>
    {{/if}}
  </template>
}
```

### Good: Debugging Outlet Args

```javascript
import Component from "@glimmer/component";

export default class DebugConnector extends Component {
  constructor() {
    super(...arguments);
    console.log("Available outlet args:", Object.keys(this.args));
    console.log("Full args:", this.args);
  }
  
  <template>
    {{! Use {{log @outletArgs}} in template to inspect }}
    {{log "Topic:" @topic}}
    {{log "Category:" @category}}
    <div>Check console for outlet args</div>
  </template>
}
```

## Common Outlets Reference

### Topic Page
- `topic-above-post-stream` - Above the post stream
- `topic-above-posts` - Above posts in a topic
- `topic-footer-buttons` - In the topic footer button area
- `before-topic-progress` - Before topic progress (mobile)
- `timeline-footer-controls-after` - After timeline controls (desktop)

### Post Stream
- `post-article` - Wraps entire post article
- `post-content-cooked-html` - Wraps post content HTML
- `post-meta-data-poster-name` - After poster name

### Discovery (Topic Lists)
- `discovery-list-container-top` - Above topic list
- `topic-list-before-columns` - Before topic list columns
- `topic-list-after-title` - After topic title in list

### Header
- `home-logo-contents` - Wraps site logo (wrapper outlet)
- `header-buttons-before` - Before header buttons
- `before-header-panel` - Before header panel

### User
- `user-profile-primary` - In user profile primary section
- `user-card-post-names` - In user card

## Diagnostics/Verification

### Finding Outlet Args

1. Enable developer toolbar: `enableDevTools()`
2. Click 🔌 icon
3. Hover over outlet to see args
4. Click "Log to console" button

Or use in template:
```javascript
<template>
  {{log @outletArgs}}
  {{! Your content }}
</template>
```

### Testing Connectors

1. ✅ Verify connector appears in correct location
2. ✅ Test on desktop and mobile (if device-specific)
3. ✅ Verify `shouldRender` logic works correctly
4. ✅ Check that outlet args are available
5. ✅ Test across different routes/pages

### Common Issues

**Connector not appearing**:
- Check directory structure matches outlet name exactly
- Verify file is `.gjs` extension
- Check `shouldRender` isn't returning false
- Clear browser cache

**Outlet args undefined**:
- Outlet may not provide that arg
- Use developer toolbar to verify available args
- Check timing - some args load asynchronously

## References

- [Using Plugin Outlet Connectors](https://meta.discourse.org/t/32727)
- [Theme Developer Tutorial: Outlets](https://meta.discourse.org/t/357799)
- [Top-Level Outlet Args](https://meta.discourse.org/t/370678)
- [Plugin Outlet Locations Component](https://meta.discourse.org/t/100673)

