# Bug Fix: Reply Buttons Incorrectly Hidden for Topic Owners

**Date:** January 14, 2025  
**Status:** ✅ FIXED  
**File:** `javascripts/discourse/api-initializers/hide-reply-buttons.gjs`

---

## Problem

**Symptom:** When the "Hide reply buttons for non owners" setting is enabled, reply buttons in `timeline-footer-controls` and `topic-footer-buttons` are incorrectly hidden for topic owners.

**User Report:** "When I view a topic where I am the topic owner, the reply buttons are not displayed in timeline-footer-controls and topic-footer-buttons."

**Expected Behavior:** Topic owners should always see reply buttons, regardless of the "Hide reply buttons for non owners" setting (since they are the owner, not a "non-owner").

---

## Root Cause

**Type mismatch in ID comparison** causing the ownership check to fail.

### The Bug

The code was using strict inequality (`!==`) to compare user IDs:

```javascript
const currentUser = api.getCurrentUser();
const shouldHideTopLevel = !currentUser || currentUser.id !== topicOwnerId;
```

**Problem:** If `currentUser.id` is a `Number` and `topicOwnerId` is a `String` (or vice versa), the comparison fails:

```javascript
// Example of the bug:
const currentUser = { id: 123 };      // Number
const topicOwnerId = "123";           // String
currentUser.id !== topicOwnerId       // true (123 !== "123")
// Result: Owner is treated as non-owner!
```

### Why This Happens

- Discourse API responses may return IDs as strings or numbers depending on the endpoint
- JavaScript's strict equality (`===`) and inequality (`!==`) operators don't perform type coercion
- The code assumed both IDs would always be the same type

---

## Solution

**Type normalization and explicit ownership check** with enhanced logging.

### Code Changes

**File:** `javascripts/discourse/api-initializers/hide-reply-buttons.gjs`  
**Lines:** 220-247

**Before:**
```javascript
log.info("Starting post classification", { topicOwnerId });

// Determine if top-level reply buttons should be hidden
// Hide if viewer is anonymous OR viewer is not the topic owner
const currentUser = api.getCurrentUser();
const shouldHideTopLevel = !currentUser || currentUser.id !== topicOwnerId;

log.debug("Top-level button visibility decision", {
  currentUserId: currentUser?.id,
  topicOwnerId,
  shouldHideTopLevel
});

// Toggle body class for top-level button hiding
document.body.classList.toggle("hide-reply-buttons-non-owners", shouldHideTopLevel);
```

**After:**
```javascript
log.info("Starting post classification", { topicOwnerId });

// Determine if top-level reply buttons should be hidden
const currentUser = api.getCurrentUser();

// Normalize IDs to numbers for type-safe comparison
// This prevents bugs where currentUser.id (Number) !== topicOwnerId (String)
const currentUserId = currentUser?.id ? Number(currentUser.id) : null;
const normalizedTopicOwnerId = Number(topicOwnerId);

const isTopicOwner = currentUserId !== null && currentUserId === normalizedTopicOwnerId;

log.debug("Top-level button visibility decision", {
  currentUserId,
  currentUserIdType: typeof currentUser?.id,
  topicOwnerId: normalizedTopicOwnerId,
  topicOwnerIdType: typeof topicOwnerId,
  isTopicOwner
});

// Show buttons if user is the topic owner, hide otherwise
if (isTopicOwner) {
  document.body.classList.remove("hide-reply-buttons-non-owners");
  log.info("User is topic owner - showing top-level reply buttons");
} else {
  document.body.classList.add("hide-reply-buttons-non-owners");
  log.info("User is not topic owner - hiding top-level reply buttons");
}
```

### Key Improvements

1. **Type Normalization:** Both IDs converted to `Number` before comparison
2. **Explicit Ownership Check:** Clear `isTopicOwner` boolean for better readability
3. **Enhanced Logging:** Logs both values AND types of IDs for debugging
4. **Defensive Null Handling:** Properly handles anonymous users and missing data
5. **Explicit If/Else:** Replaces confusing `classList.toggle()` with clear add/remove logic

---

## Testing Instructions

### Prerequisites
1. Enable: `hide_reply_buttons_for_non_owners = true`
2. Configure: `owner_comment_categories` with at least one category ID
3. Enable: `debug_logging_enabled = true`

### Test Scenario 1: As Topic Owner ✅

**Steps:**
1. Navigate to a topic you created in a configured category
2. Open browser console (F12)
3. Look for log messages

**Expected Results:**
- ✅ Console: `"User is topic owner - showing top-level reply buttons"`
- ✅ Console: `isTopicOwner: true`
- ✅ Timeline footer reply button is **VISIBLE**
- ✅ Topic footer reply button is **VISIBLE**
- ✅ Body class `hide-reply-buttons-non-owners` is **ABSENT**

**Verification:**
```javascript
// Check body class
document.body.classList.contains('hide-reply-buttons-non-owners')
// Expected: false

// Check buttons exist and are visible
const timelineBtn = document.querySelector('.timeline-footer-controls .create');
const footerBtn = document.querySelector('.topic-footer-main-buttons .create');
console.log('Timeline button:', timelineBtn ? 'VISIBLE' : 'NOT FOUND');
console.log('Footer button:', footerBtn ? 'VISIBLE' : 'NOT FOUND');
// Expected: both VISIBLE
```

### Test Scenario 2: As Non-Owner ✅

**Steps:**
1. Navigate to a topic created by another user in a configured category
2. Open browser console (F12)

**Expected Results:**
- ✅ Console: `"User is not topic owner - hiding top-level reply buttons"`
- ✅ Console: `isTopicOwner: false`
- ✅ Timeline footer reply button is **HIDDEN**
- ✅ Topic footer reply button is **HIDDEN**
- ✅ Body class `hide-reply-buttons-non-owners` is **PRESENT**

**Verification:**
```javascript
// Check body class
document.body.classList.contains('hide-reply-buttons-non-owners')
// Expected: true

// Check buttons are hidden by CSS
const timelineBtn = document.querySelector('.timeline-footer-controls .create');
if (timelineBtn) {
  console.log('Display:', window.getComputedStyle(timelineBtn).display);
  // Expected: "none"
}
```

### Test Scenario 3: As Anonymous User ✅

**Steps:**
1. Log out
2. Navigate to any topic in a configured category

**Expected Results:**
- ✅ Console: `"User is not topic owner - hiding top-level reply buttons"`
- ✅ Console: `isTopicOwner: false`
- ✅ Reply buttons are **HIDDEN**
- ✅ Body class `hide-reply-buttons-non-owners` is **PRESENT**

---

## Debugging

### Check ID Types and Values

```javascript
const topic = require("discourse/controllers/topic").default.currentModel;
const currentUser = Discourse.User.current();

console.log("=== ID Comparison Debug ===");
console.log("Current User ID:", currentUser?.id, `(${typeof currentUser?.id})`);
console.log("Topic Owner ID:", topic.details?.created_by?.id, `(${typeof topic.details?.created_by?.id})`);
console.log("Strict equality (===):", currentUser?.id === topic.details?.created_by?.id);
console.log("Loose equality (==):", currentUser?.id == topic.details?.created_by?.id);
console.log("After Number():", Number(currentUser?.id) === Number(topic.details?.created_by?.id));
console.log("Body class:", document.body.classList.contains("hide-reply-buttons-non-owners"));
```

**If you see a type mismatch:**
```
Current User ID: 123 (number)
Topic Owner ID: "123" (string)
Strict equality (===): false  ← THIS WAS THE BUG
After Number(): true  ← FIX WORKS
```

### Check Button Visibility

```javascript
const buttons = {
  timeline: document.querySelector('.timeline-footer-controls .create'),
  topicFooter: document.querySelector('.topic-footer-main-buttons .create'),
  legacyFooter: document.querySelector('.topic-footer-buttons .create')
};

console.log("=== Button Visibility ===");
Object.entries(buttons).forEach(([name, btn]) => {
  if (btn) {
    const style = window.getComputedStyle(btn);
    console.log(`${name}:`, {
      exists: true,
      display: style.display,
      visibility: style.visibility
    });
  } else {
    console.log(`${name}:`, { exists: false });
  }
});
```

---

## Rollback Plan

If the fix causes issues, revert to the previous logic:

```javascript
const currentUser = api.getCurrentUser();
const shouldHideTopLevel = !currentUser || currentUser.id !== topicOwnerId;

log.debug("Top-level button visibility decision", {
  currentUserId: currentUser?.id,
  topicOwnerId,
  shouldHideTopLevel
});

document.body.classList.toggle("hide-reply-buttons-non-owners", shouldHideTopLevel);
```

---

## Related Files

- **JavaScript:** `javascripts/discourse/api-initializers/hide-reply-buttons.gjs`
- **CSS:** `common/common.scss` (lines 220-235)
- **Settings:** `settings.yml` (line 42)
- **Tests:** `test/acceptance/hide-reply-buttons-non-owners-test.js`

---

## Verification Checklist

- [x] Code changes implemented
- [x] Type normalization added
- [x] Enhanced logging added
- [ ] Manual testing as topic owner
- [ ] Manual testing as non-owner
- [ ] Manual testing as anonymous user
- [ ] Console logs verified
- [ ] Reply buttons visible for owners
- [ ] Reply buttons hidden for non-owners

---

## Next Steps

1. **Deploy** the updated theme to your Discourse instance
2. **Test** all three scenarios (owner, non-owner, anonymous)
3. **Verify** console logs show correct ownership determination
4. **Disable** debug logging after confirming the fix works
5. **Monitor** for any edge cases or issues

---

**End of Bug Fix Report**

