# Quick Implementation Guide - Standard Reply Button Interception

## TL;DR

**What**: Make standard reply button behave like embedded reply button in filtered view  
**Where**: `javascripts/discourse/api-initializers/embedded-reply-buttons.gjs`  
**How**: Add interceptor + shared function + suppression handling  
**Lines**: ~81 net lines added  

## 5-Step Implementation

### Step 1: Add Module Variables (Top of file, after line 15)

```javascript
let standardReplyInterceptBound = false;
let suppressStandardReplyScroll = false;
let suppressedReplyPostNumber = null;
```

### Step 2: Add Shared Function (After helper functions, ~line 200)

```javascript
async function openReplyToOwnerPost(topic, ownerPost, ownerPostNumber) {
  console.log(`${LOG_PREFIX} Opening reply to owner post #${ownerPostNumber}`);
  const composer = api.container.lookup("service:composer");
  if (!composer) return;
  
  const composerOptions = {
    action: "reply",
    topic: topic,
    draftKey: topic.draft_key,
    draftSequence: topic.draft_sequence,
    skipJumpOnSave: true,
  };
  
  lastReplyContext = { topicId: topic.id, parentPostNumber: ownerPostNumber, ownerPostNumber };
  console.log(`${LOG_PREFIX} Stored lastReplyContext`, lastReplyContext);
  
  if (ownerPost) {
    composerOptions.post = ownerPost;
  } else {
    composerOptions.replyToPostNumber = ownerPostNumber;
  }
  
  await composer.open(composerOptions);
  console.log(`${LOG_PREFIX} Composer opened successfully`);
}
```

### Step 3: Refactor Embedded Handler (Lines 534-552)

**Replace this**:
```javascript
const composerOptions = { ... };
lastReplyContext = { ... };
if (ownerPost) { ... }
await composer.open(composerOptions);
```

**With this**:
```javascript
await openReplyToOwnerPost(topic, ownerPost, ownerPostNumber);
```

### Step 4: Add Standard Reply Interceptor (After line 625)

```javascript
if (!standardReplyInterceptBound) {
  document.addEventListener("click", async (e) => {
    const btn = e.target?.closest?.("button.post-action-menu__reply");
    if (!btn) return;
    
    const isOwnerCommentMode = document.body.dataset.ownerCommentMode === "true";
    if (!isOwnerCommentMode) return;
    
    const postElement = btn.closest("article.topic-post");
    if (!postElement) return;
    
    const topic = api.container.lookup("controller:topic")?.model;
    const topicOwnerId = topic?.details?.created_by?.id;
    const postNumber = extractPostNumberFromElement(postElement);
    if (!postNumber || !topic || !topicOwnerId) return;
    
    const post = topic.postStream?.posts?.find(p => p.post_number === postNumber);
    const isOwnerPost = post?.user_id === topicOwnerId;
    if (!isOwnerPost) return;
    
    console.log(`${LOG_PREFIX} Standard reply intercepted for owner post #${postNumber}`);
    e.preventDefault();
    e.stopPropagation();
    
    suppressStandardReplyScroll = true;
    suppressedReplyPostNumber = postNumber;
    
    try {
      await openReplyToOwnerPost(topic, post, postNumber);
    } catch (error) {
      console.error(`${LOG_PREFIX} Error:`, error);
      suppressStandardReplyScroll = false;
      suppressedReplyPostNumber = null;
    }
  }, true);
  
  standardReplyInterceptBound = true;
}
```

### Step 5: Add Suppression Consumption (In composer:saved, ~line 710)

**Add after line 712**:
```javascript
if (suppressStandardReplyScroll) {
  console.log(`${LOG_PREFIX} Standard reply suppression active`);
  suppressStandardReplyScroll = false;
  suppressedReplyPostNumber = null;
}
```

## Testing Checklist

### ✅ Test 1: Standard Reply to Owner (Filtered View)
1. Navigate to topic in filtered view
2. Click standard reply button on owner's post
3. **Expected**: Composer opens, reply appears in embedded section, auto-scroll works

### ✅ Test 2: Standard Reply to Non-Owner (Filtered View)
1. Navigate to topic in filtered view
2. Click standard reply button on non-owner's post
3. **Expected**: Default Discourse behavior (no interception)

### ✅ Test 3: Standard Reply (Unfiltered View)
1. Navigate to topic without filter
2. Click standard reply button
3. **Expected**: Default Discourse behavior (no interception)

### ✅ Test 4: Embedded Button (Regression)
1. Navigate to topic in filtered view
2. Click embedded reply button
3. **Expected**: Existing behavior unchanged

### ✅ Test 5: Console Logs
Check for these messages:
- `[Embedded Reply Buttons] Standard reply intercepted for owner post #X`
- `[Embedded Reply Buttons] Standard reply suppression active`
- `[Embedded Reply Buttons] Opening reply to owner post #X`

## Common Issues & Solutions

### Issue: Interceptor not firing
**Check**: 
- `document.body.dataset.ownerCommentMode === "true"`
- Button selector matches: `button.post-action-menu__reply`
- Console shows guard messages

### Issue: Default behavior still happens
**Check**:
- `e.preventDefault()` and `e.stopPropagation()` are called
- Listener uses capture phase (`true` as third argument)
- Guards are passing (check console logs)

### Issue: Composer doesn't open
**Check**:
- `openReplyToOwnerPost()` function is defined
- Composer service is available
- Try-catch is logging errors

### Issue: Auto-scroll doesn't work
**Check**:
- Suppression flag is being consumed in `composer:saved`
- `lastReplyContext` is being stored
- Existing auto-scroll logic is intact

## Rollback

If issues occur, comment out:

1. **Step 4** (standard reply interceptor)
2. **Step 5** (suppression consumption)
3. **Step 1** (module variables)

Keep Steps 2 & 3 (shared function is useful).

## File Locations

- **Main file**: `javascripts/discourse/api-initializers/embedded-reply-buttons.gjs`
- **Documentation**: 
  - `docs/STANDARD_REPLY_BUTTON_INTERCEPTION_PLAN.md`
  - `docs/STANDARD_REPLY_INTERCEPTION_FLOW.md`
  - `docs/STANDARD_REPLY_INTERCEPTION_CODE.md`
  - `IMPLEMENTATION_PLAN_SUMMARY.md`

## Key Concepts

### Four-Guard System
1. **Owner mode check**: Only intercept in filtered view
2. **Post element check**: Must find the post container
3. **Data availability check**: Topic and owner ID must exist
4. **Owner post check**: Post must belong to topic owner

### One-Shot Suppression
- Set flag before opening composer
- Consume flag in `composer:saved`
- Clear flag after consumption
- Prevents default scroll behavior

### Shared Function Pattern
- Extract common logic into `openReplyToOwnerPost()`
- Reuse for both button types
- Maintains consistency
- Easier to maintain

## Success Indicators

✅ Standard reply to owner post in filtered view:
- Opens composer with correct context
- New post appears in embedded section
- Auto-scroll and highlight work
- No scroll to main stream

✅ Standard reply to non-owner post:
- Default Discourse behavior
- No interception

✅ No regressions:
- Embedded button still works
- Unfiltered view unchanged
- No console errors

## Estimated Time

- **Implementation**: 30-45 minutes
- **Testing**: 45-60 minutes
- **Total**: 1.5-2 hours

## Support

If you encounter issues:
1. Check console logs for guard messages
2. Verify all five steps completed
3. Test each scenario from checklist
4. Review detailed docs in `docs/` folder
5. Use rollback instructions if needed

