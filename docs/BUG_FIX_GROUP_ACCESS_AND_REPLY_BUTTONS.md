# Bug Fix: Group Access Control and Reply Button Visibility

## Date
2025-10-14

## Issues Identified

### Issue 1: Toggle Button Not Showing for Group Members (RESOLVED - User Not in Allowed Groups)

**Initial Symptom**: Users who should have access cannot see the toggle view button.

**Root Cause Analysis**:
After adding debug logging, discovered the user is NOT actually in the allowed groups:
- **Allowed groups**: `[13, 1, 2]`
- **User's groups**: `[10, 11, 12]` (Vertrauensstufe_0, Vertrauensstufe_1, Vertrauensstufe_2)

**Resolution**: This is working as designed. The user needs to either:
1. Be added to one of the allowed groups (13, 1, or 2), OR
2. Have their groups (10, 11, 12) added to the allowed groups setting, OR
3. Clear the allowed groups setting entirely (empty = everyone has access)

**Type Safety Fix Applied**: Even though this specific case was a configuration issue, we added type normalization to prevent future type mismatch bugs:
```javascript
const normalizedAllowedIds = allowedGroupIds.map(id => Number(id));
const normalizedUserGroupIds = userGroupIds.map(id => Number(id));
```

### Issue 2: Reply Buttons Visible for Non-Owners

**Symptom**: Reply buttons are visible for non-topic-owners, even when `hide_reply_buttons_for_non_owners` is enabled.

**Root Cause**: Multiple issues:
1. The CSS selectors were incomplete - missing embedded reply buttons and some button variations
2. Possible CSS specificity issues with newer Discourse versions
3. Missing debug logging to identify which buttons are visible

**Evidence from Logs**:
```
[Hide Reply Buttons] User is not topic owner - hiding top-level reply buttons
```

The body class was being added correctly, but some buttons were still visible.

**Important Clarification**: The `hide_reply_buttons_for_non_owners` feature is **completely independent** of group access control:
- ✅ Does NOT check `allowed_groups` setting
- ✅ Does NOT check user group membership
- ✅ Only checks: setting enabled, category configured, viewer vs topic owner
- ✅ Works for ALL users (including those not in allowed groups)

## Fixes Applied

### Fix 1: Enhanced Debug Logging for Group Access

**Files Modified**:
- `javascripts/discourse/lib/group-access-utils.js`
- `javascripts/discourse/api-initializers/group-access-control.gjs`

**Changes**: Added type normalization and enhanced logging to help diagnose group membership issues:

```javascript
// Normalize both arrays to numbers for comparison
const normalizedAllowedIds = allowedGroupIds.map(id => Number(id));
const normalizedUserGroupIds = userGroupIds.map(id => Number(id));

const isMember = normalizedAllowedIds.some((allowedId) =>
  normalizedUserGroupIds.includes(allowedId)
);

// Enhanced logging with both raw and normalized values
log.info("Access decision", {
  decision: isMember ? "GRANTED" : "DENIED",
  isMember,
  allowedGroupIds: normalizedAllowedIds,
  userGroupIds: normalizedUserGroupIds,
  rawAllowedGroupIds: allowedGroupIds,
  rawUserGroupIds: userGroupIds
});
```

**Rationale**:
1. Type normalization prevents false negatives from type mismatches (e.g., `13 !== "13"`)
2. Enhanced logging shows both raw and normalized values for easier debugging
3. Makes it immediately clear when a user is not in the allowed groups

### Fix 2: Comprehensive Reply Button Hiding CSS

**File Modified**:
- `common/common.scss`

**Changes**: Expanded CSS selectors to catch all reply button variations:

```scss
body.hide-reply-buttons-non-owners {
  /* Timeline footer controls (desktop) */
  .timeline-footer-controls .create,
  .timeline-footer-controls .reply-to-post,
  .timeline-footer-controls button.create,
  .timeline-footer-controls button.reply-to-post,
  .timeline-footer-controls button[aria-label*="Reply"],
  .timeline-footer-controls button[aria-label*="reply"],

  /* Topic footer main buttons */
  .topic-footer-main-buttons .create,
  .topic-footer-main-buttons .reply-to-post,
  .topic-footer-main-buttons button.create,
  .topic-footer-main-buttons button.reply-to-post,
  .topic-footer-main-buttons button[aria-label*="Reply"],
  .topic-footer-main-buttons button[aria-label*="reply"],

  /* Legacy topic footer buttons outlet */
  .topic-footer-buttons .create,
  .topic-footer-buttons .reply-to-post,
  .topic-footer-buttons button.create,
  .topic-footer-buttons button.reply-to-post,

  /* Topic footer buttons (any container) */
  #topic-footer-buttons .create,
  #topic-footer-buttons .reply-to-post,
  #topic-footer-buttons button.create,
  #topic-footer-buttons button.reply-to-post,

  /* Embedded reply buttons (section-level) */
  .embedded-reply-button {
    display: none !important;
  }
}
```

**Rationale**:
1. Added `button.` prefix variants for newer Discourse versions
2. Added `aria-label` attribute selectors as fallback
3. Added `#topic-footer-buttons` ID selector
4. Included embedded reply buttons
5. Ensures comprehensive coverage across Discourse versions

### Fix 3: Enhanced Debug Logging for Reply Buttons

**File Modified**:
- `javascripts/discourse/api-initializers/hide-reply-buttons.gjs`

**Changes**: Added comprehensive debug logging to identify which buttons are in the DOM:

```javascript
// After adding body class, log what buttons are present
schedule("afterRender", () => {
  const replyButtons = {
    timelineCreate: document.querySelectorAll(".timeline-footer-controls .create, .timeline-footer-controls button.create").length,
    timelineReply: document.querySelectorAll(".timeline-footer-controls .reply-to-post, .timeline-footer-controls button.reply-to-post").length,
    topicFooterCreate: document.querySelectorAll(".topic-footer-main-buttons .create, .topic-footer-main-buttons button.create").length,
    topicFooterReply: document.querySelectorAll(".topic-footer-main-buttons .reply-to-post, .topic-footer-main-buttons button.reply-to-post").length,
    embeddedReply: document.querySelectorAll(".embedded-reply-button").length,
    allCreateButtons: document.querySelectorAll("button.create").length,
    allReplyButtons: document.querySelectorAll("button.reply-to-post, button.reply").length
  };

  log.debug("Reply buttons in DOM after body class added", replyButtons);

  // Log all reply-related buttons with their visibility status
  const allButtons = document.querySelectorAll("button.create, button.reply-to-post, button.reply, .embedded-reply-button");
  if (allButtons.length > 0) {
    log.debug("All reply-related buttons found", {
      count: allButtons.length,
      buttons: Array.from(allButtons).map(btn => ({
        classes: btn.className,
        text: btn.textContent?.trim(),
        parent: btn.parentElement?.className,
        visible: window.getComputedStyle(btn).display !== "none"
      }))
    });
  }
});
```

**Rationale**: This logging helps identify:
1. Which reply buttons are present in the DOM
2. Whether they're being hidden by CSS
3. Which selectors might be missing from the CSS

## Expected Behavior After Fix

### Group Access Control
1. ✅ Users who are members of ANY allowed group should see the toggle button
2. ✅ Users who are NOT members of any allowed group should NOT see the toggle button
3. ✅ If no groups are configured, ALL users (including anonymous) should see the toggle button
4. ✅ Enhanced logging shows exactly which groups the user is in vs. which are allowed

### Reply Button Hiding
1. ✅ When `hide_reply_buttons_for_non_owners` is enabled and viewer is NOT the topic owner:
   - Timeline footer reply buttons are hidden
   - Topic footer reply buttons are hidden
   - Post-level reply buttons on non-owner posts are hidden
   - Embedded reply buttons are hidden
   - ALL button variations are caught by expanded CSS selectors
2. ✅ When viewer IS the topic owner, all reply buttons are visible
3. ✅ **This feature works independently of group access control** (no group membership check)
4. ✅ Debug logging shows which buttons are present and their visibility status

## Testing Checklist

### Group Access Control
- [ ] User in allowed group can see toggle button
- [ ] User not in allowed group cannot see toggle button
- [ ] Multiple groups configured: user in ANY group can see toggle button
- [ ] No groups configured: all users can see toggle button
- [ ] Check browser console for "Access decision" logs showing GRANTED/DENIED correctly

### Reply Button Hiding
- [ ] Non-owner cannot see timeline footer reply buttons
- [ ] Non-owner cannot see topic footer reply buttons
- [ ] Non-owner cannot see post-level reply buttons on non-owner posts
- [ ] Non-owner cannot see embedded reply buttons (section-level)
- [ ] Topic owner CAN see all reply buttons
- [ ] Check browser console for "User is topic owner" or "User is not topic owner" logs

### Integration
- [ ] Reply button hiding works even when user is not in allowed groups
- [ ] Toggle button visibility is controlled by group access
- [ ] Both features work correctly in configured categories
- [ ] Both features are disabled in non-configured categories

## Debug Logging

Enable `debug_logging_enabled` in theme settings to see detailed logs:

```javascript
// Group access logs
[Owner View] [Group Access Control] Access decision {
  decision: 'GRANTED',
  isMember: true,
  allowedGroupIds: [13, 1, 2],
  userGroupIds: [13, 1, 2],
  rawAllowedGroupIds: [13, 1, 2],
  rawUserGroupIds: [13, 1, 2]
}

// Reply button hiding logs
[Owner View] [Hide Reply Buttons] User is not topic owner - hiding top-level reply buttons
```

## Related Files
- `javascripts/discourse/lib/group-access-utils.js` - Shared group access utilities
- `javascripts/discourse/api-initializers/group-access-control.gjs` - Group access body class management
- `javascripts/discourse/api-initializers/owner-toggle-outlets.gjs` - Toggle button rendering
- `javascripts/discourse/api-initializers/hide-reply-buttons.gjs` - Reply button hiding logic
- `javascripts/discourse/api-initializers/embedded-reply-buttons.gjs` - Embedded reply button injection
- `common/common.scss` - CSS for hiding buttons and toggle button visibility
- `settings.yml` - Theme settings definitions

## References
- [Group Access Control Documentation](../GROUP_ACCESS_CONTROL.md)
- [Hide Reply Buttons Implementation](HIDE_REPLY_BUTTONS_IMPLEMENTATION.md)
- [Embedded Reply Buttons](../SECTION_LEVEL_REPLY_BUTTON_CHANGES.md)

