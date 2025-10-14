# Standard Reply Button Interception - Code Implementation

## File: `javascripts/discourse/api-initializers/embedded-reply-buttons.gjs`

### Change 1: Add Module-Scoped Variables

**Location**: After line 15 (after existing module variables)

```javascript
// Existing variables
let globalClickHandlerBound = false;
let showRepliesClickHandlerBound = false;
let composerEventsBound = false;
const activeObservers = new Map();
const LOG_PREFIX = "[Embedded Reply Buttons]";
let lastReplyContext = { topicId: null, parentPostNumber: null };
let lastCreatedPost = null;

// NEW: Add these variables
let standardReplyInterceptBound = false;
let suppressStandardReplyScroll = false;
let suppressedReplyPostNumber = null;
```

### Change 2: Extract Shared Composer Opening Function

**Location**: After helper functions (around line 200, before button injection logic)

```javascript
/**
 * Shared function to open composer for replying to owner's post
 * Used by both embedded reply button and intercepted standard reply button
 */
async function openReplyToOwnerPost(topic, ownerPost, ownerPostNumber) {
  console.log(`${LOG_PREFIX} Opening reply to owner post #${ownerPostNumber}`);
  
  const composer = api.container.lookup("service:composer");
  if (!composer) {
    console.log(`${LOG_PREFIX} Composer not available`);
    return;
  }
  
  // Build composer options
  const composerOptions = {
    action: "reply",
    topic: topic,
    draftKey: topic.draft_key,
    draftSequence: topic.draft_sequence,
    skipJumpOnSave: true,
  };
  
  // Store context for auto-refresh fallback
  lastReplyContext = { 
    topicId: topic.id, 
    parentPostNumber: ownerPostNumber, 
    ownerPostNumber 
  };
  console.log(`${LOG_PREFIX} Stored lastReplyContext`, lastReplyContext);
  
  // Add post model if available, otherwise use post number
  if (ownerPost) {
    composerOptions.post = ownerPost;
  } else {
    composerOptions.replyToPostNumber = ownerPostNumber;
  }
  
  await composer.open(composerOptions);
  console.log(`${LOG_PREFIX} Composer opened successfully`);
}
```

### Change 3: Refactor Embedded Button Click Handler

**Location**: Lines 534-552 (inside embedded button click handler)

**BEFORE**:
```javascript
// Open the composer
const composerOptions = {
  action: "reply",
  topic: topic,
  draftKey: topic.draft_key,
  draftSequence: topic.draft_sequence,
  skipJumpOnSave: true,
};

// Remember context for auto-refresh fallback
lastReplyContext = { topicId: topic.id, parentPostNumber: ownerPostNumber, ownerPostNumber };
console.log(`${LOG_PREFIX} AutoRefresh: stored lastReplyContext`, lastReplyContext);

if (ownerPost) {
  composerOptions.post = ownerPost;
}

await composer.open(composerOptions);
console.log(`${LOG_PREFIX} Composer opened successfully`);
```

**AFTER**:
```javascript
// Use shared function to open composer
await openReplyToOwnerPost(topic, ownerPost, ownerPostNumber);
```

### Change 4: Add Standard Reply Button Interceptor

**Location**: After the "show replies" click handler (after line 625, before page change handler)

```javascript
// Delegated click handler for standard reply buttons (intercept in filtered view)
if (!standardReplyInterceptBound) {
  document.addEventListener(
    "click",
    async (e) => {
      const btn = e.target?.closest?.("button.post-action-menu__reply");
      if (!btn) return;
      
      // Guard 1: Only intercept in owner comment mode
      const isOwnerCommentMode = document.body.dataset.ownerCommentMode === "true";
      if (!isOwnerCommentMode) {
        console.log(`${LOG_PREFIX} Standard reply - not in owner mode, allowing default`);
        return;
      }
      
      // Guard 2: Find the post element
      const postElement = btn.closest("article.topic-post");
      if (!postElement) {
        console.log(`${LOG_PREFIX} Standard reply - no post element found`);
        return;
      }
      
      // Guard 3: Get topic and verify data availability
      const topic = api.container.lookup("controller:topic")?.model;
      const topicOwnerId = topic?.details?.created_by?.id;
      const postNumber = extractPostNumberFromElement(postElement);
      
      if (!postNumber || !topic || !topicOwnerId) {
        console.log(`${LOG_PREFIX} Standard reply - missing required data`);
        return;
      }
      
      // Guard 4: Check if this is an owner post
      const post = topic.postStream?.posts?.find(p => p.post_number === postNumber);
      const isOwnerPost = post?.user_id === topicOwnerId;
      
      if (!isOwnerPost) {
        console.log(`${LOG_PREFIX} Standard reply - not owner post, allowing default`);
        return;
      }
      
      // All guards passed - intercept the click!
      console.log(`${LOG_PREFIX} Standard reply intercepted for owner post #${postNumber}`);
      
      // Prevent default Discourse behavior
      e.preventDefault();
      e.stopPropagation();
      
      // Set suppression flag for post-creation handling
      suppressStandardReplyScroll = true;
      suppressedReplyPostNumber = postNumber;
      console.log(`${LOG_PREFIX} Set suppression flag for post #${postNumber}`);
      
      try {
        // Use shared function to open composer (same as embedded button)
        await openReplyToOwnerPost(topic, post, postNumber);
      } catch (error) {
        console.error(`${LOG_PREFIX} Error opening composer for standard reply:`, error);
        // Clear suppression flag on error
        suppressStandardReplyScroll = false;
        suppressedReplyPostNumber = null;
      }
    },
    true // Use capture phase for early interception
  );
  
  standardReplyInterceptBound = true;
  console.log(`${LOG_PREFIX} Standard reply interceptor bound`);
}
```

### Change 5: Modify composer:saved Event Handler

**Location**: Inside `composer:saved` handler (around line 710-720)

**BEFORE**:
```javascript
appEvents.on("composer:saved", (post) => {
  try {
    console.log(`${LOG_PREFIX} AutoRefresh: binding composer:saved handler`);
    // Only process in owner comment mode
    const isOwnerCommentMode = document.body.dataset.ownerCommentMode === "true";
    console.log(`${LOG_PREFIX} AutoRefresh: composer:saved fired`, { 
      id: post?.id, 
      post_number: post?.post_number, 
      reply_to_post_number: post?.reply_to_post_number, 
      isOwnerCommentMode 
    });
    if (!isOwnerCommentMode) {
      console.log(`${LOG_PREFIX} AutoRefresh: skipping - not in owner comment mode`);
      return;
    }
    
    // ... rest of handler
```

**AFTER**:
```javascript
appEvents.on("composer:saved", (post) => {
  try {
    console.log(`${LOG_PREFIX} AutoRefresh: binding composer:saved handler`);
    
    // Check and consume suppression flag
    if (suppressStandardReplyScroll) {
      console.log(`${LOG_PREFIX} Standard reply suppression active - preventing default scroll`);
      console.log(`${LOG_PREFIX} Suppressed post number: ${suppressedReplyPostNumber}`);
      suppressStandardReplyScroll = false;
      suppressedReplyPostNumber = null;
      // Continue with embedded refresh logic below
    }
    
    // Only process in owner comment mode
    const isOwnerCommentMode = document.body.dataset.ownerCommentMode === "true";
    console.log(`${LOG_PREFIX} AutoRefresh: composer:saved fired`, { 
      id: post?.id, 
      post_number: post?.post_number, 
      reply_to_post_number: post?.reply_to_post_number, 
      isOwnerCommentMode 
    });
    if (!isOwnerCommentMode) {
      console.log(`${LOG_PREFIX} AutoRefresh: skipping - not in owner comment mode`);
      return;
    }
    
    // ... rest of handler (unchanged)
```

## Summary of Changes

### Lines Added/Modified

1. **Module variables**: +3 lines
2. **Shared function**: +40 lines
3. **Refactor embedded handler**: -18 lines, +1 line (net: -17 lines)
4. **Standard reply interceptor**: +65 lines
5. **Composer:saved modification**: +7 lines

**Total**: ~98 lines added, ~17 lines removed = **~81 net lines added**

### Functions Added

1. `openReplyToOwnerPost(topic, ownerPost, ownerPostNumber)` - Shared composer opening logic

### Event Listeners Added

1. Standard reply button interceptor (delegated, capture phase)

### State Variables Added

1. `standardReplyInterceptBound` - Idempotent binding flag
2. `suppressStandardReplyScroll` - One-shot suppression flag
3. `suppressedReplyPostNumber` - Track which post triggered suppression

## Testing Verification Code

### Test 1: Verify Interceptor is Bound

```javascript
// Run in browser console after page load
console.log("Standard reply interceptor bound:", 
  window.location.href.includes('/t/') && 
  document.body.dataset.ownerCommentMode === "true"
);
```

### Test 2: Verify Guards Work

```javascript
// Click standard reply button on owner post in filtered view
// Should see in console:
// [Embedded Reply Buttons] Standard reply intercepted for owner post #X
// [Embedded Reply Buttons] Set suppression flag for post #X
// [Embedded Reply Buttons] Opening reply to owner post #X
```

### Test 3: Verify Suppression Consumption

```javascript
// After submitting reply via standard button
// Should see in console:
// [Embedded Reply Buttons] Standard reply suppression active - preventing default scroll
// [Embedded Reply Buttons] Suppressed post number: X
```

### Test 4: Verify Non-Owner Posts Not Intercepted

```javascript
// Click standard reply button on non-owner post
// Should see in console:
// [Embedded Reply Buttons] Standard reply - not owner post, allowing default
```

## Edge Cases Handled

1. **Missing post element**: Guard 2 catches this
2. **Missing topic data**: Guard 3 catches this
3. **Non-owner post**: Guard 4 catches this
4. **Not in filtered view**: Guard 1 catches this
5. **Composer open error**: Try-catch clears suppression flag
6. **Multiple rapid clicks**: One-shot suppression prevents issues

## Logging Output Examples

### Successful Interception
```
[Embedded Reply Buttons] Standard reply intercepted for owner post #1
[Embedded Reply Buttons] Set suppression flag for post #1
[Embedded Reply Buttons] Opening reply to owner post #1
[Embedded Reply Buttons] Stored lastReplyContext {topicId: 123, parentPostNumber: 1, ownerPostNumber: 1}
[Embedded Reply Buttons] Composer opened successfully
[Embedded Reply Buttons] AutoScroll: post:created fired {post_number: 5, ...}
[Embedded Reply Buttons] AutoScroll: stored lastCreatedPost {postNumber: 5, ...}
[Embedded Reply Buttons] AutoRefresh: composer:saved fired
[Embedded Reply Buttons] Standard reply suppression active - preventing default scroll
[Embedded Reply Buttons] Suppressed post number: 1
[Embedded Reply Buttons] AutoRefresh: clicking loadMoreBtn immediately
[Embedded Reply Buttons] AutoScroll: scrolling to post #5
```

### Non-Owner Post (Not Intercepted)
```
[Embedded Reply Buttons] Standard reply - not owner post, allowing default
```

### Not in Filtered View (Not Intercepted)
```
[Embedded Reply Buttons] Standard reply - not in owner mode, allowing default
```

## Rollback Instructions

If issues occur, comment out these sections:

1. **Standard reply interceptor** (lines added in Change 4)
2. **Suppression consumption** (lines added in Change 5)
3. **Module variables** (lines added in Change 1)

Keep:
- Shared function `openReplyToOwnerPost()` (useful for future)
- Refactored embedded button handler (cleaner code)

Or fully revert:
- Restore embedded button handler to original inline code
- Remove all changes from this implementation

