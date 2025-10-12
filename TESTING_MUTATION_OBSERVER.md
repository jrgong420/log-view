# Testing Guide: MutationObserver Implementation

## Overview

This guide helps you test the updated embedded reply buttons feature that now uses **MutationObserver** to detect when embedded posts are expanded by the user.

## What Changed

### Previous Implementation (Broken)
- ❌ Checked for embedded posts on page load using `api.onPageChange()`
- ❌ Embedded posts didn't exist yet at that time
- ❌ Console showed: `Found 0 embedded post sections`

### New Implementation (Fixed)
- ✅ Listens for clicks on "show replies" buttons
- ✅ Sets up MutationObserver when user clicks to expand
- ✅ Detects when `section.embedded-posts` is inserted into DOM
- ✅ Injects reply buttons immediately when embedded posts appear
- ✅ Keeps `api.onPageChange()` as fallback for already-expanded sections

## Quick Test (5 minutes)

### Prerequisites
1. Navigate to a topic in **owner comment mode** (filtered view)
   - URL should have `?username_filters=<owner_username>`
   - Body should have `data-owner-comment-mode="true"`

### Test Steps

#### 1. Initial Page Load
**Action**: Load a topic page in filtered view

**Expected Console Output**:
```
[Embedded Reply Buttons] Initializer starting...
[Embedded Reply Buttons] Binding global click handler for reply buttons...
[Embedded Reply Buttons] Global click handler for reply buttons bound successfully
[Embedded Reply Buttons] Binding delegated click handler for show-replies buttons...
[Embedded Reply Buttons] Delegated click handler for show-replies bound successfully
[Embedded Reply Buttons] Page change detected: { url: "...", title: "..." }
[Embedded Reply Buttons] Cleaning up 0 active observers
[Embedded Reply Buttons] Observers cleaned up
[Embedded Reply Buttons] afterRender: Checking for embedded posts...
[Embedded Reply Buttons] Owner comment mode: true
[Embedded Reply Buttons] Found 0 already-expanded embedded post sections
[Embedded Reply Buttons] No embedded sections found on initial load (will be detected on user click)
[Embedded Reply Buttons] Initializer setup complete
```

**Verify**:
- ✅ No errors in console
- ✅ Message confirms "will be detected on user click"

#### 2. Click "Show Replies" Button
**Action**: Click the "x replies to post" button on a post

**Expected Console Output**:
```
[Embedded Reply Buttons] Show replies / Load more button clicked: <button>
[Embedded Reply Buttons] Processing click for post <post-id>
[Embedded Reply Buttons] Embedded section not yet present, setting up observer for post <post-id>
[Embedded Reply Buttons] Setting up MutationObserver for post <post-id>
[Embedded Reply Buttons] Observer started for post <post-id>
[Embedded Reply Buttons] Mutations detected in post <post-id>: X mutations
[Embedded Reply Buttons] Embedded posts section detected in post <post-id>
[Embedded Reply Buttons] Injecting buttons into container: <section>
[Embedded Reply Buttons] Found X embedded post items
[Embedded Reply Buttons] Item 1: Injecting reply button...
[Embedded Reply Buttons] Item 1: Appending to post-actions (or post-info)
[Embedded Reply Buttons] Item 1: Button injected successfully
...
[Embedded Reply Buttons] Injection complete: X injected, 0 skipped
```

**Verify**:
- ✅ MutationObserver is set up
- ✅ Embedded posts section is detected
- ✅ Reply buttons are injected
- ✅ Buttons appear in the UI

#### 3. Click Reply Button
**Action**: Click a "Reply" button on an embedded post

**Expected Console Output**:
```
[Embedded Reply Buttons] Reply button clicked: <button>
[Embedded Reply Buttons] Topic model: <topic>
[Embedded Reply Buttons] Composer service: <service>
[Embedded Reply Buttons] Parent post number: X
[Embedded Reply Buttons] Parent post model: <post>
[Embedded Reply Buttons] Draft key: ...
[Embedded Reply Buttons] Draft sequence: ...
[Embedded Reply Buttons] Opening composer with options: { ... }
[Embedded Reply Buttons] Composer opened successfully
```

**Verify**:
- ✅ Composer opens
- ✅ Reply context is set to parent post
- ✅ Filtered view is maintained

#### 4. Navigate Away and Back
**Action**: Navigate to another page, then back to the topic

**Expected Console Output**:
```
[Embedded Reply Buttons] Page change detected: { url: "...", title: "..." }
[Embedded Reply Buttons] Cleaning up 1 active observers
[Embedded Reply Buttons] Observers cleaned up
[Embedded Reply Buttons] afterRender: Checking for embedded posts...
[Embedded Reply Buttons] Owner comment mode: true
[Embedded Reply Buttons] Found 0 already-expanded embedded post sections
[Embedded Reply Buttons] No embedded sections found on initial load (will be detected on user click)
```

**Verify**:
- ✅ Old observers are cleaned up
- ✅ No memory leaks
- ✅ Feature works again after re-expanding

#### 5. Already-Expanded Section (Fallback)
**Action**: If embedded posts are already expanded when page loads (rare case)

**Expected Console Output**:
```
[Embedded Reply Buttons] Page change detected: { url: "...", title: "..." }
[Embedded Reply Buttons] Cleaning up 0 active observers
[Embedded Reply Buttons] Observers cleaned up
[Embedded Reply Buttons] afterRender: Checking for embedded posts...
[Embedded Reply Buttons] Owner comment mode: true
[Embedded Reply Buttons] Found 1 already-expanded embedded post sections
[Embedded Reply Buttons] Processing already-expanded section 1...
[Embedded Reply Buttons] Injecting buttons into container: <section>
[Embedded Reply Buttons] Found X embedded post items
...
[Embedded Reply Buttons] Injection complete: X injected, 0 skipped
```

**Verify**:
- ✅ Buttons are injected via fallback path
- ✅ No MutationObserver needed

## Comprehensive Test Cases

### Test Case 1: Single Post with Embedded Replies
1. Navigate to topic in filtered view
2. Find a post with "x replies to post" button
3. Click the button
4. Verify reply buttons appear
5. Click a reply button
6. Verify composer opens with correct context

### Test Case 2: Multiple Posts with Embedded Replies
1. Navigate to topic with multiple posts that have replies
2. Expand first post's replies
3. Verify buttons injected
4. Expand second post's replies
5. Verify buttons injected
6. Verify both sets of buttons work independently

### Test Case 3: Load More Replies
1. Expand embedded posts
2. If "Load more replies" button exists, click it
3. Verify new embedded posts get reply buttons
4. Verify existing buttons are not duplicated

### Test Case 4: Collapse and Re-expand
1. Expand embedded posts
2. Verify buttons appear
3. Collapse embedded posts
4. Re-expand embedded posts
5. Verify buttons appear again (no duplicates)

### Test Case 5: Page Navigation
1. Expand embedded posts
2. Navigate to different page
3. Verify observers are cleaned up (check console)
4. Navigate back
5. Re-expand embedded posts
6. Verify feature still works

### Test Case 6: Not in Owner Comment Mode
1. Navigate to topic WITHOUT filtered view
2. Click "show replies" button
3. Verify console shows: "Not in owner comment mode, ignoring click"
4. Verify no buttons are injected

## Debugging Tips

### Check if MutationObserver is Working
```javascript
// In browser console
console.log("Active observers:", activeObservers.size);
```

### Check if Embedded Posts Exist
```javascript
// In browser console
document.querySelectorAll("section.embedded-posts").length
```

### Check if Buttons Were Injected
```javascript
// In browser console
document.querySelectorAll(".embedded-reply-button").length
```

### Check Owner Comment Mode
```javascript
// In browser console
document.body.dataset.ownerCommentMode
```

## Common Issues and Solutions

### Issue: "Found 0 embedded post sections" on page load
**Solution**: This is expected! Embedded posts don't exist until user clicks "show replies".

### Issue: Buttons not appearing after clicking "show replies"
**Debugging**:
1. Check console for MutationObserver setup message
2. Check if `section.embedded-posts` was detected
3. Verify owner comment mode is active
4. Check for JavaScript errors

### Issue: Duplicate buttons
**Debugging**:
1. Check if `data-reply-btn-bound` attribute is set
2. Verify idempotent injection logic
3. Check console for "skipped" messages

### Issue: Observer not cleaning up
**Debugging**:
1. Navigate to different page
2. Check console for "Cleaning up X active observers"
3. Verify count matches expected number

## Performance Considerations

### Observer Lifecycle
- ✅ Observers are created only when user clicks "show replies"
- ✅ Observers are disconnected after detecting embedded posts
- ✅ All observers are cleaned up on page navigation
- ✅ No memory leaks

### Event Delegation
- ✅ Single global click handler for all reply buttons
- ✅ Single global click handler for all show-replies buttons
- ✅ No per-element event listeners

## Success Criteria

✅ **All tests pass**:
1. Buttons appear when user expands embedded posts
2. Buttons open composer with correct reply context
3. Filtered view is maintained after posting
4. No duplicate buttons
5. No memory leaks
6. Observers are cleaned up properly
7. Feature works after navigation
8. Console logs are clear and helpful

## Next Steps

After successful testing:
1. Update documentation to reflect MutationObserver approach
2. Consider removing excessive console logs for production
3. Merge to main branch
4. Deploy to Discourse instance
5. Monitor for any issues in production

