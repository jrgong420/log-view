# Standard Reply Button Interception - Flow Diagram

## Current State: Two Different Behaviors

### Embedded Reply Button (Working)
```
User clicks .embedded-reply-button
         ↓
Delegated listener intercepts (capture phase)
         ↓
Extract ownerPostNumber from btn.dataset
         ↓
Store lastReplyContext { topicId, parentPostNumber, ownerPostNumber }
         ↓
Open composer with skipJumpOnSave: true
         ↓
User submits reply
         ↓
post:created event → Store lastCreatedPost
         ↓
composer:saved event → Find owner post element
         ↓
Click "load more replies" button
         ↓
Try immediate scroll → Found? → YES → Scroll + Highlight → Done
         ↓ NO
Set up MutationObserver
         ↓
Wait for new post to render (max 10s)
         ↓
Post appears → Scroll + Highlight → Done
```

### Standard Reply Button (Current - Inconsistent)
```
User clicks button.post-action-menu__reply
         ↓
Default Discourse behavior
         ↓
Composer opens normally
         ↓
User submits reply
         ↓
post:created event → Default handling
         ↓
Scroll to new post in MAIN STREAM ❌
         ↓
New post NOT in embedded section ❌
         ↓
User loses filtered view context ❌
```

## Proposed State: Unified Behavior

### Standard Reply Button (After Implementation)
```
User clicks button.post-action-menu__reply
         ↓
Delegated listener intercepts (capture phase)
         ↓
Guard 1: Check isOwnerCommentMode === "true"
         ↓ NO → Allow default behavior
         ↓ YES
Guard 2: Find post element
         ↓ NOT FOUND → Allow default behavior
         ↓ FOUND
Guard 3: Check if post belongs to topic owner
         ↓ NO → Allow default behavior
         ↓ YES
Prevent default (e.preventDefault, e.stopPropagation)
         ↓
Set suppressStandardReplyScroll = true
         ↓
Call openReplyToOwnerPost(topic, post, postNumber)
         ↓
[SAME AS EMBEDDED BUTTON FROM HERE]
         ↓
Store lastReplyContext { topicId, parentPostNumber, ownerPostNumber }
         ↓
Open composer with skipJumpOnSave: true
         ↓
User submits reply
         ↓
post:created event → Store lastCreatedPost
         ↓
composer:saved event → Consume suppressStandardReplyScroll flag
         ↓
Find owner post element
         ↓
Click "load more replies" button
         ↓
Try immediate scroll → Found? → YES → Scroll + Highlight → Done
         ↓ NO
Set up MutationObserver
         ↓
Wait for new post to render (max 10s)
         ↓
Post appears → Scroll + Highlight → Done
```

## Guard Logic Detail

### Guard 1: Owner Comment Mode Check
```javascript
const isOwnerCommentMode = document.body.dataset.ownerCommentMode === "true";
if (!isOwnerCommentMode) {
  // Not in filtered view - allow default
  return;
}
```

**Why**: Only intercept when filtered view is active

### Guard 2: Post Element Lookup
```javascript
const postElement = btn.closest("article.topic-post");
if (!postElement) {
  // Can't determine which post - allow default
  return;
}
```

**Why**: Need to identify which post the reply button belongs to

### Guard 3: Owner Post Verification
```javascript
const topic = api.container.lookup("controller:topic")?.model;
const topicOwnerId = topic?.details?.created_by?.id;
const postNumber = extractPostNumberFromElement(postElement);
const post = topic.postStream?.posts?.find(p => p.post_number === postNumber);
const isOwnerPost = post?.user_id === topicOwnerId;

if (!isOwnerPost) {
  // Non-owner post - allow default
  return;
}
```

**Why**: Only intercept replies to topic owner's posts

## Shared Function: openReplyToOwnerPost()

### Purpose
Centralize composer opening logic used by both:
- Embedded reply button
- Standard reply button (when intercepted)

### Signature
```javascript
async function openReplyToOwnerPost(topic, ownerPost, ownerPostNumber)
```

### Parameters
- `topic`: Topic model from controller
- `ownerPost`: Post model (may be null)
- `ownerPostNumber`: Post number to reply to

### Behavior
1. Lookup composer service
2. Build composer options with `skipJumpOnSave: true`
3. Store `lastReplyContext` for auto-refresh
4. Add post model or replyToPostNumber
5. Open composer

### Return
Promise that resolves when composer opens

## State Management

### Module-Scoped Variables

```javascript
// Existing
let globalClickHandlerBound = false;
let showRepliesClickHandlerBound = false;
let composerEventsBound = false;
let lastReplyContext = { topicId: null, parentPostNumber: null };
let lastCreatedPost = null;

// New
let standardReplyInterceptBound = false;
let suppressStandardReplyScroll = false;
let suppressedReplyPostNumber = null;
```

### State Lifecycle

**Set**:
- When standard reply button clicked on owner post in filtered view
- Before opening composer

**Consumed**:
- In `composer:saved` event handler
- Immediately cleared after consumption

**Purpose**:
- One-shot suppression to prevent default scroll behavior
- Ensures embedded refresh logic runs instead

## Event Flow Comparison

### Before (Inconsistent)

| Event | Embedded Button | Standard Button |
|-------|----------------|-----------------|
| Click | Custom handler | Default handler |
| Composer Open | skipJumpOnSave: true | Default |
| post:created | Store lastCreatedPost | Default |
| composer:saved | Refresh embedded section | Default scroll |
| Result | ✅ Stays in filtered view | ❌ Loses context |

### After (Unified)

| Event | Embedded Button | Standard Button (Owner Post) | Standard Button (Non-Owner) |
|-------|----------------|------------------------------|----------------------------|
| Click | Custom handler | Custom handler (intercepted) | Default handler |
| Composer Open | skipJumpOnSave: true | skipJumpOnSave: true | Default |
| post:created | Store lastCreatedPost | Store lastCreatedPost | Default |
| composer:saved | Refresh embedded section | Refresh embedded section | Default scroll |
| Result | ✅ Stays in filtered view | ✅ Stays in filtered view | ✅ Default behavior |

## Code Organization

### File: embedded-reply-buttons.gjs

```
Lines 1-15:    Module-scoped variables (existing + new)
Lines 16-200:  Helper functions (existing)
Lines 201-450: Button injection logic (existing)
Lines 451-560: Embedded button click handler (refactored)
Lines 561-625: Show replies click handler (existing)
Lines 626-675: Page change handler (existing)
Lines 676-943: Composer events (modified)

NEW SECTIONS:
Lines XXX-XXX: openReplyToOwnerPost() function
Lines XXX-XXX: Standard reply interceptor
```

### Modification Points

1. **Add module variables** (top of file)
2. **Extract openReplyToOwnerPost()** (after helper functions)
3. **Refactor embedded button handler** (use shared function)
4. **Add standard reply interceptor** (after show replies handler)
5. **Modify composer:saved** (add suppression consumption)

## Testing Matrix

| Scenario | Button Type | Filtered View | Post Owner | Expected Behavior |
|----------|-------------|---------------|------------|-------------------|
| 1 | Embedded | Yes | Owner | ✅ Embedded refresh (existing) |
| 2 | Standard | Yes | Owner | ✅ Embedded refresh (NEW) |
| 3 | Standard | Yes | Non-owner | ✅ Default behavior |
| 4 | Standard | No | Owner | ✅ Default behavior |
| 5 | Standard | No | Non-owner | ✅ Default behavior |
| 6 | Embedded | No | N/A | N/A (button not shown) |

## Success Criteria

### Functional
- ✅ Standard reply to owner post in filtered view behaves like embedded button
- ✅ Standard reply to non-owner post uses default behavior
- ✅ Standard reply outside filtered view uses default behavior
- ✅ Embedded button behavior unchanged (regression test)

### Technical
- ✅ No duplicate event listeners
- ✅ No memory leaks
- ✅ SPA-safe (survives navigation)
- ✅ One-shot suppression flags work correctly
- ✅ Comprehensive logging for debugging

### User Experience
- ✅ Consistent reply behavior regardless of button used
- ✅ No unexpected scrolling
- ✅ New posts appear in correct location
- ✅ Auto-scroll and highlight work
- ✅ No visual glitches or delays

## Rollback Plan

If issues arise:

1. **Remove standard reply interceptor**:
   - Comment out the new delegated listener
   - Remove suppression flag consumption

2. **Revert shared function extraction**:
   - Inline the logic back into embedded button handler

3. **Test embedded button still works**:
   - Verify existing functionality intact

4. **Document issues**:
   - Capture console logs
   - Note specific failure scenarios
   - Report to development team

