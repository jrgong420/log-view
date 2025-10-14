# Testing Guide: Debug Logging Implementation

**Date**: 2025-10-14  
**Purpose**: Verify that the centralized logging system works correctly and all features remain functional.

---

## Pre-Test Checklist

### 1. ✅ Verify Files Are Saved
All modified files should be saved and committed:
- [x] `settings.yml`
- [x] `locales/en.yml`
- [x] `javascripts/discourse/lib/logger.js`
- [x] `javascripts/discourse/api-initializers/group-access-control.gjs`
- [x] `javascripts/discourse/api-initializers/hide-reply-buttons.gjs`
- [x] `javascripts/discourse/api-initializers/owner-comment-prototype.gjs`
- [x] `javascripts/discourse/api-initializers/owner-toggle-outlets.gjs`
- [x] `javascripts/discourse/components/owner-toggle-button.gjs`
- [x] `javascripts/discourse/lib/group-access-utils.js`

### 2. ✅ Check for Syntax Errors
Run a quick syntax check (if available):
```bash
# If you have a linter configured
npm run lint
# or
yarn lint
```

---

## Test 1: Verify Logging is Disabled by Default

**Goal**: Confirm no debug logs appear when `debug_logging_enabled = false` (default)

### Steps:
1. **Deploy the theme** to your Discourse instance
2. **Open browser console** (F12 → Console tab)
3. **Navigate to a topic** in a configured category
4. **Observe console output**

### Expected Result:
- ✅ **No debug logs** should appear
- ✅ **No info logs** should appear
- ✅ **No warning logs** should appear
- ✅ Only **errors** (if any) should appear

### If You See Logs:
⚠️ **PROBLEM**: Logging is not properly gated
- Check that `settings.yml` has `debug_logging_enabled: default: false`
- Verify the theme was reloaded after changes
- Check browser console for any JavaScript errors

---

## Test 2: Enable Debug Logging

**Goal**: Verify the setting toggle works and logs appear when enabled

### Steps:
1. **Go to Admin Panel**:
   - Navigate to: `Admin → Customize → Themes`
   - Find your theme: "Owner Comments"
   - Click "Settings" (gear icon)

2. **Enable Debug Logging**:
   - Find setting: `debug_logging_enabled`
   - Check the box to enable it
   - Click "Save"

3. **Refresh the page** (important!)

4. **Navigate to a topic** in a configured category

5. **Open browser console** (F12 → Console tab)

### Expected Result:
✅ You should see logs like:
```
[Owner View] [Owner Comments] === Page change detected === {url: "/t/..."}
[Owner View] [Owner Comments] Running afterRender hook
[Owner View] [Owner Comments] Topic controller resolved {hasController: true, hasTopic: true, topicId: 123}
[Owner View] [Owner Comments] Current state {currentFilter: null, hasFilteredNotice: false, ...}
[Owner View] [Group Access Control] Access decision {decision: "GRANTED", isMember: true, ...}
```

### If You Don't See Logs:
⚠️ **PROBLEM**: Logger not working correctly
- Check browser console for JavaScript errors
- Verify `logger.js` was loaded correctly
- Check that `settings` global variable is available

---

## Test 3: Verify Feature Functionality (Logging Disabled)

**Goal**: Ensure all features still work with logging disabled

### Steps:
1. **Disable debug logging** (Admin → Settings → uncheck `debug_logging_enabled`)
2. **Refresh the page**
3. **Test each feature**:

#### 3.1 Auto-Filter Feature
- [ ] Navigate to topic in configured category
- [ ] Verify URL has `?username_filters=<owner>`
- [ ] Verify only owner's posts are visible
- [ ] Verify filtered notice appears at top

#### 3.2 Toggle Button
- [ ] Verify toggle button appears in timeline (desktop)
- [ ] Click toggle to unfiltered view
- [ ] Verify all posts now visible
- [ ] Click toggle back to filtered view
- [ ] Verify filter reapplies

#### 3.3 Hide Reply Buttons (if enabled)
- [ ] Navigate to topic in configured category
- [ ] Verify reply buttons hidden on non-owner posts
- [ ] Verify reply buttons visible on owner posts

#### 3.4 Group Access Control (if configured)
- [ ] Log in as user NOT in allowed groups
- [ ] Verify features are disabled
- [ ] Log in as user IN allowed groups
- [ ] Verify features are enabled

### Expected Result:
✅ **All features work exactly as before**
- No regressions
- No broken functionality
- No console errors

---

## Test 4: Verify Logging Content (Logging Enabled)

**Goal**: Verify logs are helpful and contain useful information

### Steps:
1. **Enable debug logging** (Admin → Settings → check `debug_logging_enabled`)
2. **Refresh the page**
3. **Navigate to a topic** in configured category
4. **Review console logs**

### Expected Log Categories:

#### 4.1 Page Change Logs
```
[Owner View] [Owner Comments] === Page change detected === {url: "/t/topic-name/123"}
[Owner View] [Owner Comments] Running afterRender hook
[Owner View] [Owner Comments] Topic controller resolved {hasController: true, hasTopic: true, topicId: 123}
```

#### 4.2 Guard Evaluation Logs
```
[Owner View] [Owner Comments] Current state {currentFilter: null, hasFilteredNotice: false, bodyMarker: undefined}
[Owner View] [Owner Comments] Category check result {topicCategoryId: 5, isEnabled: true, enabledCategoryIds: [5, 7]}
```

#### 4.3 Navigation Logs
```
[Owner View] [Owner Comments] Navigating to server-filtered URL {url: "...", ownerUsername: "alice"}
```

#### 4.4 Access Control Logs
```
[Owner View] [Group Access Control] Access decision {decision: "GRANTED", isMember: true, allowedGroupIds: [1, 2], userGroupIds: [1, 3]}
```

#### 4.5 Toggle Button Logs
```
[Owner View] [Toggle Button] Toggle button clicked {isOwnerFiltered: false, owner: "alice", topicId: 123}
[Owner View] [Toggle Button] Navigating to owner-filtered view {owner: "alice", url: "..."}
```

### Expected Result:
✅ Logs should:
- Be **clear and readable**
- Include **structured context objects**
- Show **decision points** (guards, conditions)
- Track **state changes**
- Include **relevant data** (topic ID, usernames, URLs)

---

## Test 5: Verify Throttling (Logging Enabled)

**Goal**: Verify high-frequency logs are throttled to prevent console flooding

### Steps:
1. **Enable debug logging**
2. **Navigate to a topic** with many posts
3. **Scroll down** to trigger post loading
4. **Watch console** for MutationObserver logs

### Expected Result:
✅ MutationObserver logs should be **throttled**:
```
[Owner View] [Hide Reply Buttons] New post detected (direct) {node: ...}
// ... (no more logs for 2 seconds)
[Owner View] [Hide Reply Buttons] New post detected (direct) {node: ...}
```

⚠️ **Should NOT see**:
- Dozens of logs per second
- Console flooding
- Browser slowdown

---

## Test 6: Verify Error Logging (Always On)

**Goal**: Verify errors are always logged, even when debug logging is disabled

### Steps:
1. **Disable debug logging**
2. **Trigger an error condition** (e.g., navigate to topic with missing data)
3. **Check console**

### Expected Result:
✅ Errors should **always appear**:
```
[Owner View] [Feature Name] CRITICAL: Could not determine owner post number {error: ...}
```

Even when `debug_logging_enabled = false`

---

## Test 7: Performance Check

**Goal**: Verify no performance degradation when logging is disabled

### Steps:
1. **Disable debug logging**
2. **Open browser DevTools** → Performance tab
3. **Record a page load**
4. **Navigate to a topic**
5. **Stop recording**
6. **Analyze performance**

### Expected Result:
✅ **No significant overhead**:
- Logger checks should be < 1ms total
- No string concatenation when disabled
- No object creation when disabled

### Benchmark:
- **With logging disabled**: < 1ms overhead per page load
- **With logging enabled**: < 10ms overhead per page load

---

## Test 8: Cross-Browser Compatibility

**Goal**: Verify logging works in different browsers

### Browsers to Test:
- [ ] Chrome/Edge (Chromium)
- [ ] Firefox
- [ ] Safari (if available)

### Steps:
1. **Enable debug logging**
2. **Navigate to topic** in each browser
3. **Verify logs appear correctly**

### Expected Result:
✅ Logs should work in all browsers
- No browser-specific errors
- Console methods supported (log, warn, error, group, time)

---

## Test 9: Mobile View

**Goal**: Verify logging works on mobile viewport

### Steps:
1. **Enable debug logging**
2. **Resize browser** to mobile width (< 768px)
3. **Navigate to topic**
4. **Check console**

### Expected Result:
✅ Mobile-specific logs should appear:
```
[Owner View] [Toggle Outlets] Mobile toggle shouldRender {shouldShow: true, hasAccess: true, isMobile: true, result: true}
```

---

## Test 10: Regression Testing

**Goal**: Verify no existing functionality was broken

### Critical Paths to Test:

#### 10.1 Auto-Filter Flow
- [ ] Navigate to configured category → filter applies
- [ ] Click "show all" → filter removes
- [ ] Navigate away and back → filter reapplies
- [ ] Toggle to unfiltered → opt-out flag prevents re-filter

#### 10.2 Embedded Reply Flow
- [ ] Click "show replies" → section expands
- [ ] Reply button appears in embedded section
- [ ] Click reply button → composer opens
- [ ] Submit reply → auto-refresh works
- [ ] New post appears in embedded section

#### 10.3 Toggle Button Flow
- [ ] Button appears in timeline (desktop)
- [ ] Button appears in mobile progress (mobile)
- [ ] Click toggle → navigates correctly
- [ ] State persists across navigation

### Expected Result:
✅ **Zero regressions**
- All features work as before
- No new bugs introduced
- No console errors

---

## Troubleshooting

### Problem: No logs appear when enabled

**Possible Causes**:
1. Setting not saved correctly
2. Page not refreshed after enabling
3. `settings` global variable not available
4. Logger.js not loaded

**Solutions**:
1. Verify setting in Admin panel
2. Hard refresh (Ctrl+Shift+R)
3. Check console for errors
4. Verify theme files deployed correctly

---

### Problem: Logs appear when disabled

**Possible Causes**:
1. Setting not saved correctly
2. Hardcoded DEBUG flag still present
3. Direct console.log calls

**Solutions**:
1. Verify setting is unchecked
2. Search codebase for `DEBUG = true`
3. Search for direct `console.log` calls

---

### Problem: Console flooding

**Possible Causes**:
1. Throttling not working
2. Too many debug logs in tight loops

**Solutions**:
1. Verify `debugThrottled` is used for high-frequency events
2. Move debug logs outside loops
3. Use `groupCollapsed` for verbose sections

---

### Problem: Features broken

**Possible Causes**:
1. Syntax error in updated files
2. Import path incorrect
3. Logger not available

**Solutions**:
1. Check browser console for errors
2. Verify import paths: `import { createLogger } from "../lib/logger"`
3. Verify logger.js is in correct location

---

## Success Criteria

### ✅ All Tests Pass If:

1. **Logging disabled by default** (no console output)
2. **Setting toggle works** (logs appear when enabled)
3. **All features functional** (no regressions)
4. **Logs are helpful** (structured, clear, actionable)
5. **Throttling works** (no console flooding)
6. **Errors always visible** (even when debug disabled)
7. **No performance impact** (< 1ms overhead when disabled)
8. **Cross-browser compatible** (works in Chrome, Firefox, Safari)
9. **Mobile works** (logs appear on mobile viewport)
10. **Zero regressions** (all existing features work)

---

## Next Steps After Testing

### If All Tests Pass ✅
- Proceed to **Phase 5**: Instrument `embedded-reply-buttons.gjs`
- Document any findings
- Create git commit with changes

### If Tests Fail ❌
- Document failures
- Fix issues
- Re-test
- Do not proceed until all tests pass

---

**End of Testing Guide**

