# Owner Post Number Debugging and Fix

## Problem

The embedded reply button was not opening the composer when clicked because the `data-owner-post-number` attribute was not being set on the button during injection.

**Console Error:**
```
[Embedded Reply Buttons] Section-level reply button clicked
[Embedded Reply Buttons] Owner post number not found on button
```

## Root Cause Analysis

The issue could be caused by:

1. **Owner post element not found** - `getOwnerPostFromSection()` returning null
2. **Post number not extracted** - `extractPostNumberFromElement()` returning null/undefined
3. **DOM structure mismatch** - Section not properly nested in `article.topic-post`
4. **Timing issue** - Button injected before owner post is available

## Solution Implemented

### 1. Enhanced `getOwnerPostFromSection()` with Multiple Fallbacks

**Before:**
```javascript
function getOwnerPostFromSection(section) {
  if (!section) return null;
  return section.closest("article.topic-post");
}
```

**After:**
```javascript
function getOwnerPostFromSection(section) {
  if (!section) return null;
  
  // Try closest first (most reliable)
  let ownerPost = section.closest("article.topic-post");
  
  if (!ownerPost) {
    // Fallback 1: Try parent traversal
    let current = section.parentElement;
    while (current && current !== document.body) {
      if (current.matches && current.matches("article.topic-post")) {
        ownerPost = current;
        break;
      }
      current = current.parentElement;
    }
  }
  
  if (!ownerPost) {
    // Fallback 2: Try finding by data-post-number in parent chain
    let current = section.parentElement;
    while (current && current !== document.body) {
      if (current.dataset && current.dataset.postNumber) {
        ownerPost = current;
        break;
      }
      current = current.parentElement;
    }
  }
  
  return ownerPost;
}
```

**Benefits:**
- **Fallback 1**: Manual parent traversal if `closest()` fails
- **Fallback 2**: Finds any parent with `data-post-number` attribute
- More robust across different DOM structures

### 2. Added Section ID Fallback in Injection Function

If owner post element cannot be found, try extracting post number from section ID:

```javascript
// Fallback: Try to extract from section ID (e.g., "embedded-posts--123")
if (section.id) {
  const match = section.id.match(/--(\d+)$/);
  if (match) {
    ownerPostNumber = Number(match[1]);
    console.log(`${LOG_PREFIX} Extracted owner post number from section ID:`, ownerPostNumber);
  }
}
```

**Pattern:** `embedded-posts--{postNumber}` → extracts `{postNumber}`

### 3. Comprehensive Debugging Logs

#### During Injection (lines 161-204)

```javascript
console.log(`${LOG_PREFIX} Attempting to find owner post for section:`, section);
console.log(`${LOG_PREFIX} Section ID:`, section.id);
console.log(`${LOG_PREFIX} Section classes:`, section.className);
console.log(`${LOG_PREFIX} Owner post element:`, ownerPost);
console.log(`${LOG_PREFIX} Extracted owner post number from element:`, ownerPostNumber);

// If owner post found but no post number
console.warn(`${LOG_PREFIX} Could not extract post number from owner post element`);
console.warn(`${LOG_PREFIX} Owner post dataset:`, ownerPost.dataset);
console.warn(`${LOG_PREFIX} Owner post id:`, ownerPost.id);
console.warn(`${LOG_PREFIX} Owner post attributes:`, Array.from(ownerPost.attributes).map(a => `${a.name}="${a.value}"`));

// If owner post not found
console.warn(`${LOG_PREFIX} Could not find owner post element (article.topic-post) for section`);
console.warn(`${LOG_PREFIX} Section parent elements:`, section.parentElement, section.parentElement?.parentElement);

// Success
console.log(`${LOG_PREFIX} Successfully stored owner post number ${ownerPostNumber} on button`);
console.log(`${LOG_PREFIX} Button data-owner-post-number attribute:`, btn.dataset.ownerPostNumber);

// Critical failure
console.error(`${LOG_PREFIX} CRITICAL: Could not determine owner post number - button will not work!`);
```

#### During Click (lines 346-370)

```javascript
console.log(`${LOG_PREFIX} Section-level reply button clicked`);
console.log(`${LOG_PREFIX} Button element:`, btn);
console.log(`${LOG_PREFIX} Button dataset:`, btn.dataset);
console.log(`${LOG_PREFIX} Button data-owner-post-number:`, btn.dataset.ownerPostNumber);
console.log(`${LOG_PREFIX} Parsed owner post number:`, ownerPostNumber);

// If no owner post number
console.error(`${LOG_PREFIX} Owner post number not found on button`);
console.error(`${LOG_PREFIX} Button HTML:`, btn.outerHTML);
console.error(`${LOG_PREFIX} All button attributes:`, Array.from(btn.attributes).map(a => `${a.name}="${a.value}"`));
```

## Expected Console Output

### Successful Injection

```
[Embedded Reply Buttons] Attempting to find owner post for section: <section>
[Embedded Reply Buttons] Section ID: embedded-posts--123
[Embedded Reply Buttons] Section classes: embedded-posts
[Embedded Reply Buttons] Owner post element: <article class="topic-post" data-post-number="123">
[Embedded Reply Buttons] Extracted owner post number from element: 123
[Embedded Reply Buttons] Successfully stored owner post number 123 on button
[Embedded Reply Buttons] Button data-owner-post-number attribute: 123
[Embedded Reply Buttons] Button element after setting attribute: <button>
[Embedded Reply Buttons] Created button container and injected reply button
```

### Successful Click

```
[Embedded Reply Buttons] Section-level reply button clicked
[Embedded Reply Buttons] Button element: <button class="btn btn-small embedded-reply-button">
[Embedded Reply Buttons] Button dataset: {ownerPostNumber: "123"}
[Embedded Reply Buttons] Button data-owner-post-number: 123
[Embedded Reply Buttons] Parsed owner post number: 123
[Embedded Reply Buttons] Replying to owner post #123
[Embedded Reply Buttons] AutoRefresh: stored lastReplyContext
[Embedded Reply Buttons] Composer opened successfully
```

### Failure Scenarios

#### Owner Post Not Found

```
[Embedded Reply Buttons] Attempting to find owner post for section: <section>
[Embedded Reply Buttons] Section ID: embedded-posts--123
[Embedded Reply Buttons] Section classes: embedded-posts
[Embedded Reply Buttons] Owner post element: null
[Embedded Reply Buttons] Could not find owner post element (article.topic-post) for section
[Embedded Reply Buttons] Section parent elements: <div> <div>
[Embedded Reply Buttons] Extracted owner post number from section ID: 123
[Embedded Reply Buttons] Successfully stored owner post number 123 on button
```

#### Post Number Not Extracted

```
[Embedded Reply Buttons] Owner post element: <article class="topic-post">
[Embedded Reply Buttons] Extracted owner post number from element: null
[Embedded Reply Buttons] Could not extract post number from owner post element
[Embedded Reply Buttons] Owner post dataset: {}
[Embedded Reply Buttons] Owner post id: post_123
[Embedded Reply Buttons] Owner post attributes: ["class=topic-post", "id=post_123"]
```

#### Critical Failure

```
[Embedded Reply Buttons] CRITICAL: Could not determine owner post number - button will not work!
[Embedded Reply Buttons] Section: <section class="embedded-posts">
[Embedded Reply Buttons] Owner post: null
```

## Debugging Steps

1. **Check console logs** when expanding embedded posts
2. **Verify section structure** - Is it inside `article.topic-post`?
3. **Check section ID** - Does it follow pattern `embedded-posts--{number}`?
4. **Inspect owner post** - Does it have `data-post-number` attribute?
5. **Verify button attributes** - Does button have `data-owner-post-number`?

## Testing Checklist

- [ ] Expand embedded posts section
- [ ] Check console for injection logs
- [ ] Verify "Successfully stored owner post number X" message
- [ ] Click Reply button
- [ ] Check console for click logs
- [ ] Verify "Replying to owner post #X" message
- [ ] Verify composer opens
- [ ] Verify composer is set to reply to correct post

## Files Modified

1. **`javascripts/discourse/api-initializers/embedded-reply-buttons.gjs`**
   - Lines 57-89: Enhanced `getOwnerPostFromSection()` with fallbacks
   - Lines 161-204: Added comprehensive debugging and section ID fallback
   - Lines 346-370: Added detailed click handler debugging

## Rollback Plan

If the enhanced debugging causes performance issues, you can:
1. Remove the verbose `console.log()` statements
2. Keep the fallback logic in `getOwnerPostFromSection()`
3. Keep the section ID fallback in the injection function

The core functionality improvements (fallbacks) should remain.

