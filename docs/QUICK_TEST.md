# Quick Test: 5-Minute Verification

**Purpose**: Quickly verify the logging system works before full testing.

---

## Step 1: Deploy the Theme (1 minute)

### Option A: Local Development
If you're running Discourse locally:
```bash
# From the theme directory
cd /Users/reen/Documents/augment-projects/journal-view/log-view

# If using discourse_theme CLI
discourse_theme watch .
```

### Option B: Remote Discourse
If using a remote Discourse instance:
1. Zip the theme files
2. Upload via Admin → Customize → Themes → Import
3. Or use Git sync if configured

---

## Step 2: Verify No Errors (30 seconds)

1. **Open your Discourse site**
2. **Open browser console** (F12)
3. **Navigate to any topic**
4. **Check for errors**

### ✅ Expected:
- No JavaScript errors
- No red error messages
- Page loads normally

### ❌ If you see errors:
```
Uncaught SyntaxError: ...
Uncaught ReferenceError: ...
```
**STOP**: There's a syntax error. Check the console for the file name and line number.

---

## Step 3: Test Logging Disabled (1 minute)

**Default state**: `debug_logging_enabled = false`

1. **Clear console** (click trash icon or Ctrl+L)
2. **Navigate to a topic** in a configured category
3. **Observe console**

### ✅ Expected:
- **Console is clean** (no debug logs)
- Only standard Discourse logs (if any)
- No `[Owner View]` prefixed logs

### ❌ If you see logs:
```
[Owner View] [Feature Name] ...
```
**PROBLEM**: Logging is not properly gated. Check `settings.yml` default value.

---

## Step 4: Enable Logging (1 minute)

1. **Go to Admin Panel**:
   - Click your avatar → Admin
   - Navigate to: Customize → Themes
   - Find "Owner Comments" theme
   - Click "Settings" (gear icon)

2. **Find the setting**:
   - Scroll to find: `debug_logging_enabled`
   - **Check the box** to enable it
   - Click **"Save"**

3. **Refresh the page** (important!)

---

## Step 5: Test Logging Enabled (1 minute)

1. **Clear console**
2. **Navigate to a topic** in a configured category
3. **Observe console**

### ✅ Expected:
You should see logs like this:

```javascript
[Owner View] [Owner Comments] === Page change detected === {url: "/t/topic-name/123"}
[Owner View] [Owner Comments] Running afterRender hook
[Owner View] [Owner Comments] Topic controller resolved {hasController: true, hasTopic: true, topicId: 123}
[Owner View] [Owner Comments] Current state {currentFilter: null, hasFilteredNotice: false, ...}
[Owner View] [Group Access Control] Access decision {decision: "GRANTED", ...}
```

### ❌ If you don't see logs:
**PROBLEM**: Logger not working. Possible causes:
1. Page not refreshed after enabling setting
2. `settings` global variable not available
3. Logger.js not loaded

**Try**:
- Hard refresh (Ctrl+Shift+R or Cmd+Shift+R)
- Check console for errors
- Verify theme is active

---

## Step 6: Test Feature Functionality (1 minute)

**With logging still enabled**, test one critical feature:

### Test Auto-Filter:
1. Navigate to a topic in a configured category
2. **Check URL**: Should have `?username_filters=<owner>`
3. **Check posts**: Should only show owner's posts
4. **Check console**: Should see navigation logs

### ✅ Expected:
- Feature works correctly
- Logs show the flow:
  ```
  [Owner View] [Owner Comments] Category is enabled; ensuring server-side filter
  [Owner View] [Owner Comments] Navigating to server-filtered URL {url: "...", ownerUsername: "alice"}
  ```

### ❌ If feature broken:
**PROBLEM**: Regression introduced. Check console for errors.

---

## Step 7: Disable Logging Again (30 seconds)

1. **Go back to Admin → Settings**
2. **Uncheck** `debug_logging_enabled`
3. **Save**
4. **Refresh page**
5. **Navigate to topic**
6. **Verify console is clean** (no debug logs)

### ✅ Expected:
- No debug logs
- Feature still works

---

## Quick Test Results

### ✅ PASS - All Good!
If all steps passed:
- Logging system works correctly
- No regressions introduced
- Ready for full testing or Phase 5

**Next**: Proceed to full testing (see `TESTING_GUIDE.md`) or continue to Phase 5.

---

### ❌ FAIL - Issues Found
If any step failed, document the issue:

**Issue Template**:
```
Step: [number]
Problem: [description]
Console Error: [copy error message]
Expected: [what should happen]
Actual: [what actually happened]
```

**Next**: Fix the issue before proceeding.

---

## Common Issues & Quick Fixes

### Issue: "settings is not defined"
**Cause**: Global `settings` object not available  
**Fix**: Verify theme is active and page is refreshed

### Issue: "createLogger is not a function"
**Cause**: Logger.js not loaded or import path wrong  
**Fix**: Check import path: `import { createLogger } from "../lib/logger"`

### Issue: Logs appear when disabled
**Cause**: Setting not saved or hardcoded DEBUG flag  
**Fix**: Verify setting is unchecked and saved

### Issue: Feature broken
**Cause**: Syntax error or logic error in updated files  
**Fix**: Check console for errors, review recent changes

---

## Time Estimate

- **Total time**: ~5 minutes
- **If all passes**: Proceed immediately
- **If issues found**: 10-30 minutes to debug

---

**End of Quick Test**

