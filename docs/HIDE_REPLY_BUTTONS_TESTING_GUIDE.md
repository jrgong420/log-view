# Hide Reply Buttons for Non-Owners - Testing Guide

## Quick Start Testing

### Prerequisites

1. **Enable the setting**:
   - Admin → Customize → Themes → Log View → Settings
   - Enable "Hide Reply Buttons for Non-Owners"
   - Save

2. **Configure categories**:
   - Set "Owner Comment Categories" to include at least one category
   - Save

3. **Create test topic**:
   - Create a topic in a configured category
   - Have multiple users post replies (or create test posts)

### Visual Testing Steps

#### Test 1: Regular View - Owner Posts

1. Navigate to a topic in a configured category
2. Open browser DevTools (F12) → Console
3. Look for debug logs: `[Hide Reply Buttons]`
4. Find a post by the topic owner
5. **Expected**:
   - Post has class `owner-post`
   - Post has attribute `data-owner-marked="1"`
   - Reply button is visible

**DevTools check**:
```javascript
// Find owner posts
document.querySelectorAll('article.topic-post.owner-post')

// Check specific post
const ownerPost = document.querySelector('article.topic-post.owner-post');
console.log('Has owner-post class:', ownerPost.classList.contains('owner-post'));
console.log('Reply button visible:', !!ownerPost.querySelector('button.reply'));
```

#### Test 2: Regular View - Non-Owner Posts

1. Find a post by someone other than the topic owner
2. **Expected**:
   - Post has class `non-owner-post`
   - Post has attribute `data-owner-marked="1"`
   - Reply button is hidden (not visible in UI)

**DevTools check**:
```javascript
// Find non-owner posts
document.querySelectorAll('article.topic-post.non-owner-post')

// Check specific post
const nonOwnerPost = document.querySelector('article.topic-post.non-owner-post');
console.log('Has non-owner-post class:', nonOwnerPost.classList.contains('non-owner-post'));
console.log('Reply button exists:', !!nonOwnerPost.querySelector('button.reply'));
console.log('Reply button computed display:', 
  window.getComputedStyle(nonOwnerPost.querySelector('button.reply')).display
);
// Should show "none"
```

#### Test 3: Filtered View (if toggle enabled)

1. Click the "Show Owner Only" toggle button
2. Wait for filtered view to load
3. **Expected**:
   - Owner posts still have `owner-post` class
   - Reply buttons still visible on owner posts
   - Non-owner posts (if any visible) still have `non-owner-post` class

**DevTools check**:
```javascript
// Check if in filtered mode
console.log('Filtered mode:', document.body.dataset.ownerCommentMode === 'true');

// Count classified posts
console.log('Owner posts:', document.querySelectorAll('.owner-post').length);
console.log('Non-owner posts:', document.querySelectorAll('.non-owner-post').length);
```

#### Test 4: Load More Posts

1. Scroll to bottom of topic
2. Click "Load More" (if available)
3. **Expected**:
   - New posts are automatically classified
   - Console shows: `[Hide Reply Buttons] New post detected, classifying:`
   - New posts have `owner-post` or `non-owner-post` class

**DevTools check**:
```javascript
// Before clicking "Load More"
const beforeCount = document.querySelectorAll('[data-owner-marked]').length;
console.log('Posts before:', beforeCount);

// Click "Load More", then:
const afterCount = document.querySelectorAll('[data-owner-marked]').length;
console.log('Posts after:', afterCount);
console.log('New posts classified:', afterCount - beforeCount);
```

#### Test 5: Show Replies (Embedded Posts)

1. Find a post with replies
2. Click "Show Replies" button
3. **Expected**:
   - Embedded posts are classified
   - Console shows classification logs
   - Reply buttons hidden on non-owner embedded posts

**DevTools check**:
```javascript
// Find embedded posts section
const embeddedSection = document.querySelector('section.embedded-posts');
console.log('Embedded section found:', !!embeddedSection);

// Check embedded posts classification
const embeddedPosts = embeddedSection?.querySelectorAll('[data-owner-marked]');
console.log('Embedded posts classified:', embeddedPosts?.length || 0);
```

#### Test 6: Unconfigured Category

1. Navigate to a topic in a category NOT in "Owner Comment Categories"
2. **Expected**:
   - No posts are classified
   - No `owner-post` or `non-owner-post` classes
   - All reply buttons remain visible
   - Console shows: `[Hide Reply Buttons] Category not configured; skipping`

**DevTools check**:
```javascript
// Should return 0
console.log('Classified posts:', document.querySelectorAll('[data-owner-marked]').length);
```

#### Test 7: Setting Disabled

1. Disable "Hide Reply Buttons for Non-Owners" in settings
2. Refresh the topic page
3. **Expected**:
   - No posts are classified
   - Console shows: `[Hide Reply Buttons] Setting disabled; skipping`
   - All reply buttons visible

#### Test 8: Navigation (SPA Test)

1. Navigate to a topic in a configured category
2. Wait for classification (check console)
3. Navigate to a different topic (same or different category)
4. **Expected**:
   - Console shows: `[Hide Reply Buttons] Page changed to: ...`
   - Old observer is cleaned up
   - New observer is set up (if in configured category)
   - No duplicate observers

**DevTools check**:
```javascript
// Count how many times observer is set up
// Should only see one "MutationObserver set up" per page load
```

## Common Issues and Solutions

### Issue: Posts not being classified

**Symptoms**:
- No `owner-post` or `non-owner-post` classes
- No `data-owner-marked` attributes

**Check**:
1. Is the setting enabled?
2. Is the topic in a configured category?
3. Check console for errors
4. Check console for: `[Hide Reply Buttons] Setting disabled; skipping`

**Solution**:
```javascript
// Debug in console
console.log('Setting enabled:', settings.hide_reply_buttons_for_non_owners);
console.log('Configured categories:', settings.owner_comment_categories);
console.log('Current topic category:', 
  api.container.lookup('controller:topic')?.model?.category_id
);
```

### Issue: Reply buttons still visible on non-owner posts

**Symptoms**:
- Post has `non-owner-post` class
- Reply button is still visible

**Check**:
1. Inspect the button element
2. Check computed styles

**Solution**:
```javascript
const btn = document.querySelector('.non-owner-post button.reply');
console.log('Button exists:', !!btn);
console.log('Computed display:', window.getComputedStyle(btn).display);
// Should be "none"

// Check if CSS is loaded
console.log('CSS rule exists:', 
  [...document.styleSheets].some(sheet => {
    try {
      return [...sheet.cssRules].some(rule => 
        rule.selectorText?.includes('non-owner-post')
      );
    } catch { return false; }
  })
);
```

### Issue: New posts not classified after "Load More"

**Symptoms**:
- Initial posts are classified
- Posts loaded via "Load More" are not classified

**Check**:
1. Console for observer setup: `[Hide Reply Buttons] MutationObserver set up`
2. Console for new post detection: `[Hide Reply Buttons] New post detected`

**Solution**:
```javascript
// Check if observer is active
console.log('Observer exists:', !!streamObserver);

// Manually trigger classification
const topic = api.container.lookup('controller:topic')?.model;
const topicOwnerId = topic?.details?.created_by?.id;
document.querySelectorAll('article.topic-post:not([data-owner-marked])').forEach(post => {
  classifyPost(post, topic, topicOwnerId);
});
```

### Issue: Multiple observers (memory leak)

**Symptoms**:
- Console shows multiple "MutationObserver set up" messages
- Performance degradation

**Check**:
```javascript
// This should only appear once per page load
// If it appears multiple times, there's a leak
```

**Solution**:
- Check that observer is cleaned up in `api.onPageChange`
- Verify `streamObserver.disconnect()` is called

## Performance Testing

### Test with Long Topic (100+ posts)

1. Navigate to a topic with 100+ posts
2. Monitor console for classification time
3. **Expected**:
   - Initial classification completes quickly (< 1 second)
   - No UI lag or freezing

**DevTools check**:
```javascript
// Measure classification time
console.time('classification');
processVisiblePosts(topic, topicOwnerId);
console.timeEnd('classification');
```

### Test Memory Usage

1. Open DevTools → Performance → Memory
2. Take heap snapshot
3. Navigate between topics multiple times
4. Take another heap snapshot
5. **Expected**:
   - No significant memory growth
   - Observers are properly cleaned up

## Automated Testing

Run the acceptance tests:

```bash
# Run all tests
npm test

# Run specific test
npm test -- --filter="Hide Reply Buttons"
```

**Expected output**:
```
✓ hides reply buttons on non-owner posts in configured category
✓ does not hide buttons in unconfigured category
✓ works in both filtered and regular views
✓ does not classify posts when setting is disabled
```

## Checklist

Use this checklist for comprehensive testing:

- [ ] Setting enabled/disabled works
- [ ] Category filtering works
- [ ] Owner posts show reply buttons
- [ ] Non-owner posts hide reply buttons
- [ ] Works in regular view
- [ ] Works in filtered view
- [ ] "Load More" posts are classified
- [ ] "Show Replies" posts are classified
- [ ] Navigation cleans up observers
- [ ] No memory leaks
- [ ] No console errors
- [ ] Performance is acceptable
- [ ] Automated tests pass

## Debug Mode

To enable verbose logging, ensure `DEBUG = true` in `hide-reply-buttons.gjs`:

```javascript
const DEBUG = true; // Set to false to disable debug logging
```

This will show detailed logs like:
- `[Hide Reply Buttons] Page changed to: ...`
- `[Hide Reply Buttons] Setting enabled; evaluating conditions`
- `[Hide Reply Buttons] Topic found: { id: 123, category_id: 1 }`
- `[Hide Reply Buttons] Processing 20 visible posts`
- `[Hide Reply Buttons] Post #5: author=10, owner=1, isOwner=false`
- `[Hide Reply Buttons] MutationObserver set up for post stream`

## Support

If you encounter issues not covered here:
1. Check `docs/HIDE_REPLY_BUTTONS_EXPANDED.md` for detailed troubleshooting
2. Review browser console for error messages
3. Verify theme component is active and up to date

