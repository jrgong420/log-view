# Hide Reply Buttons for Non-Owners - Implementation Plan

## Overview
Add a new feature to hide reply buttons from non-owner users in categories configured for owner comments. This is a UI-only restriction that complements the existing owner-filtered view functionality.

## Feature Requirements

### Scope
- **Applies when**: Setting is enabled AND topic is in a category defined in `owner_comment_categories`
- **Hides for**: All users except the topic owner (user who created the topic)
- **Shows for**: Topic owner only (`currentUser.id === topic.details.created_by.id`)
- **Independence**: Works independently of "Allowed groups" access control
- **Views**: Works in both regular topic view and owner-filtered view (`username_filters` active)

### Target Elements to Hide
1. **Desktop timeline reply button**: Reply button in `timeline-footer-controls` outlet area
2. **Topic footer reply button**: Primary reply button in topic footer controls (bottom of topic)
3. **Post-level reply buttons**: Individual reply buttons on each post (if applicable)

## Research Findings: Keyboard Shortcuts

### Discourse Keyboard Shortcut System
Based on research and Discourse architecture:

1. **Shift+R Shortcut**: Opens reply composer in Discourse
2. **Theme Component Limitations**: 
   - Theme components **cannot** reliably suppress or override core keyboard shortcuts
   - Discourse's keyboard handling is deeply integrated into the Ember application
   - Attempting to preventDefault on keydown events may conflict with core functionality
   
3. **Recommendation**: 
   - **Do NOT attempt to suppress Shift+R** in this implementation
   - Focus on UI-only hiding of reply buttons
   - Document this limitation clearly
   - Users can still reply via keyboard shortcuts or API manipulation (this is acceptable for UI-only enforcement)

### Why Not Suppress Keyboard Shortcuts?
- Theme components run in a sandboxed environment with limited access to core event handlers
- Discourse's `appEvents` system doesn't expose keyboard event interception for themes
- Attempting to use `document.addEventListener("keydown", ...)` with `preventDefault()` may:
  - Conflict with other keyboard shortcuts
  - Break accessibility features
  - Be unreliable across different Discourse versions
  - Violate Discourse theme component best practices

## Implementation Steps

### Step 1: Add Theme Setting

**File**: `settings.yml`

```yaml
hide_reply_buttons_for_non_owners:
  type: bool
  default: false
  description: "Hide reply buttons from non-owners in configured categories"
```

**Validation against rules**:
- ✅ Uses `bool` type for checkbox (per `.augment/rules/configuration/settings.yml`)
- ✅ Provides default value
- ✅ Clear, descriptive setting name

### Step 2: Add Localization Strings

**File**: `locales/en.yml`

```yaml
en:
  theme_metadata:
    settings:
      hide_reply_buttons_for_non_owners: "Hide reply buttons from all users except the topic owner in categories configured for owner comments. This is a UI-only restriction and does not prevent replies via keyboard shortcuts or API."
```

**Validation against rules**:
- ✅ Follows localization pattern (per `.augment/rules/configuration/localization.md`)
- ✅ Includes clear description with limitations
- ✅ Uses `theme_metadata.settings` namespace

### Step 3: Create Reply Button Hiding Logic

**File**: `javascripts/discourse/api-initializers/hide-reply-buttons.gjs`

**Approach**:
1. Use `api.onPageChange()` to re-evaluate on navigation (SPA-friendly)
2. Check if setting is enabled
3. Check if current topic is in a configured category
4. Compare `currentUser.id` with `topic.details.created_by.id`
5. Add/remove CSS class to body for styling control
6. Use `schedule("afterRender")` to ensure DOM is ready

**Key considerations** (per Augment rules):
- ✅ Use `api.onPageChange()` for SPA navigation (`.augment/rules/core/spa-event-binding.md`)
- ✅ Use `schedule("afterRender")` to ensure DOM stability
- ✅ Avoid redirect loops with proper guards (`.augment/rules/core/redirect-loop-avoidance.md`)
- ✅ Use module-scoped state if needed (`.augment/rules/core/state-scope.md`)
- ✅ Follow modern Glimmer patterns (`.augment/rules/javascript/glimmer-components.md`)

**Pseudocode**:
```javascript
import { apiInitializer } from "discourse/lib/api";
import { schedule } from "@ember/runloop";

export default apiInitializer("1.15.0", (api) => {
  api.onPageChange(() => {
    schedule("afterRender", () => {
      // Guard 1: Setting disabled
      if (!settings.hide_reply_buttons_for_non_owners) {
        document.body.classList.remove("hide-reply-buttons-non-owners");
        return;
      }
      
      // Guard 2: Get topic data
      const topic = api.container.lookup("controller:topic")?.model;
      if (!topic) {
        return;
      }
      
      // Guard 3: Check if category is configured
      const categoryId = topic.category_id;
      const enabledCategories = parseCategories(settings.owner_comment_categories);
      if (!enabledCategories.includes(categoryId)) {
        document.body.classList.remove("hide-reply-buttons-non-owners");
        return;
      }
      
      // Guard 4: Get current user and topic owner
      const currentUser = api.getCurrentUser();
      const topicOwnerId = topic.details?.created_by?.id;
      
      // Guard 5: Anonymous users or no owner data
      if (!currentUser || !topicOwnerId) {
        document.body.classList.add("hide-reply-buttons-non-owners");
        return;
      }
      
      // Decision: Hide if not owner
      if (currentUser.id !== topicOwnerId) {
        document.body.classList.add("hide-reply-buttons-non-owners");
      } else {
        document.body.classList.remove("hide-reply-buttons-non-owners");
      }
    });
  });
});
```

### Step 4: Add CSS Hiding Rules

**File**: `common/common.scss`

**Approach**:
- Use body class `hide-reply-buttons-non-owners` to control visibility
- Target specific reply button selectors
- Use `display: none !important` for reliable hiding

**Target selectors** (based on Discourse core structure):
```scss
/* Hide reply buttons for non-owners when setting is enabled */
body.hide-reply-buttons-non-owners {
  /* Timeline footer reply button (desktop) */
  .timeline-footer-controls .create,
  .timeline-footer-controls .reply-to-post {
    display: none !important;
  }
  
  /* Topic footer reply button */
  .topic-footer-main-buttons .create,
  .topic-footer-main-buttons .reply-to-post {
    display: none !important;
  }
  
  /* Post-level reply buttons */
  .post-controls .reply,
  .post-controls .reply-to-post {
    display: none !important;
  }
}
```

**Validation against rules**:
- ✅ Uses body class for scoping (`.augment/rules/styling/scss-guidelines.md`)
- ✅ Uses `!important` for reliable hiding (acceptable for theme overrides)
- ✅ Targets specific selectors to avoid breaking other functionality

### Step 5: Add Helper Function for Category Parsing

**File**: `javascripts/discourse/lib/group-access-utils.js` (extend existing file)

Add a reusable function to parse category settings:

```javascript
/**
 * Parse category IDs from pipe-separated setting string
 * @param {string} categorySetting - Pipe-separated category IDs
 * @returns {number[]} Array of category IDs
 */
export function parseCategoryIds(categorySetting) {
  if (!categorySetting) {
    return [];
  }
  
  return categorySetting
    .split("|")
    .map((id) => parseInt(id.trim(), 10))
    .filter((id) => !isNaN(id));
}
```

**Validation**:
- ✅ Reuses existing utility file pattern
- ✅ Follows existing code style in the project
- ✅ Provides clear JSDoc documentation

### Step 6: Add Debug Logging

Add comprehensive logging for troubleshooting:

```javascript
const DEBUG = true; // Set to false to disable

function debugLog(...args) {
  if (DEBUG) {
    console.log("[Hide Reply Buttons]", ...args);
  }
}

// Usage in implementation:
debugLog("Setting enabled:", settings.hide_reply_buttons_for_non_owners);
debugLog("Topic category:", categoryId, "Enabled categories:", enabledCategories);
debugLog("Current user ID:", currentUser?.id, "Topic owner ID:", topicOwnerId);
debugLog("Decision:", currentUser.id === topicOwnerId ? "SHOW" : "HIDE");
```

## Documentation Updates

### README.md

Add new section:

```markdown
### Hide Reply Buttons for Non-Owners

**Purpose**: Restrict reply functionality to topic owners in configured categories.

**How it works**:
- When enabled, hides reply buttons from all users except the topic owner
- Only applies in categories configured in "Owner Comment Categories"
- Works independently of the "Allowed groups" access control
- This is a UI-only restriction

**Important limitations**:
- Users can still reply using keyboard shortcuts (Shift+R)
- Users can still reply via API or browser console
- This is not a security feature—use Discourse category permissions for true access control

**Configuration**:
1. Enable "Hide reply buttons for non-owners" setting
2. Ensure "Owner Comment Categories" includes the target categories
3. Reply buttons will be hidden for non-owners in those categories
```

### GROUP_ACCESS_CONTROL.md or New Doc

Create `docs/REPLY_BUTTON_HIDING.md`:

```markdown
# Reply Button Hiding Feature

## Overview
This feature hides reply buttons from non-owner users in categories configured for owner comments.

## Scope
- **UI-only**: Does not prevent replies via keyboard shortcuts or API
- **Category-specific**: Only applies in categories defined in `owner_comment_categories`
- **Owner-based**: Shows buttons only to the user who created the topic

## Independence from Access Control
This feature works independently of the "Allowed groups" setting:
- "Allowed groups" controls who can see the theme component features
- "Hide reply buttons" controls who can see reply buttons within allowed users

## Technical Implementation
- Uses body class `hide-reply-buttons-non-owners` for CSS control
- Re-evaluates on page navigation (SPA-friendly)
- Compares `currentUser.id` with `topic.details.created_by.id`

## Limitations
- Cannot suppress keyboard shortcuts (Shift+R still works)
- Cannot prevent API-based replies
- Not a security feature—use Discourse permissions for true access control
```

## Testing Plan

### Manual Testing Checklist

1. **Setting Toggle**:
   - [ ] Enable setting → verify buttons hide for non-owners
   - [ ] Disable setting → verify buttons show for all users
   
2. **Topic Owner**:
   - [ ] As topic owner → verify reply buttons are visible
   - [ ] As topic owner → verify can click reply buttons
   
3. **Non-Owner User**:
   - [ ] As non-owner → verify reply buttons are hidden
   - [ ] As non-owner → verify Shift+R still opens composer (documented limitation)
   
4. **Category Filtering**:
   - [ ] In configured category → verify hiding works
   - [ ] In non-configured category → verify buttons always show
   
5. **View Modes**:
   - [ ] Regular topic view → verify hiding works
   - [ ] Owner-filtered view (`username_filters` active) → verify hiding works
   
6. **Navigation**:
   - [ ] Navigate between topics → verify re-evaluation works
   - [ ] Refresh page → verify state persists correctly
   
7. **Edge Cases**:
   - [ ] Anonymous user → verify buttons are hidden
   - [ ] Topic with no owner data → verify graceful handling
   - [ ] Mobile view → verify hiding works
   - [ ] Desktop view → verify hiding works

## Implementation Risks and Mitigations

### Risk 1: Incorrect CSS Selectors
**Mitigation**: Test on latest Discourse version; document selectors for future updates

### Risk 2: SPA Navigation Issues
**Mitigation**: Use `api.onPageChange()` and `schedule("afterRender")` per Augment rules

### Risk 3: Performance Impact
**Mitigation**: Minimal—only runs on page change, uses simple DOM class manipulation

### Risk 4: Conflicts with Other Themes
**Mitigation**: Use specific body class; avoid modifying global state

## Rollout Plan

1. Implement on feature branch
2. Test locally with Discourse development environment
3. Test on staging site with real users
4. Document limitations clearly
5. Merge to main after approval
6. Monitor for issues post-deployment

## Future Enhancements (Out of Scope)

- Server-side enforcement (requires Discourse plugin, not theme component)
- Keyboard shortcut suppression (not feasible with theme components)
- Granular control per-post (complex, low value)
- Integration with Discourse permissions system (requires core changes)

