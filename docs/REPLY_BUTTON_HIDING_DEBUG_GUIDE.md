# Reply Button Hiding - Debug Guide

## Purpose

This guide helps diagnose why reply buttons might still be visible when `hide_reply_buttons_for_non_owners` is enabled.

## How It Works

The reply button hiding feature is **completely independent** of group access control:

1. ✅ **Does NOT check** `allowed_groups` setting
2. ✅ **Does NOT check** user group membership
3. ✅ **Only checks**:
   - Is `hide_reply_buttons_for_non_owners` enabled?
   - Is topic in a configured `owner_comment_categories`?
   - Is viewer the topic owner?

## Expected Behavior

### When Enabled
- **Topic Owner**: Sees ALL reply buttons (timeline, topic footer, post-level, embedded)
- **Non-Owner (logged in)**:
  - ❌ Does NOT see: Timeline footer buttons, topic footer buttons, post-level buttons on non-owner posts
  - ✅ DOES see: **Embedded reply buttons** (in embedded posts sections) - these allow non-owners to reply to owner posts
- **Anonymous**:
  - ❌ Does NOT see: Timeline footer buttons, topic footer buttons, post-level buttons
  - ✅ DOES see: **Embedded reply buttons** (in embedded posts sections)

### When Disabled
- **Everyone**: Sees all reply buttons (normal Discourse behavior)

## Debugging Steps

### Step 1: Enable Debug Logging

1. Go to **Admin → Customize → Themes → Your Theme → Settings**
2. Enable **"Debug logging enabled"**
3. Save and refresh the page

### Step 2: Check Console Logs

Open browser console (F12) and look for these logs:

#### ✅ Good Logs (Feature Working)
```javascript
[Owner View] [Hide Reply Buttons] Hide reply buttons feature enabled; evaluating conditions
[Owner View] [Hide Reply Buttons] Category is configured; proceeding with post classification
[Owner View] [Hide Reply Buttons] User is not topic owner - hiding top-level reply buttons
[Owner View] [Hide Reply Buttons] Reply buttons in DOM after body class added {
  timelineCreate: 1,
  topicFooterCreate: 1,
  embeddedReply: 2,
  ...
}
[Owner View] [Hide Reply Buttons] All reply-related buttons found {
  count: 4,
  buttons: [
    { classes: "btn-primary create", visible: false },  // ← Should be false!
    ...
  ]
}
```

#### ❌ Bad Logs (Feature Not Working)
```javascript
// If you see this, the setting is disabled:
[Owner View] [Hide Reply Buttons] Setting disabled; removing body class and skipping

// If you see this, category is not configured:
[Owner View] [Hide Reply Buttons] Category not configured; removing body class and skipping

// If you see this, user IS the topic owner:
[Owner View] [Hide Reply Buttons] User is topic owner - showing top-level reply buttons
```

### Step 3: Check Body Class

In browser console, run:
```javascript
document.body.classList.contains("hide-reply-buttons-non-owners")
```

**Expected**:
- `true` if viewer is NOT the topic owner
- `false` if viewer IS the topic owner

### Step 4: Check Button Visibility

In browser console, run:
```javascript
// Check if buttons exist
const buttons = document.querySelectorAll("button.create, button.reply-to-post, .embedded-reply-button");
console.log("Total buttons:", buttons.length);

// Check if they're hidden
buttons.forEach((btn, i) => {
  const style = window.getComputedStyle(btn);
  console.log(`Button ${i}:`, {
    classes: btn.className,
    display: style.display,
    visibility: style.visibility,
    hidden: style.display === "none"
  });
});
```

**Expected**: All buttons should have `display: "none"` when viewer is not the topic owner.

### Step 5: Check CSS Specificity

If buttons are still visible, there might be a CSS specificity issue. Run:

```javascript
// Find visible reply buttons
const visibleButtons = Array.from(document.querySelectorAll("button.create, button.reply-to-post, .embedded-reply-button"))
  .filter(btn => window.getComputedStyle(btn).display !== "none");

console.log("Visible buttons:", visibleButtons.length);
visibleButtons.forEach(btn => {
  console.log({
    element: btn,
    classes: btn.className,
    parent: btn.parentElement?.className,
    grandparent: btn.parentElement?.parentElement?.className,
    computedDisplay: window.getComputedStyle(btn).display
  });
});
```

This will show which buttons are still visible and their DOM hierarchy.

## Common Issues

### Issue 1: Buttons Still Visible Despite Body Class

**Symptom**: `body.hide-reply-buttons-non-owners` class is present, but buttons are visible.

**Cause**: CSS selectors don't match the actual button structure in your Discourse version.

**Solution**: Check the button hierarchy and add missing selectors to `common/common.scss`:

```scss
body.hide-reply-buttons-non-owners {
  /* Add the specific selector for your visible buttons */
  .your-button-container button.create {
    display: none !important;
  }
}
```

### Issue 2: Body Class Not Being Added

**Symptom**: `body.hide-reply-buttons-non-owners` class is missing.

**Possible Causes**:
1. Setting is disabled
2. Category is not configured
3. Viewer IS the topic owner
4. JavaScript error preventing execution

**Solution**: Check console logs for the exact reason.

### Issue 3: Feature Works on Some Pages, Not Others

**Symptom**: Reply buttons are hidden on some topics but not others.

**Cause**: Only topics in configured `owner_comment_categories` have reply buttons hidden.

**Solution**: Add the category ID to `owner_comment_categories` setting.

### Issue 4: Embedded Reply Buttons Still Visible

**Symptom**: Timeline/footer buttons are hidden, but embedded reply buttons (in embedded posts sections) are visible.

**Cause**: CSS selector for `.embedded-reply-button` might not be matching.

**Solution**: Check if embedded buttons have a different class name in your Discourse version.

## Manual CSS Override (Temporary Fix)

If you need an immediate fix while debugging, add this to your theme's CSS:

```scss
/* TEMPORARY: Force hide all reply buttons for non-owners */
body.hide-reply-buttons-non-owners {
  button.create,
  button.reply-to-post,
  button.reply,
  .embedded-reply-button {
    display: none !important;
  }
}
```

⚠️ **Warning**: This is very broad and might hide buttons you want to keep. Use only for testing.

## Verification Checklist

After making changes, verify:

- [ ] Setting `hide_reply_buttons_for_non_owners` is enabled
- [ ] Category is in `owner_comment_categories` list
- [ ] Viewer is NOT the topic owner
- [ ] Body class `hide-reply-buttons-non-owners` is present
- [ ] Console shows "User is not topic owner - hiding top-level reply buttons"
- [ ] Console shows button visibility debug info
- [ ] All reply buttons have `display: none` in computed styles
- [ ] Buttons are actually invisible on the page

## Getting Help

If buttons are still visible after following this guide:

1. Enable debug logging
2. Copy all `[Owner View] [Hide Reply Buttons]` logs from console
3. Run the button visibility check script (Step 4)
4. Take a screenshot showing:
   - The visible reply buttons
   - Browser console with logs
   - Browser DevTools showing the button's computed styles
5. Share this information for further diagnosis

## Related Files

- `javascripts/discourse/api-initializers/hide-reply-buttons.gjs` - Main logic
- `common/common.scss` - CSS rules for hiding buttons
- `settings.yml` - Setting definitions
- `docs/HIDE_REPLY_BUTTONS_IMPLEMENTATION.md` - Implementation details

