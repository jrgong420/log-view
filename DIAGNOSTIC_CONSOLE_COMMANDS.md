# Diagnostic Console Commands

Copy and paste these commands into your browser console (F12) to diagnose why logs are missing.

---

## Command 1: Check Settings Object

```javascript
console.log("=== SETTINGS CHECK ===");
console.log("Settings object exists:", typeof settings !== "undefined");
console.log("Settings object:", settings);
console.log("debug_logging_enabled:", settings?.debug_logging_enabled);
console.log("owner_comment_categories:", settings?.owner_comment_categories);
console.log("Expected: debug_logging_enabled should be true");
```

**What to look for**:
- ✅ `debug_logging_enabled: true` → Setting is enabled correctly
- ❌ `debug_logging_enabled: false` → Go to Admin → Settings and enable it
- ❌ `debug_logging_enabled: undefined` → Setting not in settings.yml (deployment issue)
- ❌ `Settings object exists: false` → Theme not loaded

---

## Command 2: Check Theme is Active

```javascript
console.log("=== THEME CHECK ===");
console.log("Body dataset:", document.body.dataset);
console.log("Owner comment mode:", document.body.dataset.ownerCommentMode);
console.log("Toggle button exists:", !!document.querySelector('.owner-toggle-button'));
console.log("Embedded sections:", document.querySelectorAll('.embedded-posts__wrapper').length);
console.log("Expected: Should see theme-specific elements");
```

**What to look for**:
- ✅ `ownerCommentMode: "true"` → Theme is active and working
- ❌ `ownerCommentMode: undefined` → Theme not active or not in configured category

---

## Command 3: Manual Logger Test

```javascript
console.log("=== MANUAL LOGGER TEST ===");

// Test if logging would work
const testEnabled = typeof settings !== "undefined" && settings.debug_logging_enabled === true;
console.log("Logging should work:", testEnabled);

if (testEnabled) {
  console.log("[MANUAL TEST] ✅ Logging is enabled - logs should appear");
  console.log("[MANUAL TEST] If you don't see theme logs, there's an import/module issue");
} else {
  console.log("[MANUAL TEST] ❌ Logging is DISABLED");
  console.log("[MANUAL TEST] Enable debug_logging_enabled in Admin → Themes → Settings");
}
```

---

## Command 4: Check for Import Errors

```javascript
console.log("=== ERROR CHECK ===");
console.log("Check console above for any errors containing:");
console.log("  - 'Failed to load module'");
console.log("  - 'createLogger is not defined'");
console.log("  - 'Cannot find module'");
console.log("If you see these, there's an import path issue");
```

---

## Command 5: Force Test Log

```javascript
console.log("=== FORCE TEST LOG ===");

// Create a simple logger that always works
const forceLog = {
  debug: (...args) => console.log("[FORCE DEBUG]", ...args),
  info: (...args) => console.log("[FORCE INFO]", ...args)
};

forceLog.debug("This should ALWAYS appear");
forceLog.info("If this appears but theme logs don't, the logger module has an issue");
```

---

## Command 6: Check Current Page Context

```javascript
console.log("=== PAGE CONTEXT ===");
const url = new URL(window.location.href);
console.log("Current URL:", url.href);
console.log("Is topic page:", url.pathname.includes('/t/'));
console.log("Has username_filters:", url.searchParams.has('username_filters'));
console.log("Username filter value:", url.searchParams.get('username_filters'));
console.log("Expected: Should be on a topic page in configured category");
```

---

## All-in-One Diagnostic

Copy and paste this entire block:

```javascript
console.log("╔════════════════════════════════════════════════════════════╗");
console.log("║         THEME COMPONENT DIAGNOSTIC REPORT                  ║");
console.log("╚════════════════════════════════════════════════════════════╝");

// 1. Settings Check
console.log("\n📋 SETTINGS:");
console.log("  Settings object:", typeof settings !== "undefined" ? "✅ EXISTS" : "❌ MISSING");
console.log("  debug_logging_enabled:", settings?.debug_logging_enabled === true ? "✅ ENABLED" : "❌ DISABLED");
console.log("  owner_comment_categories:", settings?.owner_comment_categories || "Not set");

// 2. Theme Active Check
console.log("\n🎨 THEME STATUS:");
console.log("  Owner comment mode:", document.body.dataset.ownerCommentMode === "true" ? "✅ ACTIVE" : "❌ INACTIVE");
console.log("  Toggle button:", document.querySelector('.owner-toggle-button') ? "✅ FOUND" : "❌ NOT FOUND");
console.log("  Embedded sections:", document.querySelectorAll('.embedded-posts__wrapper').length);

// 3. Page Context
console.log("\n📍 PAGE CONTEXT:");
const url = new URL(window.location.href);
console.log("  Current page:", url.pathname);
console.log("  Is topic page:", url.pathname.includes('/t/') ? "✅ YES" : "❌ NO");
console.log("  Has filter:", url.searchParams.has('username_filters') ? "✅ YES" : "❌ NO");

// 4. Logging Test
console.log("\n🔍 LOGGING TEST:");
const shouldLog = typeof settings !== "undefined" && settings.debug_logging_enabled === true;
console.log("  Should logs appear:", shouldLog ? "✅ YES" : "❌ NO");

if (shouldLog) {
  console.log("\n✅ DIAGNOSIS: Logging is enabled!");
  console.log("   If you don't see theme logs, check for:");
  console.log("   1. Import errors in console (red text above)");
  console.log("   2. Module loading failures");
  console.log("   3. Cache issues (try hard refresh: Cmd+Shift+R)");
} else {
  console.log("\n❌ DIAGNOSIS: Logging is disabled!");
  console.log("   TO FIX:");
  console.log("   1. Go to Admin → Customize → Themes");
  console.log("   2. Click on your theme");
  console.log("   3. Click 'Settings' tab");
  console.log("   4. Enable 'debug_logging_enabled'");
  console.log("   5. Click 'Save'");
  console.log("   6. Refresh this page (Cmd+R or Ctrl+R)");
}

console.log("\n╚════════════════════════════════════════════════════════════╝");
```

---

## What to Share

After running the diagnostics, share:

1. **The output of the "All-in-One Diagnostic"** (copy/paste the console output)
2. **Any red errors** in the console
3. **Screenshot** of Admin → Themes → Settings page showing `debug_logging_enabled`

This will help identify the exact issue!

