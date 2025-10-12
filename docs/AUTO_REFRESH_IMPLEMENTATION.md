# Auto-Refresh Embedded Posts After Reply - Implementation

## Overview

This feature automatically refreshes the embedded posts section after a user submits a reply via the embedded reply button, eliminating the need for manual interaction with the "load more replies" button.

## Problem Solved

**Before:**
1. User clicks reply button on embedded post
2. User writes and submits reply
3. Reply is created successfully
4. "Load more replies" button appears
5. ❌ User must manually click button to see their new reply

**After:**
1. User clicks reply button on embedded post
2. User writes and submits reply
3. Reply is created successfully
4. ✅ Embedded posts section automatically refreshes
5. ✅ New reply appears immediately

## Implementation Details

### Architecture

```
User submits reply via composer
         ↓
Discourse saves post to server
         ↓
appEvents fires "composer:saved" event
         ↓
Event listener detects the event
         ↓
Check if in owner comment mode
         ↓
Find parent post element
         ↓
Schedule afterRender callback
         ↓
Look for "load more replies" button
         ↓
If found: Click button immediately
If not found: Set up MutationObserver
         ↓
Button appears → Observer clicks it
         ↓
Embedded posts section refreshes
         ↓
New reply appears in the list
```

### Code Location

**File:** `javascripts/discourse/api-initializers/embedded-reply-buttons.gjs`
**Lines:** 491-553

### Key Components

#### 1. Event Listener Setup

```javascript
const appEvents = api.container.lookup("service:app-events");

appEvents.on("composer:saved", (post) => {
  // Handle post save event
});
```

**Why `composer:saved`?**
- Fires immediately after post is successfully saved to server
- Provides the newly created post object with all metadata
- Includes `reply_to_post_number` which we need to find parent post

#### 2. Guard Conditions

```javascript
// Only process in owner comment mode
const isOwnerCommentMode = document.body.dataset.ownerCommentMode === "true";
if (!isOwnerCommentMode) return;

// Only process if this is a reply (has reply_to_post_number)
const parentPostNumber = post.reply_to_post_number;
if (!parentPostNumber) return;
```

**Why these guards?**
- Prevents interference with normal (non-filtered) view
- Only triggers for replies, not new topics or top-level posts
- Ensures we have the information needed to find parent post

#### 3. Parent Post Lookup

```javascript
const parentPostElement = document.querySelector(
  `article.topic-post[data-post-number="${parentPostNumber}"]`
);
```

**Why this selector?**
- Uses the post number from the newly created post
- Finds the exact post that was replied to
- This is where the embedded posts section will be

#### 4. Timing with afterRender

```javascript
schedule("afterRender", () => {
  // DOM manipulation here
});
```

**Why `afterRender`?**
- Ensures DOM has updated after post creation
- Discourse may re-render parts of the page
- Gives time for "load more replies" button to appear

#### 5. Two-Tier Approach

**Tier 1: Immediate Click**
```javascript
const loadMoreBtn = embeddedSection?.querySelector(".load-more-replies");
if (loadMoreBtn) {
  loadMoreBtn.click();
}
```

**Tier 2: MutationObserver Fallback**
```javascript
const observer = new MutationObserver(() => {
  const btn = parentPostElement.querySelector(
    "section.embedded-posts .load-more-replies"
  );
  
  if (btn) {
    btn.click();
    observer.disconnect();
  }
});

observer.observe(parentPostElement, {
  childList: true,
  subtree: true
});

// Timeout to prevent infinite observation
setTimeout(() => observer.disconnect(), 5000);
```

**Why two tiers?**
- Button may already exist (fast path)
- Button may appear with delay due to async rendering (fallback)
- MutationObserver waits for button to appear
- Timeout prevents memory leaks if button never appears

## Benefits

### 1. Improved User Experience
- ✅ Immediate feedback after posting
- ✅ No manual interaction required
- ✅ Seamless workflow in filtered view
- ✅ Matches user expectations

### 2. Maintains Filtered View
- ✅ User stays in owner comment mode
- ✅ URL parameters preserved
- ✅ No navigation away from current context
- ✅ Consistent with existing behavior

### 3. Robust Implementation
- ✅ Handles both immediate and delayed button appearance
- ✅ Includes timeout to prevent infinite observation
- ✅ Only triggers in appropriate context (owner comment mode)
- ✅ Uses Discourse's built-in refresh mechanism

### 4. SPA Compatible
- ✅ Uses Discourse's event system
- ✅ Proper timing with `schedule("afterRender")`
- ✅ No memory leaks (observer cleanup)
- ✅ Works with Ember.js routing

## Edge Cases Handled

### 1. Button Already Exists
- **Scenario:** "Load more replies" button is already rendered
- **Handling:** Immediate click (Tier 1)
- **Result:** Fast refresh

### 2. Button Appears with Delay
- **Scenario:** Button renders asynchronously after post creation
- **Handling:** MutationObserver waits for it (Tier 2)
- **Result:** Reliable refresh even with timing variations

### 3. Button Never Appears
- **Scenario:** No embedded posts section or button doesn't render
- **Handling:** 5-second timeout disconnects observer
- **Result:** No memory leak, graceful degradation

### 4. Not in Owner Comment Mode
- **Scenario:** User is in normal (non-filtered) view
- **Handling:** Early return, no action taken
- **Result:** No interference with normal behavior

### 5. Top-Level Post (Not a Reply)
- **Scenario:** User creates new topic or top-level post
- **Handling:** Check for `reply_to_post_number`, return if null
- **Result:** Only processes actual replies

### 6. Parent Post Not Found
- **Scenario:** Parent post not in DOM (shouldn't happen but defensive)
- **Handling:** Early return if `parentPostElement` is null
- **Result:** No errors, graceful degradation

## Testing Checklist

### Basic Functionality
- [ ] Click reply button on embedded post
- [ ] Write and submit reply
- [ ] Verify embedded posts section refreshes automatically
- [ ] Verify new reply appears without manual interaction
- [ ] Verify "load more replies" button is clicked programmatically

### Timing Scenarios
- [ ] Test with fast network (button appears immediately)
- [ ] Test with slow network (button appears with delay)
- [ ] Test with very slow network (timeout scenario)
- [ ] Verify no errors in console in any scenario

### Context Scenarios
- [ ] Test in owner comment mode (filtered view) - should work
- [ ] Test in normal view - should not trigger
- [ ] Test replying to top-level post - should work
- [ ] Test creating new topic - should not trigger

### Edge Cases
- [ ] Test when embedded posts section doesn't exist
- [ ] Test when parent post is not in DOM
- [ ] Test rapid successive replies
- [ ] Test navigating away before refresh completes

### Integration
- [ ] Verify doesn't break existing reply button functionality
- [ ] Verify doesn't break "show replies" button
- [ ] Verify doesn't break manual "load more replies" click
- [ ] Verify works with MutationObserver for button injection

## Debugging

### Enable Logging

Add temporary logging to debug issues:

```javascript
appEvents.on("composer:saved", (post) => {
  console.log("[Auto-Refresh] Post saved:", post);
  console.log("[Auto-Refresh] Reply to post number:", post.reply_to_post_number);
  console.log("[Auto-Refresh] Owner comment mode:", document.body.dataset.ownerCommentMode);
  
  // ... rest of code
  
  if (loadMoreBtn) {
    console.log("[Auto-Refresh] Clicking load more button immediately");
    loadMoreBtn.click();
  } else {
    console.log("[Auto-Refresh] Setting up observer to wait for button");
  }
});
```

### Common Issues

**Issue:** Refresh doesn't trigger
- **Check:** Is `ownerCommentMode` set to "true"?
- **Check:** Does post have `reply_to_post_number`?
- **Check:** Is parent post element in DOM?

**Issue:** Button click doesn't work
- **Check:** Is button selector correct?
- **Check:** Is button actually clickable (not disabled)?
- **Check:** Check browser console for errors

**Issue:** Observer never finds button
- **Check:** Is embedded posts section rendering?
- **Check:** Is button selector correct?
- **Check:** Check if timeout is too short (increase from 5s)

## Future Enhancements

### Potential Improvements

1. **Visual Feedback**
   - Show loading indicator while refreshing
   - Highlight newly added post
   - Smooth scroll to new post

2. **Optimistic UI Update**
   - Add new post to DOM immediately
   - Don't wait for server refresh
   - Update with server data when available

3. **Smarter Refresh**
   - Only refresh if new post would be visible in filter
   - Skip refresh if new post is from different user
   - Batch multiple rapid replies

4. **Configuration**
   - Add theme setting to enable/disable auto-refresh
   - Add setting for timeout duration
   - Add setting for visual feedback

## References

- [Discourse appEvents Documentation](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/app-events.js)
- [Composer Service](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js)
- [MutationObserver MDN](https://developer.mozilla.org/en-US/docs/Web/API/MutationObserver)
- [Ember runloop schedule](https://api.emberjs.com/ember/5.0/functions/@ember%2Frunloop/schedule)

