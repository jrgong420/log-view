# Troubleshooting: Console Logs Missing

## Quick Diagnostics

### Step 1: Verify Setting is Enabled

Open browser console and run:
```javascript
// Check if settings object exists
console.log("Settings object:", typeof settings);

// Check debug_logging_enabled value
console.log("debug_logging_enabled:", settings?.debug_logging_enabled);

// Should output: true
```

**Expected Output**:
```
Settings object: object
debug_logging_enabled: true
```

**If you see**:
- `Settings object: undefined` → Theme not loaded correctly
- `debug_logging_enabled: false` → Setting not enabled in admin UI
- `debug_logging_enabled: undefined` → Setting not defined in settings.yml

---

### Step 2: Verify Logger Module Loads

In browser console:
```javascript
// Check if logger is accessible (won't work directly, but we can check for errors)
// Navigate to a topic and check for import errors in console
```

Look for errors like:
- `Failed to load module` → Import path issue
- `createLogger is not defined` → Export/import mismatch

---

### Step 3: Force a Test Log

Add this temporary code to test logging directly:

**Option A: Test in browser console**
```javascript
// Manually test the logger
const testLog = {
  debug: (...args) => {
    if (settings?.debug_logging_enabled) {
      console.log("[TEST]", ...args);
    }
  }
};

testLog.debug("Test message", { test: true });
// Should output: [TEST] Test message {test: true}
```

**Option B: Add temporary log to a file**

Edit `javascripts/discourse/api-initializers/owner-comment-prototype.gjs` and add at the very top of the initializer:

```javascript
export default apiInitializer("1.15.0", (api) => {
  // TEMPORARY TEST LOG
  console.log("[DIAGNOSTIC] Initializer loaded");
  console.log("[DIAGNOSTIC] Settings object:", typeof settings);
  console.log("[DIAGNOSTIC] debug_logging_enabled:", settings?.debug_logging_enabled);
  
  const log = createLogger("[Owner View] [Owner Comment Prototype]");
  
  // TEMPORARY TEST LOG
  console.log("[DIAGNOSTIC] Logger created:", typeof log);
  log.debug("Test debug log");
  log.info("Test info log");
  console.log("[DIAGNOSTIC] Logs should appear above if enabled");
  
  // ... rest of code
```

---

### Step 4: Check Theme is Active

1. Go to **Admin → Customize → Themes**
2. Verify your theme is **active** (has a checkmark or "Active" badge)
3. If using a component, verify it's **enabled** on the active theme

---

### Step 5: Check Browser Console Filters

1. Open browser console (F12)
2. Check console filter settings:
   - ✅ "Verbose" or "All levels" should be selected
   - ❌ Don't filter by "Errors only" or "Warnings only"
3. Clear any text filters in the console search box
4. Check if logs are hidden by console grouping (expand all groups)

---

### Step 6: Verify Theme Deployed Correctly

Check if the theme files are actually deployed:

**In browser console**:
```javascript
// Check if the theme's CSS is loaded
const themeStyles = Array.from(document.styleSheets).filter(s => 
  s.href?.includes('theme') || s.ownerNode?.dataset?.target === 'theme'
);
console.log("Theme stylesheets:", themeStyles.length);

// Check for theme-specific elements
console.log("Owner toggle button:", document.querySelector('.owner-toggle-button'));
console.log("Owner comment mode:", document.body.dataset.ownerCommentMode);
```

---

## Common Issues & Solutions

### Issue 1: Setting Not Enabled

**Symptom**: `debug_logging_enabled: false` or `undefined`

**Solution**:
1. Go to **Admin → Customize → Themes → [Your Theme] → Settings**
2. Find `debug_logging_enabled`
3. Toggle it **ON** (should show as enabled/checked)
4. Click **Save**
5. **Refresh the page** (important!)

---

### Issue 2: Theme Not Active

**Symptom**: `Settings object: undefined` or theme features don't work

**Solution**:
1. **Admin → Customize → Themes**
2. Find your theme in the list
3. Click **Preview** or **Set as Default**
4. If it's a component, ensure it's added to an active theme

---

### Issue 3: Import Path Wrong

**Symptom**: Console shows `Failed to load module` or `createLogger is not defined`

**Solution**:
Check the import path in each file. Should be:
```javascript
// For files in javascripts/discourse/api-initializers/
import { createLogger } from "../lib/logger";

// For files in javascripts/discourse/components/
import { createLogger } from "../lib/logger";

// For files in javascripts/discourse/lib/
import { createLogger } from "./logger";
```

---

### Issue 4: Cache Issue

**Symptom**: Changes not appearing, old code still running

**Solution**:
1. **Hard refresh**: `Cmd+Shift+R` (Mac) or `Ctrl+Shift+R` (Windows)
2. **Clear cache**: Browser settings → Clear browsing data → Cached files
3. **Disable cache**: DevTools → Network tab → Check "Disable cache"
4. **Restart Discourse**: If using local development

---

### Issue 5: Settings Object Not Available Yet

**Symptom**: Logs work sometimes but not on initial page load

**Solution**:
The `settings` object should be available in api-initializers. If not, check:
```javascript
export default apiInitializer("1.15.0", (api) => {
  // Add defensive check
  if (typeof settings === "undefined") {
    console.error("[Logger] Settings object not available!");
    return;
  }
  
  const log = createLogger("[Prefix]");
  // ... rest of code
});
```

---

## Verification Checklist

Run through this checklist:

- [ ] Theme is deployed and active
- [ ] `debug_logging_enabled` setting exists in settings.yml
- [ ] `debug_logging_enabled` is **enabled** in admin UI
- [ ] Page has been **refreshed** after enabling setting
- [ ] Browser console is open (F12)
- [ ] Console filter is set to "All levels" or "Verbose"
- [ ] No console errors about failed module imports
- [ ] Navigated to a topic in a configured category

---

## Test Commands

Run these in browser console to diagnose:

```javascript
// 1. Check settings
console.log("Settings check:", {
  settingsExists: typeof settings !== "undefined",
  debugEnabled: settings?.debug_logging_enabled,
  categories: settings?.owner_comment_categories
});

// 2. Check if in owner comment mode
console.log("Owner comment mode:", {
  bodyDataset: document.body.dataset.ownerCommentMode,
  isFiltered: window.location.href.includes("username_filters")
});

// 3. Check for theme elements
console.log("Theme elements:", {
  toggleButton: !!document.querySelector('.owner-toggle-button'),
  embeddedSections: document.querySelectorAll('.embedded-posts__wrapper').length,
  ownerPosts: document.querySelectorAll('.owner-post').length
});

// 4. Manual logger test
if (typeof settings !== "undefined" && settings.debug_logging_enabled) {
  console.log("[MANUAL TEST] Logging is enabled!");
} else {
  console.log("[MANUAL TEST] Logging is DISABLED or settings unavailable");
}
```

---

## Expected Console Output

When everything is working, you should see logs like:

```
[Owner View] [Owner Comment Prototype] Checking if owner comment mode should apply
[Owner View] [Owner Comment Prototype] Owner comment mode active {topicId: 123, categoryId: 5}
[Owner View] [Embedded Reply Buttons] AutoRefresh: initializing composer event listeners
[Owner View] [Toggle Button] Component initialized
```

---

## Still Not Working?

If logs are still missing after trying all the above:

1. **Share these diagnostics**:
   - Output of the "Test Commands" above
   - Any console errors (red text)
   - Screenshot of Admin → Themes → Settings page
   - Browser and version

2. **Try the nuclear option**:
   - Remove the theme completely
   - Re-import/re-deploy from scratch
   - Enable `debug_logging_enabled`
   - Hard refresh

3. **Fallback: Add direct console.log**:
   - Temporarily add `console.log("[DIRECT]", "message")` to a file
   - If this works but `log.debug()` doesn't, there's an issue with the logger module
   - If this doesn't work either, theme isn't loading at all

---

## Quick Fix: Bypass Logger Temporarily

If you need logs NOW and can't wait to debug the logger:

**Temporary workaround** (add to any initializer):
```javascript
// TEMPORARY - bypass logger
const log = {
  debug: (...args) => console.log("[DEBUG]", ...args),
  info: (...args) => console.log("[INFO]", ...args),
  warn: (...args) => console.warn("[WARN]", ...args),
  error: (...args) => console.error("[ERROR]", ...args)
};

// Now use log.debug() etc. as normal
log.debug("This will always show");
```

This bypasses the settings check and always logs. Use only for debugging!

