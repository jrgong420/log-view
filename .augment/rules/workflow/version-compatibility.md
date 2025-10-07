---
id: discourse-version-compatibility
title: Version Compatibility and Deprecations
type: guide
severity: required
category: workflow
applies_to: [discourse-theme, compatibility, deprecations]
tags: [compatibility, versions, deprecations, migration]
last_updated: 2025-10-07
sources:
  - https://meta.discourse.org/t/upcoming-eol-for-the-widget-rendering-system/375332
  - https://meta.discourse.org/t/modernizing-inline-script-tags-for-templates-js-api/366482
  - https://meta.discourse.org/t/removing-support-for-template-overrides-and-mobile-specific-templates/355668
  - https://meta.discourse.org/t/upcoming-post-stream-changes-how-to-prepare-themes-and-plugins/372063
---

# Version Compatibility and Deprecations

## Intent

Ensure theme compatibility with current and future Discourse versions by following deprecation timelines and migration paths. Stay informed about breaking changes and update themes proactively.

## 2025 Breaking Changes & Deprecations

### ❌ Inline Script Tags (REMOVED - September 2025)

**Deprecated**: `<script type="text/discourse-plugin">` and `<script type="text/x-handlebars">`

**Migration**:
```javascript
// OLD (removed)
<script type="text/discourse-plugin" version="0.8">
  const api = require("discourse/lib/plugin-api").default;
  api.onPageChange(() => { /* ... */ });
</script>

// NEW (required)
// File: javascripts/discourse/api-initializers/init-theme.gjs
import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  api.onPageChange(() => { /* ... */ });
});
```

**Timeline**:
- ✅ May 2025: Console deprecation warnings
- ✅ July 2025: Admin warning banners
- ✅ September 2025: Feature removed

**Deprecation ID**: `discourse.inline-script-tags`

---

### ❌ Template Overrides (REMOVED - June 2025)

**Deprecated**: Overriding core templates in `templates/` directory

**Migration**: Use wrapper plugin outlets instead

```javascript
// OLD (removed)
// templates/components/topic-list.hbs

// NEW (required)
// Use wrapper outlets
api.renderInOutlet("topic-list-wrapper", MyCustomComponent);
```

**Timeline**:
- ✅ November 2024: Deprecation introduced
- ✅ March 2025: Admin warning banner
- ✅ June 2025: Feature removed

**Deprecation ID**: `discourse.template-overrides`

---

### ❌ Widget Rendering System (EOL - Q4 2025)

**Deprecated**: All widget-based APIs

**Affected APIs**:
- `createWidget`
- `decorateWidget`
- `changeWidgetSetting`
- `reopenWidget`
- `attachWidgetAction`
- `MountWidget` component

**Migration**: Use Glimmer components and plugin outlets

```javascript
// OLD (deprecated)
api.decorateWidget("post-contents:after-cooked", (helper) => {
  return helper.attach("my-widget", { data });
});

// NEW (required)
api.renderAfterWrapperOutlet(
  "post-content-cooked-html",
  class extends Component {
    static shouldRender(args) {
      return args.post.someCondition;
    }
    
    <template>
      <div class="my-content">{{@post.data}}</div>
    </template>
  }
);
```

**Timeline**:
- ✅ July 2025: Deprecation warnings + experimental setting
- ✅ August 2025: Official plugins upgraded, Meta runs without widgets
- ✅ Q3 2025: Third-party themes must upgrade
- ⏳ Q4 2025: Widgets disabled by default, then removed

**Deprecation ID**: `discourse.widgets-end-of-life`

**Testing**: Set `deactivate_widgets_rendering: true` in site settings

---

### ⚠️ Post Stream Modernization (Active - 2025)

**Changed**: Post stream now uses Glimmer components

**Affected APIs**:
- `api.includePostAttributes()` → Use `api.addTrackedPostProperties()`
- Widget decorations on post-related widgets → Use plugin outlets and transformers

**Migration**:

```javascript
// OLD
api.includePostAttributes("custom_field", "custom_status");

// NEW
api.addTrackedPostProperties("custom_field", "custom_status");
```

**Timeline**:
- ✅ Q2 2025: Core implementation, enabled on Meta
- ✅ Q3 2025: Default mode set to `auto`, deprecation warnings
- ✅ Q4 2025: Enabled by default, legacy code removed

**Testing**: Set `glimmer_post_stream_mode: auto` in site settings

**Deprecation ID**: `discourse.post-stream-widget-overrides`

---

## Do

### ✅ Set minimum_discourse_version

```json
// about.json
{
  "name": "My Theme",
  "component": true,
  "minimum_discourse_version": "3.2.0",
  "theme_version": "2.1.0"
}
```

### ✅ Monitor Deprecation Warnings

Check browser console for deprecation messages:
```
DEPRECATION: discourse.widgets-end-of-life
  Widget rendering system will be removed in Q4 2025
  See: https://meta.discourse.org/t/375332
```

### ✅ Test with Feature Flags

```
# Admin → Settings → Search for:
glimmer_post_stream_mode: auto
deactivate_widgets_rendering: true
```

### ✅ Follow Dev News

Subscribe to the `dev-news` tag on Meta Discourse:
https://meta.discourse.org/tag/dev-news

### ✅ Update Regularly

```bash
# Check for theme updates
git pull origin main

# Update dependencies
pnpm update

# Test on development instance
discourse_theme watch .
```

## Don't

### ❌ Don't Ignore Deprecation Warnings

Deprecations will become breaking changes. Update proactively.

### ❌ Don't Use Deprecated APIs in New Code

Even if they still work, avoid deprecated APIs in new development.

### ❌ Don't Skip Testing

Always test themes with:
- Latest Discourse version
- Deprecation feature flags enabled
- Different user roles and permissions

## Migration Checklist

### Inline Scripts → File-Based Initializers
- [ ] Move `<script type="text/discourse-plugin">` to `.gjs` files
- [ ] Move `<script type="text/x-handlebars">` to `.gjs` or `.hbs` files
- [ ] Update `require()` to ES6 `import`
- [ ] Test all functionality

### Template Overrides → Wrapper Outlets
- [ ] Identify template overrides in `templates/` directory
- [ ] Find corresponding wrapper outlets
- [ ] Create connector components
- [ ] Test rendering

### Widgets → Glimmer Components
- [ ] List all widget decorations
- [ ] Map to plugin outlets or transformers
- [ ] Create Glimmer components
- [ ] Update `includePostAttributes` to `addTrackedPostProperties`
- [ ] Test with `deactivate_widgets_rendering: true`

### Post Stream Updates
- [ ] Replace widget decorations with outlets/transformers
- [ ] Update post attribute tracking
- [ ] Test with `glimmer_post_stream_mode: auto`
- [ ] Verify no console warnings

## Compatibility Matrix

| Feature | Deprecated | Removed | Replacement |
|---------|-----------|---------|-------------|
| Inline `<script>` tags | May 2025 | Sept 2025 | `.gjs` files |
| Template overrides | Nov 2024 | June 2025 | Wrapper outlets |
| Widget system | July 2025 | Q4 2025 | Glimmer components |
| `includePostAttributes` | Q3 2025 | Q4 2025 | `addTrackedPostProperties` |

## Testing for Compatibility

### 1. Enable All Deprecation Flags

```
glimmer_post_stream_mode: auto
deactivate_widgets_rendering: true
```

### 2. Check Console

Look for deprecation warnings with IDs:
- `discourse.inline-script-tags`
- `discourse.template-overrides`
- `discourse.widgets-end-of-life`
- `discourse.post-stream-widget-overrides`

### 3. Test Core Functionality

- [ ] Theme loads without errors
- [ ] All components render correctly
- [ ] Interactive features work
- [ ] No console errors or warnings
- [ ] Mobile and desktop views work

### 4. Verify Admin Panel

Check Admin → Customize → Themes for warning banners.

## Resources

### Official Migration Guides
- [Inline Scripts Migration](https://meta.discourse.org/t/366482)
- [Template Overrides Removal](https://meta.discourse.org/t/355668)
- [Widget System EOL](https://meta.discourse.org/t/375332)
- [Post Stream Changes](https://meta.discourse.org/t/372063)

### Example Migrations
- [discourse-solved](https://github.com/discourse/discourse-solved/pull/363)
- [discourse-reactions](https://github.com/discourse/discourse-reactions/pull/362)
- [discourse-ai](https://github.com/discourse/discourse-ai/pull/1230)

## References

- [Widget System EOL](https://meta.discourse.org/t/375332)
- [Inline Scripts Deprecation](https://meta.discourse.org/t/366482)
- [Template Overrides Removal](https://meta.discourse.org/t/355668)
- [Post Stream Modernization](https://meta.discourse.org/t/372063)
- [Dev News Tag](https://meta.discourse.org/tag/dev-news)

