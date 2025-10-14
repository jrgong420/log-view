# Test Session Guide - Centralized Logger Migration & Bug Fix

**Date**: 2025-10-14  
**Purpose**: Verify centralized logger migration and stale-state bug fix

---

## Pre-Test Setup

### 1. Deploy Theme to Discourse
```bash
# If using discourse_theme CLI
discourse_theme watch .

# Or manually upload via Admin UI:
# Admin → Customize → Themes → Import → From a git repository
```

### 2. Enable Debug Logging
1. Navigate to **Admin → Customize → Themes**
2. Click on your theme (log-view)
3. Click **Settings** tab
4. Find `debug_logging_enabled`
5. ✅ **Enable it** (toggle to ON)
6. Click **Save**

### 3. Open Browser Console
- **Chrome/Edge**: Press `F12` or `Cmd+Option+J` (Mac) / `Ctrl+Shift+J` (Windows)
- **Firefox**: Press `F12` or `Cmd+Option+K` (Mac) / `Ctrl+Shift+K` (Windows)
- **Safari**: Enable Developer menu first, then `Cmd+Option+C`

---

## Test 1: Verify Logging System Works ✅

### Expected Behavior
When `debug_logging_enabled` is ON, you should see logs in console with prefixes like:
- `[Owner View] [Embedded Reply Buttons]`
- `[Owner View] [Owner Comment Prototype]`
- `[Owner View] [Toggle Button]`
- etc.

### Steps
1. ✅ Navigate to a topic in a configured category (one where owner comment mode applies)
2. ✅ Check console for logs like:
   ```
   [Owner View] [Owner Comment Prototype] Checking if owner comment mode should apply
   [Owner View] [Embedded Reply Buttons] AutoRefresh: initializing composer event listeners
   ```
3. ✅ Verify logs appear with structured context objects (not just strings)

### Success Criteria
- ✅ Logs appear in console
- ✅ All logs have consistent prefix format
- ✅ Context objects are visible (expandable in console)
- ✅ No errors in console

---

## Test 2: Verify Logging Can Be Disabled ✅

### Steps
1. ✅ Go back to **Admin → Customize → Themes → Your Theme → Settings**
2. ✅ **Disable** `debug_logging_enabled` (toggle to OFF)
3. ✅ Click **Save**
4. ✅ Refresh the page
5. ✅ Navigate to a topic again

### Expected Behavior
- ✅ No debug/info/warn logs appear in console
- ✅ Only errors (if any) would still appear
- ✅ Features still work normally

### Success Criteria
- ✅ Console is clean (no theme logs)
- ✅ All features work correctly
- ✅ No performance degradation

---

## Test 3: Critical Bug Fix - Second Reply Issue 🐛

**This is the main bug we fixed!**

### Background
**Problem**: When creating a reply while embedded posts are collapsed, the first reply worked correctly, but a second reply without reloading the page reverted to stock Discourse behavior.

**Fix**: Eliminated stale module-scoped state, added direct owner post lookup, removed unreliable fallbacks.

### Setup
1. ✅ **Re-enable** `debug_logging_enabled` (we want to see logs)
2. ✅ Navigate to a topic in owner comment mode
3. ✅ Ensure the owner's embedded replies section is **collapsed** (click collapse button if needed)

### Test Steps

#### Step 1: First Reply (Should Work)
1. ✅ Click the **Reply** button on the collapsed owner section
2. ✅ Type a test message: "First test reply"
3. ✅ Submit the reply
4. ✅ **Watch console logs** - you should see:
   ```
   [Owner View] [Embedded Reply Buttons] AutoRefresh: target parent post #XXX
   [Owner View] [Embedded Reply Buttons] AutoRefresh: direct owner post lookup succeeded
   [Owner View] [Embedded Reply Buttons] AutoRefresh: collapsed detected for owner post #XXX — expanding and loading replies
   [Owner View] [Embedded Reply Buttons] AutoScroll: scrolling to post #YYY
   ```

**Expected Result**:
- ✅ Owner section expands automatically
- ✅ Embedded replies load
- ✅ Your new reply appears in the embedded section
- ✅ Page scrolls to your new reply
- ✅ Reply is highlighted briefly

#### Step 2: Second Reply (THE BUG TEST) 🎯
**DO NOT RELOAD THE PAGE!**

1. ✅ Collapse the owner section again (click collapse button)
2. ✅ Click the **Reply** button on the collapsed owner section again
3. ✅ Type a test message: "Second test reply"
4. ✅ Submit the reply
5. ✅ **Watch console logs carefully**

**Expected Result (FIXED)**:
- ✅ Console shows correct owner post number (same as first reply)
- ✅ Owner section expands automatically
- ✅ Embedded replies refresh
- ✅ Your second reply appears **below the first reply** in the embedded section
- ✅ Page scrolls to your second reply
- ✅ Reply is highlighted briefly

**Bug Behavior (OLD - Should NOT happen)**:
- ❌ Console shows wrong owner post number
- ❌ Wrong section expands
- ❌ Reply appears in main stream instead of embedded section
- ❌ Stock Discourse behavior (no auto-refresh)

### Console Log Verification

Look for these specific log patterns:

**Good (Bug Fixed)** ✅:
```
[Owner View] [Embedded Reply Buttons] AutoRefresh: target parent post #807 (source: lastReplyContext)
[Owner View] [Embedded Reply Buttons] AutoRefresh: direct owner post lookup succeeded for #807
[Owner View] [Embedded Reply Buttons] AutoRefresh: collapsed detected for owner post #807 — expanding and loading replies
[Owner View] [Embedded Reply Buttons] Finalize: clearing collapsed expansion state and ephemeral reply state
[Owner View] [Embedded Reply Buttons] AutoScroll: scrolling to post #842
```

**Bad (Bug Present)** ❌:
```
[Owner View] [Embedded Reply Buttons] AutoRefresh: target parent post #807
[Owner View] [Embedded Reply Buttons] AutoRefresh: collapsed detected for owner post #795  ← WRONG POST!
```

---

## Test 4: Third Reply (Stress Test) 🔥

### Steps
1. ✅ Without reloading, collapse the owner section again
2. ✅ Create a **third** reply: "Third test reply"
3. ✅ Verify it works correctly (same as second reply)

### Success Criteria
- ✅ Correct owner post expanded
- ✅ Reply appears in embedded section
- ✅ Auto-scroll works
- ✅ No console errors

---

## Test 5: Standard Reply Button Interception

### Steps
1. ✅ Navigate to a topic in owner comment mode (filtered view)
2. ✅ Find a **non-owner post** (a reply from someone else)
3. ✅ Click the standard **Reply** button on that post
4. ✅ Watch console logs

### Expected Behavior
```
[Owner View] [Embedded Reply Buttons] Standard reply intercepted for owner post #XXX
```

### Success Criteria
- ✅ Composer opens to reply to the owner post (not the clicked post)
- ✅ Console shows interception log
- ✅ No errors

---

## Test 6: Toggle Button

### Steps
1. ✅ Navigate to a topic in owner comment mode
2. ✅ Click the **"Show All Posts"** button (toggle button)
3. ✅ Watch console logs

### Expected Behavior
```
[Owner View] [Toggle Button] Navigating to unfiltered view
```

### Success Criteria
- ✅ URL changes (username_filters parameter removed)
- ✅ All posts visible
- ✅ Toggle button changes to "Show Owner Comments Only"
- ✅ Console shows navigation log

---

## Test 7: MutationObserver Rate-Limiting

### Steps
1. ✅ Navigate to a topic in owner comment mode
2. ✅ Expand/collapse owner sections rapidly (click multiple times)
3. ✅ Watch console logs

### Expected Behavior
- ✅ Logs appear but are **throttled** (not flooding console)
- ✅ You should see rate-limited logs with 2-second gaps

### Success Criteria
- ✅ Console doesn't flood with hundreds of logs
- ✅ Throttling works correctly
- ✅ Features still work

---

## Test 8: Error Logging (Always Visible)

### Steps
1. ✅ Disable `debug_logging_enabled` in admin settings
2. ✅ Refresh page
3. ✅ Trigger an error condition (if possible)

### Expected Behavior
- ✅ Errors still appear in console (even with debug disabled)
- ✅ Format: `[Owner View] [Feature] Error message`

### Success Criteria
- ✅ Errors are always visible
- ✅ Debug/info/warn logs are hidden

---

## Test 9: Performance Check

### Steps
1. ✅ Disable `debug_logging_enabled`
2. ✅ Open browser DevTools → Performance tab
3. ✅ Start recording
4. ✅ Navigate to a topic
5. ✅ Stop recording
6. ✅ Check for any logging-related overhead

### Expected Behavior
- ✅ No performance impact when logging disabled
- ✅ No console.log calls in performance trace

### Success Criteria
- ✅ Page load time unchanged
- ✅ No logging overhead visible

---

## Test 10: Group Access Control

### Steps
1. ✅ Enable `debug_logging_enabled`
2. ✅ Navigate to a topic as a user in the allowed group
3. ✅ Check console logs

### Expected Behavior
```
[Owner View] [Group Access] User has access to owner comment features
```

### Success Criteria
- ✅ Access check logs appear
- ✅ Features work correctly
- ✅ No errors

---

## Checklist Summary

### Critical Tests (Must Pass) ✅
- [ ] Test 1: Logging appears when enabled
- [ ] Test 2: Logging disappears when disabled
- [ ] Test 3: **Second reply bug is fixed** 🎯
- [ ] Test 4: Third reply works correctly
- [ ] Test 9: No performance impact when disabled

### Important Tests (Should Pass) ✅
- [ ] Test 5: Standard reply interception works
- [ ] Test 6: Toggle button works
- [ ] Test 7: Rate-limiting prevents console flooding
- [ ] Test 8: Errors always visible

### Nice-to-Have Tests ✅
- [ ] Test 10: Group access control logs correctly

---

## Reporting Results

### If All Tests Pass ✅
Report back with:
```
✅ All tests passed!
- Logging system works correctly
- Second reply bug is FIXED
- No performance issues
- Ready for production
```

### If Tests Fail ❌
Report back with:
1. Which test failed
2. Console logs (copy/paste)
3. Expected vs actual behavior
4. Screenshots if helpful

---

## Quick Test (5 Minutes)

If you're short on time, run these critical tests only:

1. ✅ Enable `debug_logging_enabled`
2. ✅ Navigate to topic in owner comment mode
3. ✅ Verify logs appear in console
4. ✅ **Create two replies while collapsed (THE BUG TEST)**
5. ✅ Verify both replies work correctly
6. ✅ Disable `debug_logging_enabled`
7. ✅ Verify logs disappear

---

**Ready to test!** 🚀

Start with the Quick Test if you want fast verification, or run the full test suite for comprehensive validation.

