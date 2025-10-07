---
id: discourse-widget-system-deprecated
title: Widget System (DEPRECATED - EOL Q4 2025)
type: deprecated
severity: critical
category: javascript
applies_to: [discourse-theme, widgets, deprecated]
tags: [widgets, deprecated, eol, migration]
last_updated: 2025-10-07
sources:
  - https://meta.discourse.org/t/upcoming-eol-for-the-widget-rendering-system/375332
  - https://meta.discourse.org/t/upcoming-post-stream-changes-how-to-prepare-themes-and-plugins/372063
---

# Widget System (DEPRECATED - EOL Q4 2025)

## ⚠️ CRITICAL WARNING

**The widget rendering system is deprecated and will be completely removed in Q4 2025.**

**DO NOT use any widget APIs in new code. Migrate existing widget code to Glimmer components immediately.**

## Deprecated APIs

### All Widget-Related APIs Are Deprecated

- ❌ `createWidget`
- ❌ `decorateWidget`
- ❌ `changeWidgetSetting`
- ❌ `reopenWidget`
- ❌ `attachWidgetAction`
- ❌ `MountWidget` component

### Affected Widgets (Post Stream)

- `actions-summary`
- `avatar-flair`
- `embedded-post`
- `expand-hidden`
- `expand-post-button`
- `filter-jump-to-post`
- `filter-show-all`
- `post-article`
- `post-avatar-user-info`
- `post-avatar`
- `post-body`
- `post-contents`
- `post-date`
- `post-edits-indicator`
- `post-email-indicator`
- `post-gap`
- `post-group-request`
- `post-links`
- `post-locked-indicator`
- `post-meta-data`
- `post-notice`
- `post-placeholder`
- `post-stream`
- `post`
- `poster-name`
- `poster-name-title`
- `posts-filtered-notice`
- `reply-to-tab`
- `select-post`
- `topic-post-visited-line`

## Timeline

- ✅ **July 2025**: Deprecation warnings enabled, experimental setting added
- ✅ **August 2025**: Official plugins upgraded, Meta runs without widgets
- ✅ **Q3 2025**: Third-party themes must upgrade
- ⏳ **Q4 2025**: Widgets disabled by default, then completely removed

**After Q4 2025, any theme using widgets will break completely.**

## Migration Paths

### 1. decorateWidget → Plugin Outlets

**OLD (deprecated)**:
```javascript
api.decorateWidget("post-contents:after-cooked", (helper) => {
  const post = helper.getModel();
  if (post.wiki) {
    return helper.attach("wiki-banner", { post });
  }
});
```

**NEW (required)**:
```javascript
import Component from "@glimmer/component";

api.renderAfterWrapperOutlet(
  "post-content-cooked-html",
  class extends Component {
    static shouldRender(args) {
      return args.post.wiki;
    }
    
    <template>
      <div class="wiki-banner">
        This post is a wiki
      </div>
    </template>
  }
);
```

### 2. decorateWidget (poster-name) → Plugin Outlet

**OLD (deprecated)**:
```javascript
api.decorateWidget("poster-name:after", (dec) => {
  if (dec.attrs.user.admin) {
    return dec.widget.attach("admin-badge");
  }
});
```

**NEW (required)**:
```javascript
import Component from "@glimmer/component";

api.renderAfterWrapperOutlet(
  "post-meta-data-poster-name",
  class extends Component {
    static shouldRender(args) {
      return args.post.user.admin;
    }
    
    <template>
      <span class="admin-badge">Admin</span>
    </template>
  }
);
```

### 3. includePostAttributes → addTrackedPostProperties

**OLD (deprecated)**:
```javascript
api.includePostAttributes("custom_field", "custom_status");
```

**NEW (required)**:
```javascript
api.addTrackedPostProperties("custom_field", "custom_status");
```

### 4. Widget Classes → Value Transformers

**OLD (deprecated)**:
```javascript
api.decorateWidget("post:classNames", (attrs) => {
  if (attrs.wiki) {
    return ["wiki-post"];
  }
});
```

**NEW (required)**:
```javascript
api.registerValueTransformer("post-class", ({ value, context }) => {
  if (context.post.wiki) {
    return [...value, "wiki-post"];
  }
  return value;
});
```

## Supporting Both Systems During Transition

Use `withSilencedDeprecations` to support both old and new systems temporarily:

```javascript
import { withSilencedDeprecations } from "discourse/lib/deprecated";

function modernImplementation(api) {
  // Glimmer component implementation
  api.renderAfterWrapperOutlet("post-content-cooked-html", MyComponent);
}

function legacyImplementation(api) {
  // Widget implementation (deprecated)
  api.decorateWidget("post-contents:after-cooked", (helper) => {
    // ...
  });
}

export default apiInitializer((api) => {
  // Modern implementation
  modernImplementation(api);
  
  // Legacy implementation (silenced warnings)
  withSilencedDeprecations("discourse.post-stream-widget-overrides", () => {
    legacyImplementation(api);
  });
});
```

**Note**: This is only for transition. Remove legacy code before Q4 2025.

## Testing Without Widgets

Enable the setting to test your theme without widgets:

```
Admin → Settings → deactivate_widgets_rendering: true
```

Or for post stream specifically:

```
Admin → Settings → glimmer_post_stream_mode: auto
```

If your theme works with these settings enabled, it's ready for Q4 2025.

## Common Migration Patterns

### Pattern 1: Adding Content After Post

**Widget (deprecated)**:
```javascript
api.decorateWidget("post-contents:after-cooked", (helper) => {
  return helper.h("div.custom-footer", "Custom content");
});
```

**Glimmer (required)**:
```javascript
api.renderAfterWrapperOutlet(
  "post-content-cooked-html",
  <template>
    <div class="custom-footer">Custom content</div>
  </template>
);
```

### Pattern 2: Conditional Rendering

**Widget (deprecated)**:
```javascript
api.decorateWidget("post-contents:after-cooked", (helper) => {
  const post = helper.getModel();
  if (post.post_number === 1) {
    return helper.attach("first-post-banner");
  }
});
```

**Glimmer (required)**:
```javascript
api.renderAfterWrapperOutlet(
  "post-content-cooked-html",
  class extends Component {
    static shouldRender(args) {
      return args.post.post_number === 1;
    }
    
    <template>
      <div class="first-post-banner">First post!</div>
    </template>
  }
);
```

### Pattern 3: Using Post Data

**Widget (deprecated)**:
```javascript
api.decorateWidget("post-contents:after-cooked", (helper) => {
  const post = helper.getModel();
  return helper.h("div", `Likes: ${post.like_count}`);
});
```

**Glimmer (required)**:
```javascript
api.renderAfterWrapperOutlet(
  "post-content-cooked-html",
  <template>
    <div>Likes: {{@post.like_count}}</div>
  </template>
);
```

## Detecting Widget Usage

### Check Console Warnings

With widgets enabled, check console for:
```
DEPRECATION: discourse.widgets-end-of-life
  Widget rendering system will be removed in Q4 2025
  Component: my-theme-component
  Widget: post-contents
```

### Check Admin Panel

Admin → Customize → Themes will show warning banners for themes using widgets.

### Search Your Code

Search for these patterns in your theme:
```bash
grep -r "createWidget" .
grep -r "decorateWidget" .
grep -r "changeWidgetSetting" .
grep -r "reopenWidget" .
grep -r "attachWidgetAction" .
grep -r "MountWidget" .
grep -r "includePostAttributes" .
```

## Migration Resources

### Official Migration Examples

Real-world migrations from official Discourse plugins:

- [discourse-solved](https://github.com/discourse/discourse-solved/pull/363)
- [discourse-reactions](https://github.com/discourse/discourse-reactions/pull/362)
- [discourse-ai](https://github.com/discourse/discourse-ai/pull/1230)
- [discourse-assign](https://github.com/discourse/discourse-assign/pull/651)
- [discourse-post-voting](https://github.com/discourse/discourse-post-voting/pull/244)

### Documentation

- [Widget System EOL Announcement](https://meta.discourse.org/t/375332)
- [Post Stream Migration Guide](https://meta.discourse.org/t/372063)
- [Plugin Outlets Guide](https://meta.discourse.org/t/32727)
- [Value Transformers Guide](https://meta.discourse.org/t/349954)

## Immediate Action Required

1. ✅ **Audit your theme** - Search for widget usage
2. ✅ **Plan migration** - Map widgets to outlets/transformers
3. ✅ **Implement Glimmer components** - Replace all widget code
4. ✅ **Test thoroughly** - Enable `deactivate_widgets_rendering: true`
5. ✅ **Deploy before Q4 2025** - Don't wait until the deadline

**Failure to migrate will result in broken themes after Q4 2025.**

## References

- [Widget System EOL](https://meta.discourse.org/t/375332)
- [Post Stream Changes](https://meta.discourse.org/t/372063)
- [Plugin Outlets](https://meta.discourse.org/t/32727)
- [Value Transformers](https://meta.discourse.org/t/349954)
- [Glimmer Components](https://guides.emberjs.com/release/components/)

