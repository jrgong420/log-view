# Auto-Scroll to Newly Created Embedded Posts

## Overview

This feature automatically scrolls to and highlights newly created embedded posts after a user submits a reply via the embedded reply buttons. This ensures the user can immediately see their new post without manually searching for it.

## Problem Statement

When a user clicks the embedded reply button and submits a new reply:
1. The composer opens and the reply is created
2. The new post is initially collapsed and hidden
3. User must manually click "load more replies" to see their new post
4. Even after clicking, the new post may be off-screen

**Desired behavior**: Automatically expand replies, scroll to the new post, and highlight it for visual confirmation.

## Implementation

### 1. State Management

**Module-scoped state** (`lastCreatedPost`):
```javascript
let lastCreatedPost = null;
```

Stores:
- `topicId`: Topic ID of the created post
- `postNumber`: Post number of the created post
- `replyToPostNumber`: Parent post number
- `timestamp`: Creation timestamp

### 2. Event Listeners

#### A. `post:created` Event
Captures newly created post details immediately after creation:

```javascript
appEvents.on("post:created", (createdPost) => {
  // Only in owner comment mode
  if (!isOwnerCommentMode) return;
  
  // Store post details for auto-scroll
  lastCreatedPost = {
    topicId: createdPost?.topic_id,
    postNumber: createdPost?.post_number,
    replyToPostNumber: createdPost?.reply_to_post_number,
    timestamp: Date.now()
  };
});
```

#### B. `composer:saved` Event (existing)
Already implemented - clicks "load more replies" button to expand embedded posts.

### 3. Auto-Scroll Helper Function

**`tryScrollToNewReply(section)`**:
- Searches for the newly created post in the embedded section
- Uses multiple selectors for robustness:
  - `[data-post-number="${postNumber}"]`
  - `#post_${postNumber}`
  - `#post-${postNumber}`
- Scrolls element into view with smooth animation
- Adds temporary highlight class for visual feedback
- Clears state after successful scroll

```javascript
function tryScrollToNewReply(section) {
  if (!lastCreatedPost?.postNumber) return false;
  
  // Find the element
  const selectors = [
    `[data-post-number="${lastCreatedPost.postNumber}"]`,
    `#post_${lastCreatedPost.postNumber}`,
    `#post-${lastCreatedPost.postNumber}`
  ];
  
  let foundElement = null;
  for (const selector of selectors) {
    foundElement = section.querySelector(selector);
    if (foundElement) break;
  }
  
  if (foundElement) {
    // Scroll into view
    foundElement.scrollIntoView({ 
      block: "center", 
      behavior: "smooth" 
    });
    
    // Add highlight
    foundElement.classList.add("highlighted-reply");
    setTimeout(() => {
      foundElement.classList.remove("highlighted-reply");
    }, 2000);
    
    // Clear state
    lastCreatedPost = null;
    return true;
  }
  
  return false;
}
```

### 4. Integration with Load More Replies

After clicking "load more replies" button (both immediate and observer paths):

1. **Try immediate scroll**: Call `tryScrollToNewReply()` right after click
2. **If not found**: Set up MutationObserver to watch for new post
3. **Observer**: Continuously checks for new post until found or timeout (10s)
4. **On success**: Scroll and disconnect observer
5. **On timeout**: Disconnect and clear stale state

### 5. Visual Feedback (CSS)

**Highlight animation** (`highlighted-reply` class):
- 2-second fade-in/fade-out animation
- Background color pulse using theme colors
- Left border accent in tertiary color
- Box shadow expansion effect

```scss
@keyframes highlightFadeIn {
  0% {
    background-color: var(--tertiary-very-low);
    box-shadow: 0 0 0 0 var(--tertiary-low);
  }
  50% {
    background-color: var(--tertiary-low);
    box-shadow: 0 0 0 4px var(--tertiary-very-low);
  }
  100% {
    background-color: var(--tertiary-very-low);
    box-shadow: 0 0 0 0 var(--tertiary-low);
  }
}

.highlighted-reply {
  animation: highlightFadeIn 2s ease-in-out;
  border-left: 3px solid var(--tertiary) !important;
  transition: border-left 0.3s ease;
}
```

## Flow Diagram

```
User clicks embedded reply button
         ↓
Composer opens with reply context
         ↓
User submits reply
         ↓
post:created event fires → Store lastCreatedPost
         ↓
composer:saved event fires → Click "load more replies"
         ↓
Try immediate scroll → Found? → YES → Scroll + Highlight → Done
         ↓ NO
Set up MutationObserver
         ↓
Wait for new post to render (max 10s)
         ↓
Post appears → Scroll + Highlight → Done
         ↓ (timeout)
Clear stale state → Done
```

## Guards and Safety

1. **Owner comment mode check**: Only runs when `body[data-owner-comment-mode="true"]`
2. **State consumption**: `lastCreatedPost` is cleared after successful scroll
3. **Timeout protection**: Observers disconnect after 10 seconds
4. **Stale state cleanup**: Timeout clears `lastCreatedPost` to prevent future false positives
5. **Idempotency**: Multiple calls to `tryScrollToNewReply()` are safe (returns early if no state)

## Testing Scenarios

### Scenario 1: Fast Network (Post Already Rendered)
1. Click embedded reply button
2. Submit reply
3. "Load more replies" clicked automatically
4. Post already in DOM → Immediate scroll + highlight

### Scenario 2: Slow Network (Post Not Yet Rendered)
1. Click embedded reply button
2. Submit reply
3. "Load more replies" clicked automatically
4. Post not in DOM yet → Observer set up
5. Post renders after 2-3 seconds → Observer detects → Scroll + highlight

### Scenario 3: Already Expanded Section
1. Section already expanded (no "load more" button)
2. Click embedded reply button
3. Submit reply
4. Observer watches for new post directly
5. Post renders → Scroll + highlight

### Scenario 4: Multiple Rapid Replies
1. Submit first reply → Scroll to first post
2. Immediately submit second reply
3. State cleared from first → Only second post scrolled to
4. No duplicate scrolls or stale state issues

## Logging

All operations logged with `[Embedded Reply Buttons] AutoScroll:` prefix:

- `post:created fired` - Captures new post details
- `stored lastCreatedPost` - State saved
- `searching for post #X` - Looking for element
- `found element with selector: Y` - Element located
- `scrolling to post #X` - Scroll initiated
- `clearing lastCreatedPost` - State cleared
- `observer timeout` - Timeout reached
- `observer successfully scrolled` - Observer path succeeded

## Files Modified

1. **javascripts/discourse/api-initializers/embedded-reply-buttons.gjs**
   - Added `lastCreatedPost` state variable
   - Added `tryScrollToNewReply()` helper function
   - Added `post:created` event listener
   - Integrated scroll logic into "load more replies" flow (both paths)

2. **common/common.scss**
   - Added `@keyframes highlightFadeIn` animation
   - Added `.highlighted-reply` class styling

## Browser Compatibility

- `scrollIntoView()` with options: Modern browsers (Chrome 61+, Firefox 58+, Safari 14+)
- CSS animations: All modern browsers
- Fallback: If `scrollIntoView` options not supported, basic scroll still works

## Performance Considerations

- **Minimal overhead**: Only runs in owner comment mode
- **Observer cleanup**: All observers disconnect after use or timeout
- **State cleanup**: No memory leaks from stale state
- **Efficient selectors**: Uses specific ID/attribute selectors for fast lookup

## Future Enhancements

1. **Configurable highlight duration**: Theme setting for animation length
2. **Scroll offset**: Theme setting to control scroll position (top/center/bottom)
3. **Sound/haptic feedback**: Optional audio/vibration on mobile
4. **Accessibility**: ARIA live region announcement for screen readers
5. **Retry logic**: Exponential backoff for observer checks instead of continuous polling

