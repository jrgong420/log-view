# Debugging Global Styling Issue

## Problem Description

Post-level reply button styling (primary action colors) is being applied to ALL topics across the entire Discourse instance, regardless of category configuration.

**Expected behavior:**
- Post-level reply button styling should ONLY apply in topics within "Owner comment categories"
- Topics in other categories should have normal, unmodified styling

## Root Cause Analysis

The CSS is correctly scoped under `body.hide-reply-buttons-non-owners`, so if styling is applying globally, one of these must be true:

1. **Body class is being added globally** (JavaScript bug)
2. **CSS caching issue** (browser or Discourse cache)
3. **CSS compilation issue** (SCSS not compiling correctly)

## Diagnostic Steps

### Step 1: Check Body Class Presence

Open browser console and run this on different topics:

```javascript
// Check if body class is present
console.log("Body class present:", document.body.classList.contains("hide-reply-buttons-non-owners"));

// List all body classes
console.log("All body classes:", Array.from(document.body.classList));
```

**Expected results:**
- ✅ **In configured category, non-owner**: `true`
- ✅ **In configured category, owner**: `false`
- ✅ **In non-configured category**: `false`
- ✅ **On non-topic pages** (category list, user profile): `false`

If body class is present on non-configured topics, the JavaScript has a bug.

### Step 2: Check Debug Logs

With `DEBUG = true` in `hide-reply-buttons.gjs`, check console for:

```
[Hide Reply Buttons] Page changed to: /t/topic-slug/123
[Hide Reply Buttons] Body class before evaluation: false
[Hide Reply Buttons] Setting enabled; evaluating conditions
[Hide Reply Buttons] Topic found: {id: 123, category_id: 5}
[Hide Reply Buttons] Category check: {topicCategory: 5, enabledCategories: [3, 7]}
[Hide Reply Buttons] Category not configured; removing body class
```

**What to verify:**
1. `enabledCategories` matches your "Owner comment categories" setting
2. `topicCategory` is correctly identified
3. Body class is removed when category doesn't match
4. Body class is removed when user is owner

### Step 3: Inspect Compiled CSS

In browser DevTools:

1. Inspect a post-level reply button
2. Check computed styles
3. Look for the source of `background-color: var(--tertiary)`

**If the styling is applying:**
- Check if the CSS rule shows `body.hide-reply-buttons-non-owners` in the selector
- If yes: body class is incorrectly present
- If no: CSS compilation issue (shouldn't happen with our current code)

### Step 4: Check for CSS Caching

1. Hard refresh the page (Cmd+Shift+R / Ctrl+Shift+R)
2. Clear Discourse theme cache:
   - Admin → Customize → Themes → Your Theme → "Clear Cache"
3. Rebuild theme assets:
   - Admin → Customize → Themes → Your Theme → "Rebuild"

### Step 5: Verify Setting Configuration

Check theme settings:

```javascript
// In browser console
console.log("Setting enabled:", settings.hide_reply_buttons_for_non_owners);
console.log("Owner comment categories:", settings.owner_comment_categories);
```

**Verify:**
- Setting is actually enabled (should be `true`)
- Categories are correctly configured (pipe-separated IDs)

## Enhanced Debug Logging

The updated `hide-reply-buttons.gjs` now logs:

```
[Hide Reply Buttons] Page changed to: <url>
[Hide Reply Buttons] Body class before evaluation: <true/false>
[Hide Reply Buttons] Setting enabled; evaluating conditions
[Hide Reply Buttons] Topic found: {id: X, category_id: Y}
[Hide Reply Buttons] Category check: {topicCategory: Y, enabledCategories: [A, B, C]}
[Hide Reply Buttons] Category not configured; removing body class
[Hide Reply Buttons] Body class after evaluation: <true/false>
```

Or for non-owners in configured categories:

```
[Hide Reply Buttons] Ownership decision: {isOwner: false, action: "HIDE buttons (add class)"}
[Hide Reply Buttons] Body class added (non-owner)
[Hide Reply Buttons] Body class after evaluation: true
```

## Common Issues and Solutions

### Issue 1: Body Class Persists Across Navigation

**Symptom:** Body class added in one topic stays when navigating to another

**Cause:** `api.onPageChange()` not firing or early return not removing class

**Solution:** Verify all early returns call `document.body.classList.remove()`

### Issue 2: Category ID Mismatch

**Symptom:** Body class not added in configured categories

**Cause:** Category IDs in setting don't match actual category IDs

**Solution:** 
1. Check category ID in topic URL or API
2. Verify setting uses correct IDs (not slugs)
3. Check debug logs for `enabledCategories` vs `topicCategory`

### Issue 3: CSS Specificity Override

**Symptom:** Styling applies even without body class

**Cause:** CSS selectors too broad or `!important` causing issues

**Solution:** This should NOT happen with current code - all rules are inside `body.hide-reply-buttons-non-owners { }`

### Issue 4: Browser Cache

**Symptom:** Old CSS still loading

**Cause:** Browser or Discourse caching old theme assets

**Solution:**
1. Hard refresh (Cmd+Shift+R)
2. Clear Discourse theme cache
3. Rebuild theme
4. Try incognito/private window

## Testing Checklist

After fixes, verify:

- [ ] Navigate to topic in **non-configured category**
  - [ ] Body class is NOT present
  - [ ] Post-level buttons have normal styling
  - [ ] Console shows "Category not configured; removing body class"

- [ ] Navigate to topic in **configured category as owner**
  - [ ] Body class is NOT present
  - [ ] Post-level buttons have normal styling
  - [ ] Console shows "Body class removed (owner)"

- [ ] Navigate to topic in **configured category as non-owner**
  - [ ] Body class IS present
  - [ ] Post-level buttons have primary styling
  - [ ] Console shows "Body class added (non-owner)"

- [ ] Navigate between different topics
  - [ ] Body class updates correctly on each navigation
  - [ ] No stale body class from previous topic

- [ ] Navigate to non-topic pages (category list, user profile)
  - [ ] Body class is NOT present
  - [ ] Console shows "No topic found; removing body class"

## CSS Structure Verification

The CSS should compile to:

```css
body.hide-reply-buttons-non-owners .timeline-footer-controls .create { display: none !important; }
body.hide-reply-buttons-non-owners nav.post-controls .actions button.create { background-color: var(--tertiary) !important; }
/* etc. */
```

**NOT:**
```css
/* This would be wrong - no body class scoping */
nav.post-controls .actions button.create { background-color: var(--tertiary) !important; }
```

## Next Steps

1. Run diagnostic steps above
2. Share console logs showing the issue
3. Verify body class presence on affected topics
4. Check if hard refresh + cache clear resolves it
5. If issue persists, we may need to add additional guards or change approach

## Alternative Approaches (If Issue Persists)

If the body class approach isn't working reliably:

### Option A: Add data attribute to topic container
Instead of body class, add data attribute to topic container:
```javascript
const topicContainer = document.querySelector(".topic-body");
if (topicContainer) {
  topicContainer.dataset.hideReplyButtons = "true";
}
```

### Option B: Use more specific CSS targeting
Target only within specific topic container:
```scss
.topic-body[data-topic-id="123"] nav.post-controls .actions button.create { }
```

### Option C: Inject inline styles
Directly manipulate button styles via JavaScript (less maintainable)

## Contact

If you've completed all diagnostic steps and the issue persists, please provide:
1. Console logs from affected topics
2. Body class status on different pages
3. Theme setting values
4. Discourse version

