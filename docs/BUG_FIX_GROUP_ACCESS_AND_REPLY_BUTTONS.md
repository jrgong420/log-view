# Bug Fix: Group Access Control and Reply Button Visibility

## Date
2025-10-14

## Issues Identified

### Issue 1: Toggle Button Not Showing for Group Members
**Symptom**: Users who are members of allowed groups cannot see the toggle view button.

**Root Cause**: Group ID comparison was failing due to type inconsistency. The `allowedGroupIds` array contained numbers parsed from the settings string, but `userGroupIds` might have been strings or numbers depending on how Discourse provides the data. The comparison `userGroupIds.includes(allowedId)` was failing when types didn't match.

**Evidence from Logs**:
```
[Group Access Control] Allowed groups setting {raw: '13|1|2', parsed: Array(3)}
[Group Access Control] User group membership {userGroupIds: Array(3), userGroupNames: Array(3), allowedGroupIds: Array(3)}
[Group Access Control] Access decision {decision: 'DENIED', isMember: false, userGroupNames: Array(3)}
```

The user has 3 groups, the allowed groups setting has 3 groups, but access is DENIED.

### Issue 2: Embedded Reply Buttons Visible for Non-Owners
**Symptom**: The embedded reply buttons (section-level reply buttons in embedded posts) are visible for non-topic-owners, even when `hide_reply_buttons_for_non_owners` is enabled.

**Root Cause**: The CSS rule for hiding reply buttons when `body.hide-reply-buttons-non-owners` is present only targeted:
- Timeline footer controls
- Topic footer main buttons
- Legacy topic footer buttons

It did NOT target the `.embedded-reply-button` class that is injected by the `embedded-reply-buttons.gjs` initializer.

**Evidence from Logs**:
```
[Hide Reply Buttons] User is not topic owner - hiding top-level reply buttons
```

The body class was being added correctly, but the CSS wasn't hiding all reply buttons.

## Fixes Applied

### Fix 1: Normalize Group IDs for Type-Safe Comparison

**Files Modified**:
- `javascripts/discourse/lib/group-access-utils.js`
- `javascripts/discourse/api-initializers/group-access-control.gjs`

**Changes**:
```javascript
// Before
const isMember = allowedGroupIds.some((allowedId) =>
  userGroupIds.includes(allowedId)
);

// After
// Normalize both arrays to numbers for comparison
const normalizedAllowedIds = allowedGroupIds.map(id => Number(id));
const normalizedUserGroupIds = userGroupIds.map(id => Number(id));

const isMember = normalizedAllowedIds.some((allowedId) => 
  normalizedUserGroupIds.includes(allowedId)
);
```

**Rationale**: By explicitly converting both arrays to numbers using `Number()`, we ensure type-safe comparison regardless of how Discourse provides the group IDs. This prevents false negatives where a user is actually a member but the comparison fails due to type mismatch (e.g., `13 !== "13"`).

**Enhanced Logging**: Added raw and normalized values to debug logs to help diagnose future issues:
```javascript
log.info("Access decision", {
  decision: isMember ? "GRANTED" : "DENIED",
  isMember,
  allowedGroupIds: normalizedAllowedIds,
  userGroupIds: normalizedUserGroupIds,
  rawAllowedGroupIds: allowedGroupIds,
  rawUserGroupIds: userGroupIds
});
```

### Fix 2: Hide Embedded Reply Buttons for Non-Owners

**File Modified**:
- `common/common.scss`

**Changes**:
```scss
/* Hide top-level reply buttons when viewer is not the topic owner */
body.hide-reply-buttons-non-owners {
  /* Timeline footer controls (desktop) */
  .timeline-footer-controls .create,
  .timeline-footer-controls .reply-to-post,

  /* Topic footer main buttons */
  .topic-footer-main-buttons .create,
  .topic-footer-main-buttons .reply-to-post,

  /* Legacy topic footer buttons outlet */
  .topic-footer-buttons .create,
  .topic-footer-buttons .reply-to-post,

  /* Embedded reply buttons (section-level) */  // ← NEW
  .embedded-reply-button {                       // ← NEW
    display: none !important;                    // ← NEW
  }                                              // ← NEW
}
```

**Rationale**: The `hide_reply_buttons_for_non_owners` setting is documented as hiding reply buttons for non-topic-owners, and this should include ALL reply buttons, including the embedded reply buttons that appear in the embedded posts sections.

## Expected Behavior After Fix

### Group Access Control
1. ✅ Users who are members of ANY allowed group should see the toggle button
2. ✅ Users who are NOT members of any allowed group should NOT see the toggle button
3. ✅ If no groups are configured, ALL users (including anonymous) should see the toggle button
4. ✅ Group membership check works regardless of whether group IDs are stored as strings or numbers

### Reply Button Hiding
1. ✅ When `hide_reply_buttons_for_non_owners` is enabled and viewer is NOT the topic owner:
   - Timeline footer reply buttons are hidden
   - Topic footer reply buttons are hidden
   - Post-level reply buttons on non-owner posts are hidden
   - **Embedded reply buttons are hidden** (NEW)
2. ✅ When viewer IS the topic owner, all reply buttons are visible
3. ✅ This feature works independently of group access control

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

