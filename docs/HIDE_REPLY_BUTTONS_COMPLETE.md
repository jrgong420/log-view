# Hide Reply Buttons for Non-Owners - Complete Implementation

## Overview

The "Hide reply buttons for non owners" feature now provides comprehensive reply button hiding in two ways:

1. **Post-level hiding**: Hides reply buttons on individual posts authored by non-owners
2. **Top-level hiding**: Hides topic-level reply buttons (timeline footer, topic footer) when the viewer is not the topic owner

Both behaviors are controlled by a single setting: `hide_reply_buttons_for_non_owners`

## How It Works

### Post-Level Hiding

**Target**: Reply buttons on individual posts  
**Condition**: Post author is NOT the topic owner  
**Implementation**: JavaScript classifies posts and adds CSS class `non-owner-post`

```javascript
// Posts are classified based on authorship
if (postAuthorId === topicOwnerId) {
  postElement.classList.add("owner-post");
} else {
  postElement.classList.add("non-owner-post");
}
```

**CSS**:
```scss
article.topic-post.non-owner-post {
  nav.post-controls .actions button.create,
  nav.post-controls .actions button.reply,
  nav.post-controls .actions button.reply-to-post {
    display: none !important;
  }
}
```

### Top-Level Hiding

**Target**: Topic-level reply buttons (timeline footer, topic footer)  
**Condition**: Viewer is anonymous OR viewer is NOT the topic owner  
**Implementation**: JavaScript adds body class `hide-reply-buttons-non-owners`

```javascript
// Determine if viewer is the topic owner
const currentUser = api.getCurrentUser();
const shouldHideTopLevel = !currentUser || currentUser.id !== topicOwnerId;

// Toggle body class
document.body.classList.toggle("hide-reply-buttons-non-owners", shouldHideTopLevel);
```

**CSS**:
```scss
body.hide-reply-buttons-non-owners {
  .timeline-footer-controls .create,
  .timeline-footer-controls .reply-to-post,
  .topic-footer-main-buttons .create,
  .topic-footer-main-buttons .reply-to-post,
  .topic-footer-buttons .create,
  .topic-footer-buttons .reply-to-post {
    display: none !important;
  }
}
```

## Configuration

### Setting

**Name**: `hide_reply_buttons_for_non_owners`  
**Type**: Boolean  
**Default**: `false`  
**Location**: Admin → Customize → Themes → Log View → Settings

### Prerequisites

1. Enable the setting `hide_reply_buttons_for_non_owners`
2. Configure `owner_comment_categories` with at least one category ID
3. The feature only applies in configured categories

## Behavior Matrix

| Scenario | Post-Level Buttons | Top-Level Buttons |
|----------|-------------------|-------------------|
| Viewer is topic owner | ✅ Visible on all posts | ✅ Visible |
| Viewer is not owner, viewing owner's post | ✅ Visible | ❌ Hidden |
| Viewer is not owner, viewing non-owner's post | ❌ Hidden | ❌ Hidden |
| Anonymous user, viewing owner's post | ✅ Visible | ❌ Hidden |
| Anonymous user, viewing non-owner's post | ❌ Hidden | ❌ Hidden |
| Unconfigured category | ✅ Visible on all posts | ✅ Visible |
| Setting disabled | ✅ Visible on all posts | ✅ Visible |

## Technical Details

### Files Modified

1. **`javascripts/discourse/api-initializers/hide-reply-buttons.gjs`**
   - Added viewer vs owner comparison logic
   - Added body class toggling for top-level hiding
   - Enhanced logging for debugging

2. **`common/common.scss`**
   - Added CSS rules for top-level button hiding
   - Updated comments to explain both behaviors

3. **`settings.yml`**
   - Updated description to reflect both behaviors

4. **`test/acceptance/hide-reply-buttons-non-owners-test.js`**
   - Added test for body class presence
   - Added assertions for top-level hiding behavior

### Decision Flow

```
1. Is setting enabled?
   NO → Remove body class, skip post classification
   YES → Continue

2. Is there a topic?
   NO → Remove body class, skip
   YES → Continue

3. Is topic in configured category?
   NO → Remove body class, skip
   YES → Continue

4. Is there topic owner data?
   NO → Remove body class, skip
   YES → Continue

5. Determine viewer status:
   - Get current user
   - Compare viewer ID with topic owner ID
   - Set body class if viewer is not owner

6. Classify posts:
   - Process all visible posts
   - Add owner-post or non-owner-post class
   - Set up MutationObserver for new posts
```

### CSS Selectors Targeted

**Post-level** (hidden on non-owner posts):
- `nav.post-controls .actions button.create`
- `nav.post-controls .actions button.reply`
- `nav.post-controls .actions button.reply-to-post`
- `.topic-body .actions button.create`
- `.topic-body .actions button.reply`
- `.topic-body .actions button.reply-to-post`

**Top-level** (hidden when viewer is not owner):
- `.timeline-footer-controls .create`
- `.timeline-footer-controls .reply-to-post`
- `.topic-footer-main-buttons .create`
- `.topic-footer-main-buttons .reply-to-post`
- `.topic-footer-buttons .create`
- `.topic-footer-buttons .reply-to-post`

## Testing

### Manual Testing Checklist

**As Topic Owner**:
- [ ] Top-level reply buttons are visible (timeline footer, topic footer)
- [ ] Reply buttons on owner's posts are visible
- [ ] Reply buttons on other users' posts are visible
- [ ] Can click and use all reply buttons

**As Non-Owner (Logged In)**:
- [ ] Top-level reply buttons are hidden
- [ ] Reply buttons on owner's posts are visible
- [ ] Reply buttons on non-owner's posts are hidden
- [ ] Keyboard shortcut (Shift+R) still works

**As Anonymous User**:
- [ ] Top-level reply buttons are hidden
- [ ] Reply buttons on owner's posts are visible
- [ ] Reply buttons on non-owner's posts are hidden

**Category Configuration**:
- [ ] Feature only applies in configured categories
- [ ] Other categories show all reply buttons normally

**Setting Toggle**:
- [ ] Disabling setting shows all buttons
- [ ] Enabling setting hides buttons as expected

### Automated Tests

Run the test suite:
```bash
npm test
```

Or run specific test file:
```bash
npm test -- --filter="Hide Reply Buttons"
```

### Browser Console Debugging

Enable debug logging:
1. Admin → Customize → Themes → Log View → Settings
2. Enable `debug_logging_enabled`
3. Open browser console

Look for logs:
```
[Owner View] [Hide Reply Buttons] Hide reply buttons feature enabled
[Owner View] [Hide Reply Buttons] Top-level button visibility decision
[Owner View] [Hide Reply Buttons] Classifying post
```

Check body class:
```javascript
document.body.classList.contains('hide-reply-buttons-non-owners')
```

Check post classification:
```javascript
document.querySelectorAll('article.topic-post.owner-post').length
document.querySelectorAll('article.topic-post.non-owner-post').length
```

## Limitations

### What This Feature Does NOT Do

1. **Cannot prevent keyboard shortcuts**: Users can still press Shift+R to reply
2. **Cannot prevent API calls**: Technical users can still reply via API
3. **Not a security feature**: Use Discourse permissions for true access control
4. **Does not check Allowed groups**: This setting is independent of group access control

### Why These Limitations Exist

- Theme components run in a sandboxed environment
- Limited access to core event handlers and API interception
- Attempting to block keyboard shortcuts could break accessibility
- This is a UI-only convenience feature, not a security mechanism

## Troubleshooting

### Top-level buttons not hiding

**Check**:
1. Is the setting enabled?
2. Is the topic in a configured category?
3. Are you logged in as the topic owner? (Buttons should be visible for owner)
4. Check browser console for `[Hide Reply Buttons]` logs
5. Inspect `<body>` element - does it have class `hide-reply-buttons-non-owners`?

**Debug**:
```javascript
// In browser console
const topic = Discourse.__container__.lookup("controller:topic")?.model;
const currentUser = Discourse.__container__.lookup("service:current-user");
console.log("Topic owner ID:", topic?.details?.created_by?.id);
console.log("Current user ID:", currentUser?.id);
console.log("Body class present:", document.body.classList.contains('hide-reply-buttons-non-owners'));
```

### Post-level buttons not hiding

**Check**:
1. Are posts being classified? Look for `data-owner-marked="1"` attribute
2. Are posts getting the correct class? (`owner-post` vs `non-owner-post`)
3. Are there conflicting CSS rules from other themes?

**Debug**:
```javascript
// Check classification
document.querySelectorAll('article.topic-post[data-owner-marked]').length
document.querySelectorAll('article.topic-post.non-owner-post').length
```

### Buttons reappear after navigation

This should not happen with the current implementation. If it does:
1. Check browser console for errors
2. Verify MutationObserver is being cleaned up properly
3. Check for conflicting JavaScript from other themes

## Migration Notes

### Changes from Previous Version

**Old behavior** (before this implementation):
- Only hid post-level buttons based on post authorship
- Did NOT hide top-level reply buttons

**New behavior** (current):
- Hides post-level buttons based on post authorship (unchanged)
- ALSO hides top-level buttons based on viewer identity (new)

### Backward Compatibility

- Setting name unchanged: `hide_reply_buttons_for_non_owners`
- Post-level behavior unchanged
- Top-level hiding is additive (new feature)
- No breaking changes for existing deployments

## See Also

- [HIDE_REPLY_BUTTONS_IMPLEMENTATION_SUMMARY.md](./HIDE_REPLY_BUTTONS_IMPLEMENTATION_SUMMARY.md) - Previous implementation
- [HIDE_REPLY_BUTTONS_EXPANDED.md](./HIDE_REPLY_BUTTONS_EXPANDED.md) - Post-level hiding details
- [REPLY_BUTTON_HIDING.md](./REPLY_BUTTON_HIDING.md) - Original documentation

