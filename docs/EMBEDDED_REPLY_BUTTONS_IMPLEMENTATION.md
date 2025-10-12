# Embedded Reply Buttons - Implementation Documentation

## Overview

This document provides technical details about the implementation of the embedded reply buttons feature for the log-view theme component.

## Feature Requirements

1. Add "Reply" buttons to posts displayed in `section.embedded-posts` when in filtered view
2. Open the Discourse composer programmatically when clicked
3. Pre-populate the composer with correct reply context (replying to the parent owner's post)
4. Keep the user on the filtered view page (no navigation)
5. Maintain filtered view after posting the reply

## Architecture

### File Structure

```
javascripts/discourse/api-initializers/
  └── embedded-reply-buttons.gjs    # Main feature implementation

common/
  └── common.scss                    # Styling for reply buttons

docs/
  ├── EMBEDDED_REPLY_BUTTONS_IMPLEMENTATION.md  # This file
  └── EMBEDDED_REPLY_BUTTONS_TESTING.md         # Testing guide
```

### Key Components

1. **API Initializer**: `embedded-reply-buttons.gjs`
   - Registers with Discourse Plugin API v1.14.0+
   - Sets up global event delegation for button clicks
   - Injects buttons into embedded posts on page changes

2. **Styling**: `common/common.scss`
   - Styles for `.embedded-reply-button`
   - Layout adjustments for embedded post sections

## Implementation Details

### 1. Initialization

```javascript
export default apiInitializer("1.14.0", (api) => {
  // Setup code
});
```

The initializer requires Discourse Plugin API version 1.14.0 or higher.

### 2. Global Click Handler (Event Delegation)

**Why Event Delegation?**
- Discourse is a Single Page Application (SPA) using Ember.js
- DOM elements are frequently re-rendered during route changes
- Direct event binding would create memory leaks and duplicate handlers
- Event delegation binds once at the document level and handles all clicks

**Implementation**:
```javascript
let globalClickHandlerBound = false;

if (!globalClickHandlerBound) {
  document.addEventListener("click", async (e) => {
    const btn = e.target?.closest?.(".embedded-reply-button");
    if (!btn) return;
    
    // Handle click
  }, true); // Use capture phase
  
  globalClickHandlerBound = true;
}
```

**Key Points**:
- Uses `closest()` to handle clicks on button or its children
- Capture phase (`true`) ensures early event handling
- Idempotent flag prevents duplicate bindings
- Async handler allows for dynamic imports

### 3. Button Injection

**Trigger**: `api.onPageChange()`
- Fires on every route change in the SPA
- Provides URL and title of the new page

**Timing**: `schedule("afterRender", ...)`
- Ensures DOM is fully rendered before manipulation
- Part of Ember's run loop system
- Prevents race conditions with DOM updates

**Detection Logic**:
```javascript
const isOwnerCommentMode = document.body.dataset.ownerCommentMode === "true";
```
- Only inject buttons when in filtered view
- Relies on `owner-comment-prototype.gjs` setting this data attribute

**Injection Process**:
1. Find all `section.embedded-posts` elements
2. For each section, find all `.embedded-post` items
3. Check if button already injected (`data-reply-btn-bound`)
4. Create and append button element
5. Mark as bound to prevent duplicates

**Button Placement Strategy**:
```javascript
const postActions = item.querySelector(".post-actions");
const postInfo = item.querySelector(".post-info");

if (postActions) {
  postActions.appendChild(btn);
} else if (postInfo) {
  postInfo.appendChild(btn);
} else {
  item.appendChild(btn);
}
```
- Tries to place button in logical locations
- Falls back to appending directly to item

### 4. Opening the Composer

**Service Lookup**:
```javascript
const topic = api.container.lookup("controller:topic")?.model;
const composer = api.container.lookup("service:composer");
```
- Uses Ember's dependency injection container
- `controller:topic` provides the current topic model
- `service:composer` provides the composer service

**Finding the Parent Post**:
```javascript
const postContainer = btn.closest("article.topic-post");
const postNumber = postContainer.dataset.postNumber;
const parentPost = topic.postStream?.posts?.find(
  (p) => p.post_number === Number(postNumber)
);
```
- Traverses DOM to find parent post container
- Reads post number from data attribute
- Looks up full post model from topic's post stream

**Composer Options**:
```javascript
await composer.open({
  action: Composer.REPLY,      // Reply action
  topic: topic,                 // Current topic
  post: parentPost,             // Post to reply to
  draftKey: topic.draft_key,    // Required for drafts
  draftSequence: topic.draft_sequence,  // Required for drafts
  skipJumpOnSave: true,         // Don't navigate after posting
});
```

**Key Options Explained**:
- `action: Composer.REPLY`: Sets composer to reply mode
- `post: parentPost`: Sets the reply-to context
- `skipJumpOnSave: true`: Prevents auto-navigation to new post after saving
- `draftKey` and `draftSequence`: Required by Discourse for draft management

### 5. Maintaining Filtered View

**During Composer Opening**:
- Composer opens as an overlay, no navigation occurs
- URL remains unchanged (keeps `?username_filters=...`)

**After Posting**:
- `skipJumpOnSave: true` prevents automatic navigation
- If Discourse does navigate, it uses `keepFilter: true` by default
- This preserves the `username_filters` query parameter

## Design Patterns Used

### 1. SPA Event Binding Pattern

**Problem**: DOM elements are re-rendered frequently in SPAs
**Solution**: Event delegation at document level
**Reference**: `.augment/rules/core/spa-event-binding.md`

### 2. Redirect Loop Avoidance

**Problem**: Programmatic navigation can cause infinite loops
**Solution**: Guard conditions and state checks
**Reference**: `.augment/rules/core/redirect-loop-avoidance.md`

### 3. Idempotent Operations

**Problem**: Code may run multiple times due to SPA lifecycle
**Solution**: Check state before performing actions
**Implementation**: `data-reply-btn-bound` flag, `globalClickHandlerBound` flag

## Error Handling

The implementation includes comprehensive error checking:

1. **Missing Topic Model**:
   ```javascript
   if (!topic) {
     console.error(`${LOG_PREFIX} No topic model found`);
     return;
   }
   ```

2. **Missing Composer Service**:
   ```javascript
   if (!composer) {
     console.error(`${LOG_PREFIX} No composer service found`);
     return;
   }
   ```

3. **Missing Post Container**:
   ```javascript
   if (!postContainer) {
     console.error(`${LOG_PREFIX} No parent post container found`);
     return;
   }
   ```

4. **Post Model Not Found**:
   ```javascript
   if (!parentPost) {
     console.error(`${LOG_PREFIX} Could not find post model for post number ${postNumber}`);
     console.log(`${LOG_PREFIX} Available posts:`, topic.postStream?.posts?.map((p) => p.post_number));
     return;
   }
   ```

5. **Composer Opening Errors**:
   ```javascript
   try {
     await composer.open({ ... });
   } catch (error) {
     console.error(`${LOG_PREFIX} Error opening composer:`, error);
   }
   ```

## Logging Strategy

All logs are prefixed with `[Embedded Reply Buttons]` for easy filtering.

**Log Levels**:
- `console.log()`: Normal operation, state changes, success messages
- `console.error()`: Errors, missing data, failed operations

**Key Logged Information**:
- Initialization status
- Page change events
- Button injection progress
- Click events
- Composer opening parameters
- Error details with context

## Performance Considerations

1. **Single Event Listener**: Only one click handler for all buttons
2. **Lazy Import**: Composer model is imported only when needed
3. **Early Returns**: Guards exit early if conditions aren't met
4. **Idempotent Checks**: Prevents redundant DOM manipulation

## Browser Compatibility

- Uses modern JavaScript features (async/await, optional chaining)
- Requires ES2020+ support
- Compatible with all browsers supported by Discourse

## Dependencies

### Discourse Core
- Plugin API v1.14.0+
- Composer service
- Composer model
- Topic controller
- Ember run loop (`@ember/runloop`)

### Theme Component
- `owner-comment-prototype.gjs`: Sets `ownerCommentMode` data attribute
- Common SCSS: Provides base styling

## Future Enhancements

Potential improvements for future versions:

1. **Reply to Nested Replies**: Currently replies to parent owner post; could support replying to the embedded post itself
2. **Keyboard Shortcuts**: Add keyboard support for accessibility
3. **Button Customization**: Allow theme settings to customize button text/icon
4. **Animation**: Add subtle animations for button appearance
5. **Loading State**: Show loading indicator while composer opens
6. **Quote Integration**: Support quoting embedded post content

## Testing

See `EMBEDDED_REPLY_BUTTONS_TESTING.md` for comprehensive testing procedures.

## Troubleshooting

### Buttons Not Appearing

**Check**:
1. Is `ownerCommentMode` set? `document.body.dataset.ownerCommentMode`
2. Are there embedded posts? `document.querySelectorAll('section.embedded-posts')`
3. Console errors?

**Common Causes**:
- Not in filtered view
- No embedded posts in current topic
- JavaScript error preventing initialization

### Composer Not Opening

**Check**:
1. Console logs for error messages
2. Topic model availability
3. Composer service availability
4. Post model lookup success

**Common Causes**:
- Topic not fully loaded
- Post number mismatch
- Composer service not available

### Wrong Reply Context

**Check**:
1. Parent post number in console
2. Post model in topic.postStream.posts
3. Reply indicator in composer

**Common Causes**:
- DOM structure different than expected
- Post number not found in data attribute
- Post stream not fully loaded

## References

- [Discourse Plugin API](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/plugin-api.gjs)
- [Composer Service](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js)
- [Composer Model](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/models/composer.js)
- [Meta: Opening Composer Without Changing Route](https://meta.discourse.org/t/67710)

