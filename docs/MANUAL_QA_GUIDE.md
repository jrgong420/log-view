# Manual QA Guide: Category Scoping Fix

## Prerequisites

1. Enable debug logging: Set `debug_logging_enabled` to `true` in theme settings
2. Open browser DevTools console to monitor log output
3. Have at least two categories:
   - Category A: Listed in `owner_comment_categories` (e.g., category ID 1)
   - Category B: NOT listed in `owner_comment_categories` (e.g., category ID 2)
4. Have test topics in both categories
5. Have at least two user accounts:
   - User 1: Topic owner
   - User 2: Non-owner

## Test Scenarios

### Scenario 1: Configured Category + Owner Viewer

**Setup:**
- Setting `hide_reply_buttons_for_non_owners`: `true`
- Setting `owner_comment_categories`: `1` (or your test category)
- Navigate to a topic in category 1
- Log in as the topic owner

**Expected Results:**
- [ ] Console shows: `"Added owner-comments-enabled body class for category scoping"`
- [ ] Console shows: `"User is topic owner - showing top-level reply buttons"`
- [ ] Body element has class `owner-comments-enabled`
- [ ] Body element does NOT have class `hide-reply-buttons-non-owners`
- [ ] Reply buttons have custom styling (primary button colors - blue/purple depending on theme)
- [ ] All reply buttons are visible (post-level and top-level)

**Browser Console Check:**
```javascript
// Run in console
console.log('owner-comments-enabled:', document.body.classList.contains('owner-comments-enabled'));
console.log('hide-reply-buttons-non-owners:', document.body.classList.contains('hide-reply-buttons-non-owners'));
```

Expected output:
```
owner-comments-enabled: true
hide-reply-buttons-non-owners: false
```

---

### Scenario 2: Configured Category + Non-Owner Viewer

**Setup:**
- Setting `hide_reply_buttons_for_non_owners`: `true`
- Setting `owner_comment_categories`: `1`
- Navigate to a topic in category 1
- Log in as a different user (NOT the topic owner)

**Expected Results:**
- [ ] Console shows: `"Added owner-comments-enabled body class for category scoping"`
- [ ] Console shows: `"User is not topic owner - hiding top-level reply buttons"`
- [ ] Body element has class `owner-comments-enabled`
- [ ] Body element has class `hide-reply-buttons-non-owners`
- [ ] Reply buttons have custom styling (primary button colors)
- [ ] Post-level reply buttons on non-owner posts are hidden
- [ ] Top-level reply buttons (timeline footer, topic footer) are hidden
- [ ] **Embedded reply buttons (in embedded posts sections) remain VISIBLE** - these allow non-owners to reply to owner posts

**Browser Console Check:**
```javascript
console.log('owner-comments-enabled:', document.body.classList.contains('owner-comments-enabled'));
console.log('hide-reply-buttons-non-owners:', document.body.classList.contains('hide-reply-buttons-non-owners'));
```

Expected output:
```
owner-comments-enabled: true
hide-reply-buttons-non-owners: true
```

---

### Scenario 3: Non-Configured Category + Any Viewer

**Setup:**
- Setting `hide_reply_buttons_for_non_owners`: `true`
- Setting `owner_comment_categories`: `1`
- Navigate to a topic in category 2 (NOT in the configured list)
- Log in as any user

**Expected Results:**
- [ ] Console shows: `"Category not configured; removing body classes and skipping"`
- [ ] Body element does NOT have class `owner-comments-enabled`
- [ ] Body element does NOT have class `hide-reply-buttons-non-owners`
- [ ] Reply buttons have DEFAULT Discourse styling (not custom primary colors)
- [ ] All reply buttons are visible (normal Discourse behavior)
- [ ] Posts are NOT classified (no `owner-post` or `non-owner-post` classes)

**Browser Console Check:**
```javascript
console.log('owner-comments-enabled:', document.body.classList.contains('owner-comments-enabled'));
console.log('hide-reply-buttons-non-owners:', document.body.classList.contains('hide-reply-buttons-non-owners'));
console.log('Classified posts:', document.querySelectorAll('[data-owner-marked]').length);
```

Expected output:
```
owner-comments-enabled: false
hide-reply-buttons-non-owners: false
Classified posts: 0
```

---

### Scenario 4: Setting Disabled + Any Category

**Setup:**
- Setting `hide_reply_buttons_for_non_owners`: `false`
- Setting `owner_comment_categories`: `1`
- Navigate to any topic (any category)
- Log in as any user

**Expected Results:**
- [ ] Console shows: `"Setting disabled; removing body classes and skipping"`
- [ ] Body element does NOT have class `owner-comments-enabled`
- [ ] Body element does NOT have class `hide-reply-buttons-non-owners`
- [ ] Reply buttons have DEFAULT Discourse styling
- [ ] All reply buttons are visible
- [ ] Posts are NOT classified

**Browser Console Check:**
```javascript
console.log('owner-comments-enabled:', document.body.classList.contains('owner-comments-enabled'));
console.log('hide-reply-buttons-non-owners:', document.body.classList.contains('hide-reply-buttons-non-owners'));
```

Expected output:
```
owner-comments-enabled: false
hide-reply-buttons-non-owners: false
```

---

## Visual Styling Verification

### How to Identify Custom Styling

**Custom styling (should only appear in configured categories):**
- Reply button (`button.post-action-menu__reply`):
  - Background: Primary button color (usually blue/purple)
  - Text: White or light color
  - Prominent, stands out from other buttons
  
- Show Replies button (`button.post-action-menu__show-replies`):
  - Background: Light gray (`var(--primary-100)`)
  - Text: Dark (`var(--primary-900)`)
  - Consistent appearance in collapsed state

**Default styling (should appear in non-configured categories):**
- Reply button:
  - More subtle appearance
  - May have gray or transparent background
  - Less prominent
  
- Show Replies button:
  - Default Discourse button styling
  - May vary between collapsed/expanded states

### Quick Visual Test

1. Open two browser tabs side-by-side
2. Tab 1: Topic in configured category
3. Tab 2: Topic in non-configured category
4. Compare the reply button styling - they should look different

---

## Troubleshooting

### Issue: Classes not being added/removed

**Check:**
1. Refresh the page (hard refresh: Cmd+Shift+R / Ctrl+Shift+R)
2. Verify theme is enabled and active
3. Check console for JavaScript errors
4. Verify `debug_logging_enabled` is true to see detailed logs

### Issue: Styling not applying in configured category

**Check:**
1. Verify `owner-comments-enabled` class is present on body
2. Check browser DevTools → Elements → Inspect reply button
3. Look at "Computed" styles to see if custom styles are applied
4. Check for CSS conflicts or higher specificity rules

### Issue: Styling applying in non-configured category

**Check:**
1. Verify `owner-comments-enabled` class is NOT present on body
2. Clear browser cache
3. Check if category ID is correctly excluded from `owner_comment_categories`
4. Verify you're looking at the right category (check URL or breadcrumbs)

---

## Success Criteria

All scenarios pass with expected results:
- ✅ Configured category: Custom styling applied
- ✅ Non-configured category: Default styling (no custom styling)
- ✅ Setting disabled: Default styling everywhere
- ✅ Owner vs non-owner: Correct hiding behavior in configured categories
- ✅ No JavaScript errors in console
- ✅ Smooth transitions between categories (classes update correctly)

