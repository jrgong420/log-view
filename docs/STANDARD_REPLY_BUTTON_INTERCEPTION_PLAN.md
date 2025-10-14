# Standard Reply Button Interception - Implementation Plan

## Goal

Unify reply behavior in filtered view so that replies via the standard `button.post-action-menu__reply` button behave exactly like replies via the custom `button.btn.btn-small.embedded-reply-button`.

## Current State Analysis

### Filtered View Detection
**Location**: `owner-comment-prototype.gjs`
- **URL Parameter**: `username_filters` equals topic owner username
- **UI Indicator**: `document.body.dataset.ownerCommentMode === "true"`
- **Multiple Guards**: Both URL param and body dataset are checked

### Embedded Reply Button Flow (Current Working Implementation)
**Location**: `embedded-reply-buttons.gjs` lines 452-560

**Click Handler**:
1. Delegated event listener on `document` (capture phase)
2. Selector: `.embedded-reply-button`
3. Extracts `ownerPostNumber` from `btn.dataset.ownerPostNumber`
4. Opens composer with:
   - `action: "reply"`
   - `topic: topic`
   - `skipJumpOnSave: true`
   - `replyToPostNumber: ownerPostNumber`
   - `post: ownerPost` (if available)
5. Stores context: `lastReplyContext = { topicId, parentPostNumber, ownerPostNumber }`

**Post Creation Flow** (lines 676-943):
1. **`post:created` event** (lines 684-707):
   - Checks `isOwnerCommentMode`
   - Stores `lastCreatedPost` with post details
2. **`composer:saved` event** (lines 710-939):
   - Checks `isOwnerCommentMode`
   - Derives `parentPostNumber` from multiple sources
   - Finds owner post element containing embedded section
   - Clicks "load more replies" button
   - Attempts immediate scroll to new post
   - Sets up MutationObserver if post not immediately visible
   - Scrolls and highlights new post when it appears

### Standard Reply Button (Default Discourse Behavior)
**Selector**: `button.post-action-menu__reply`
**Current Behavior**:
- Opens composer normally
- After post creation, scrolls to new post in main stream
- Does NOT trigger embedded section refresh
- Does NOT maintain filtered view context

## Implementation Plan

### Phase 1: Intercept Standard Reply Click

**File**: `embedded-reply-buttons.gjs`
**Location**: Add new delegated listener alongside existing ones

**Requirements**:
1. Add delegated click handler for `button.post-action-menu__reply`
2. Only intercept when:
   - Filtered view is active (`isOwnerCommentMode === true`)
   - Clicked button belongs to a topic owner's post
3. Prevent default behavior
4. Set suppression flag to prevent default post-creation scroll

**Implementation Details**:

```javascript
// Module-scoped suppression flags
let suppressStandardReplyScroll = false;
let suppressedReplyPostNumber = null;

// New delegated listener (add after showRepliesClickHandlerBound block)
if (!standardReplyInterceptBound) {
  document.addEventListener("click", async (e) => {
    const btn = e.target?.closest?.("button.post-action-menu__reply");
    if (!btn) return;
    
    // Guard 1: Only in owner comment mode
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
    
    // Guard 3: Check if this is an owner post
    const topic = api.container.lookup("controller:topic")?.model;
    const topicOwnerId = topic?.details?.created_by?.id;
    const postNumber = extractPostNumberFromElement(postElement);
    
    if (!postNumber || !topic) {
      console.log(`${LOG_PREFIX} Standard reply - missing data`);
      return;
    }
    
    const post = topic.postStream?.posts?.find(p => p.post_number === postNumber);
    const isOwnerPost = post?.user_id === topicOwnerId;
    
    if (!isOwnerPost) {
      console.log(`${LOG_PREFIX} Standard reply - not owner post, allowing default`);
      return;
    }
    
    // All guards passed - intercept!
    console.log(`${LOG_PREFIX} Standard reply intercepted for owner post #${postNumber}`);
    
    // Prevent default behavior
    e.preventDefault();
    e.stopPropagation();
    
    // Set suppression flag
    suppressStandardReplyScroll = true;
    suppressedReplyPostNumber = postNumber;
    
    // Reuse embedded reply logic
    await openReplyToOwnerPost(topic, post, postNumber);
    
  }, true); // Capture phase
  
  standardReplyInterceptBound = true;
}
```

### Phase 2: Extract Reusable Composer Opening Logic

**File**: `embedded-reply-buttons.gjs`
**Location**: Extract from existing embedded button handler (lines 467-555)

**Create new function**:

```javascript
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
  
  // Store context for auto-refresh
  lastReplyContext = { 
    topicId: topic.id, 
    parentPostNumber: ownerPostNumber, 
    ownerPostNumber 
  };
  console.log(`${LOG_PREFIX} Stored lastReplyContext`, lastReplyContext);
  
  // Add post if available
  if (ownerPost) {
    composerOptions.post = ownerPost;
  } else {
    composerOptions.replyToPostNumber = ownerPostNumber;
  }
  
  await composer.open(composerOptions);
  console.log(`${LOG_PREFIX} Composer opened successfully`);
}
```

**Refactor existing embedded button handler** to use this function:

```javascript
// In embedded button click handler (around line 534)
// Replace lines 534-552 with:
await openReplyToOwnerPost(topic, ownerPost, ownerPostNumber);
```

### Phase 3: Suppress Default Scroll After Post Creation

**File**: `embedded-reply-buttons.gjs`
**Location**: Modify `composer:saved` event handler (around line 710)

**Add suppression consumption**:

```javascript
appEvents.on("composer:saved", (post) => {
  try {
    console.log(`${LOG_PREFIX} AutoRefresh: composer:saved fired`);
    
    // Check and consume suppression flag
    if (suppressStandardReplyScroll) {
      console.log(`${LOG_PREFIX} Standard reply suppression active - preventing default scroll`);
      suppressStandardReplyScroll = false;
      // Continue with embedded refresh logic below
    }
    
    // Existing owner comment mode check
    const isOwnerCommentMode = document.body.dataset.ownerCommentMode === "true";
    // ... rest of existing logic
  } catch (err) {
    console.error(`${LOG_PREFIX} AutoRefresh: error`, err);
  }
});
```

**Note**: The existing `composer:saved` handler already:
- Checks `isOwnerCommentMode`
- Finds the owner post element
- Clicks "load more replies"
- Handles auto-scroll to new post

So we just need to ensure the suppression flag is consumed and logged.

### Phase 4: Testing & Verification

**Test Cases**:

1. **Standard reply to owner post in filtered view**:
   - ✅ Click `button.post-action-menu__reply` on owner's post
   - ✅ Composer opens with correct context
   - ✅ Submit reply
   - ✅ New post appears in embedded section (not main stream)
   - ✅ Auto-scroll to new post works
   - ✅ No scroll to main stream

2. **Standard reply to non-owner post in filtered view**:
   - ✅ Click `button.post-action-menu__reply` on non-owner's post
   - ✅ Default Discourse behavior (no interception)

3. **Standard reply when NOT in filtered view**:
   - ✅ Click `button.post-action-menu__reply`
   - ✅ Default Discourse behavior (no interception)

4. **Embedded reply button (regression test)**:
   - ✅ Click `.embedded-reply-button`
   - ✅ Existing behavior unchanged

5. **Multiple rapid replies**:
   - ✅ Reply via standard button
   - ✅ Reply via embedded button
   - ✅ Both work correctly

## Code Structure Summary

### New Module-Level Variables
```javascript
let standardReplyInterceptBound = false;
let suppressStandardReplyScroll = false;
let suppressedReplyPostNumber = null;
```

### New Functions
```javascript
async function openReplyToOwnerPost(topic, ownerPost, ownerPostNumber)
```

### Modified Sections
1. Embedded button click handler - refactored to use `openReplyToOwnerPost()`
2. New standard reply interceptor - delegated listener
3. `composer:saved` handler - consume suppression flag

## SPA Safety Considerations

### Event Delegation
- ✅ Single delegated listener at document level
- ✅ Capture phase for early interception
- ✅ Idempotent binding with `standardReplyInterceptBound` flag

### State Management
- ✅ Module-scoped flags (view-only state)
- ✅ One-shot suppression pattern
- ✅ Cleared after consumption

### Guards
- ✅ Check `isOwnerCommentMode` (URL + body dataset)
- ✅ Verify post belongs to topic owner
- ✅ Validate required data availability

## Logging Strategy

All logs use `${LOG_PREFIX}` prefix: `[Embedded Reply Buttons]`

**New log messages**:
- `Standard reply - not in owner mode, allowing default`
- `Standard reply - no post element found`
- `Standard reply - missing data`
- `Standard reply - not owner post, allowing default`
- `Standard reply intercepted for owner post #X`
- `Standard reply suppression active - preventing default scroll`
- `Opening reply to owner post #X`

## Files Modified

1. **`javascripts/discourse/api-initializers/embedded-reply-buttons.gjs`**
   - Add `standardReplyInterceptBound` flag
   - Add `suppressStandardReplyScroll` and `suppressedReplyPostNumber` flags
   - Extract `openReplyToOwnerPost()` function
   - Add standard reply interceptor listener
   - Refactor embedded button handler to use shared function
   - Add suppression consumption in `composer:saved`

## Estimated Lines of Code

- New function: ~30 lines
- New listener: ~50 lines
- Refactoring: ~5 lines changed
- Suppression consumption: ~5 lines
- **Total**: ~90 lines added/modified

## Next Steps

1. Implement Phase 1 (interceptor)
2. Implement Phase 2 (extract shared function)
3. Implement Phase 3 (suppression)
4. Test all scenarios
5. Document in user-facing docs

