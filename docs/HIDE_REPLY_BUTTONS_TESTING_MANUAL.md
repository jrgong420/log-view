# Manual Testing Guide - Hide Reply Buttons for Non-Owners

## Overview

This guide provides step-by-step instructions for manually testing the "Hide reply buttons for non owners" feature, which now includes both post-level and top-level reply button hiding.

## Prerequisites

1. Discourse instance with the Log View theme component installed
2. At least one category configured for owner comments
3. Test topics with multiple posts from different users
4. Multiple test user accounts (owner and non-owner)

## Setup

### 1. Configure the Theme Component

1. Navigate to **Admin** → **Customize** → **Themes**
2. Select **Log View** theme component
3. Click **Settings**
4. Configure the following:
   - `owner_comment_categories`: Select at least one category (e.g., "Support")
   - `hide_reply_buttons_for_non_owners`: Enable (toggle to ON)
   - `debug_logging_enabled`: Enable (for debugging)
5. Click **Save**

### 2. Prepare Test Data

Create a test topic in the configured category with:
- **Topic owner**: User A (creates the topic)
- **Post 1**: By User A (topic owner)
- **Post 2**: By User B (non-owner)
- **Post 3**: By User A (topic owner)
- **Post 4**: By User C (non-owner)

## Test Scenarios

### Scenario 1: Topic Owner View

**Login as**: User A (topic owner)

**Expected Behavior**:
- ✅ Timeline footer "Reply" button is **visible**
- ✅ Topic footer "Reply" button is **visible**
- ✅ Reply buttons on all posts are **visible** (both owner and non-owner posts)

**Steps**:
1. Navigate to the test topic
2. Scroll through the topic
3. Verify timeline footer (right side on desktop) shows "Reply" button
4. Scroll to bottom of topic
5. Verify topic footer shows "Reply" button
6. Check each post for reply buttons
7. Click a reply button to verify it works

**Browser Console Check**:
```javascript
// Should be false (owner viewing their own topic)
document.body.classList.contains('hide-reply-buttons-non-owners')
// Expected: false

// Check post classification
document.querySelectorAll('article.topic-post.owner-post').length
// Expected: 2 (posts by User A)

document.querySelectorAll('article.topic-post.non-owner-post').length
// Expected: 2 (posts by User B and C)
```

### Scenario 2: Non-Owner View (Logged In)

**Login as**: User B (non-owner)

**Expected Behavior**:
- ❌ Timeline footer "Reply" button is **hidden**
- ❌ Topic footer "Reply" button is **hidden**
- ✅ Reply buttons on owner's posts (User A) are **visible**
- ❌ Reply buttons on non-owner's posts (User B, C) are **hidden**

**Steps**:
1. Navigate to the test topic
2. Verify timeline footer does NOT show "Reply" button
3. Scroll to bottom of topic
4. Verify topic footer does NOT show "Reply" button
5. Check Post 1 (by User A) - should have reply button
6. Check Post 2 (by User B) - should NOT have reply button
7. Check Post 3 (by User A) - should have reply button
8. Check Post 4 (by User C) - should NOT have reply button
9. Try keyboard shortcut Shift+R - should still work (limitation)

**Browser Console Check**:
```javascript
// Should be true (non-owner viewing topic)
document.body.classList.contains('hide-reply-buttons-non-owners')
// Expected: true

// Check post classification
document.querySelectorAll('article.topic-post.owner-post').length
// Expected: 2

document.querySelectorAll('article.topic-post.non-owner-post').length
// Expected: 2

// Verify CSS is hiding buttons
const nonOwnerPost = document.querySelector('article.topic-post.non-owner-post');
const replyButton = nonOwnerPost?.querySelector('nav.post-controls .actions button.reply');
const computedStyle = window.getComputedStyle(replyButton);
console.log('Reply button display:', computedStyle.display);
// Expected: "none"
```

### Scenario 3: Anonymous User View

**Logout** (view as anonymous user)

**Expected Behavior**:
- ❌ Timeline footer "Reply" button is **hidden**
- ❌ Topic footer "Reply" button is **hidden**
- ✅ Reply buttons on owner's posts are **visible** (or show login prompt)
- ❌ Reply buttons on non-owner's posts are **hidden**

**Steps**:
1. Navigate to the test topic (logged out)
2. Verify timeline footer does NOT show "Reply" button
3. Verify topic footer does NOT show "Reply" button
4. Check posts - owner posts may show reply button or login prompt
5. Non-owner posts should not show reply buttons

**Browser Console Check**:
```javascript
// Should be true (anonymous user)
document.body.classList.contains('hide-reply-buttons-non-owners')
// Expected: true
```

### Scenario 4: Unconfigured Category

**Login as**: Any user

**Expected Behavior**:
- ✅ All reply buttons are **visible** (feature disabled in this category)

**Steps**:
1. Navigate to a topic in a category NOT configured in `owner_comment_categories`
2. Verify all reply buttons are visible
3. Verify body class is not present

**Browser Console Check**:
```javascript
document.body.classList.contains('hide-reply-buttons-non-owners')
// Expected: false
```

### Scenario 5: Setting Disabled

**Steps**:
1. Admin → Customize → Themes → Log View → Settings
2. Disable `hide_reply_buttons_for_non_owners`
3. Save

**Expected Behavior**:
- ✅ All reply buttons are **visible** for all users in all categories

**Browser Console Check**:
```javascript
document.body.classList.contains('hide-reply-buttons-non-owners')
// Expected: false
```

### Scenario 6: Filtered View

**Login as**: User B (non-owner)

**Steps**:
1. Navigate to test topic
2. Click "Show Owner Posts Only" toggle button (if enabled)
3. Verify filtered view shows only owner's posts
4. Check reply button visibility

**Expected Behavior**:
- ❌ Timeline footer "Reply" button is **hidden**
- ❌ Topic footer "Reply" button is **hidden**
- ✅ Reply buttons on visible owner posts are **visible**
- Feature works the same in both filtered and regular views

### Scenario 7: Navigation Between Topics

**Login as**: User B (non-owner)

**Steps**:
1. Navigate to test topic (configured category)
2. Verify body class is present
3. Navigate to another topic in unconfigured category
4. Verify body class is removed
5. Navigate back to test topic
6. Verify body class is re-applied

**Expected Behavior**:
- Body class should be added/removed correctly on each navigation
- No flickering or double-application
- MutationObserver should be cleaned up and re-created

**Browser Console Check**:
Look for logs:
```
[Owner View] [Hide Reply Buttons] Page changed
[Owner View] [Hide Reply Buttons] Cleaned up previous observer
[Owner View] [Hide Reply Buttons] Top-level button visibility decision
[Owner View] [Hide Reply Buttons] MutationObserver set up for post stream
```

## Debugging

### Enable Debug Logging

1. Admin → Customize → Themes → Log View → Settings
2. Enable `debug_logging_enabled`
3. Open browser console (F12)
4. Navigate to test topic
5. Look for `[Owner View] [Hide Reply Buttons]` logs

### Common Debug Commands

```javascript
// Get current topic and user info
const topic = Discourse.__container__.lookup("controller:topic")?.model;
const currentUser = Discourse.__container__.lookup("service:current-user");

console.log("Topic ID:", topic?.id);
console.log("Topic owner ID:", topic?.details?.created_by?.id);
console.log("Current user ID:", currentUser?.id);
console.log("Category ID:", topic?.category_id);

// Check body class
console.log("Body class present:", document.body.classList.contains('hide-reply-buttons-non-owners'));

// Check post classification
console.log("Owner posts:", document.querySelectorAll('article.topic-post.owner-post').length);
console.log("Non-owner posts:", document.querySelectorAll('article.topic-post.non-owner-post').length);
console.log("Classified posts:", document.querySelectorAll('article.topic-post[data-owner-marked]').length);

// Check specific post
const post = document.querySelector('article.topic-post');
console.log("Post number:", post?.dataset?.postNumber);
console.log("Post classes:", post?.className);
console.log("Owner marked:", post?.dataset?.ownerMarked);

// Check button visibility
const timelineReply = document.querySelector('.timeline-footer-controls .create');
const topicFooterReply = document.querySelector('.topic-footer-main-buttons .create');
console.log("Timeline reply button:", timelineReply ? "present" : "not found");
console.log("Topic footer reply button:", topicFooterReply ? "present" : "not found");

if (timelineReply) {
  const style = window.getComputedStyle(timelineReply);
  console.log("Timeline reply display:", style.display);
}
```

### Troubleshooting

**Issue**: Top-level buttons not hiding

**Check**:
1. Is body class present? `document.body.classList.contains('hide-reply-buttons-non-owners')`
2. Are you logged in as the topic owner? (Should be visible for owner)
3. Is the topic in a configured category?
4. Check browser console for errors

**Issue**: Post-level buttons not hiding

**Check**:
1. Are posts classified? `document.querySelectorAll('[data-owner-marked]').length`
2. Do posts have correct classes? Check `owner-post` vs `non-owner-post`
3. Check browser console for classification logs
4. Verify MutationObserver is running

**Issue**: Buttons reappear after scrolling

**Check**:
1. Check for MutationObserver cleanup logs
2. Verify no JavaScript errors in console
3. Check if other themes are interfering

## Success Criteria

All scenarios should pass with expected behavior:
- [ ] Scenario 1: Topic Owner View
- [ ] Scenario 2: Non-Owner View (Logged In)
- [ ] Scenario 3: Anonymous User View
- [ ] Scenario 4: Unconfigured Category
- [ ] Scenario 5: Setting Disabled
- [ ] Scenario 6: Filtered View
- [ ] Scenario 7: Navigation Between Topics

## Reporting Issues

If any scenario fails, collect the following information:

1. **Scenario number and description**
2. **Expected vs actual behavior**
3. **Browser console logs** (with debug logging enabled)
4. **Browser and version**
5. **Discourse version**
6. **Theme component version/commit**
7. **Screenshots** (if applicable)

## Notes

- This is a UI-only feature and does not prevent replies via keyboard shortcuts or API
- The feature is independent of the "Allowed groups" setting
- Post classification happens asynchronously and may take a moment after page load
- MutationObserver ensures newly loaded posts (e.g., "load more") are classified

