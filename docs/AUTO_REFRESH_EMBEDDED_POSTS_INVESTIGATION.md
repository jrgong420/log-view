# Auto-Refresh Embedded Posts After Reply - Investigation

## Problem Statement

When a user submits a reply via the embedded reply button in filtered view:
- ✅ Post is created successfully on the server
- ❌ New reply is NOT visible until user manually clicks "load more replies" or refreshes page
- ❌ A "load more replies" button appears but requires manual interaction

## Goal

Automatically refresh/reload the embedded posts section after a reply is submitted so the new post appears immediately.

## Investigation Findings

### 1. Discourse Composer Events

**Potential Events to Listen For:**
- `appEvents.on("composer:saved")` - Fires after post is successfully saved
- `appEvents.on("composer:closed")` - Fires when composer closes
- `appEvents.on("post-stream:posted")` - Fires when a new post is added to stream

**Access Pattern:**
```javascript
const appEvents = api.container.lookup("service:app-events");
appEvents.on("composer:saved", (post) => {
  // post contains the newly created post data
});
```

### 2. Load More Replies Button

**DOM Structure:**
```html
<button class="widget-button btn load-more-replies btn-text">
  <span class="d-button-label">load more replies</span>
</button>
```

**Location:** Inside `section.embedded-posts`

**Programmatic Click:**
```javascript
const loadMoreBtn = section.querySelector(".load-more-replies");
if (loadMoreBtn) {
  loadMoreBtn.click();
}
```

### 3. Post Stream Refresh

**Alternative Approach:** Instead of clicking the button, we could:
1. Find the parent post element
2. Trigger a refresh of its embedded posts section
3. Use Discourse's internal post stream methods

**Potential Methods:**
```javascript
// Get the topic controller
const topicController = api.container.lookup("controller:topic");
const topic = topicController?.model;

// Refresh post stream
topic.postStream.refresh();

// Or reload specific posts
topic.postStream.loadPostByPostNumber(postNumber);
```

## Implementation Approaches

### Approach 1: Listen to Composer Events + Click "Load More"

**Pros:**
- Uses existing Discourse UI mechanism
- Minimal custom code
- Leverages Discourse's built-in refresh logic

**Cons:**
- Relies on button being present
- May not work if button hasn't rendered yet
- Simulates user interaction (less clean)

**Implementation:**
```javascript
const appEvents = api.container.lookup("service:app-events");

appEvents.on("composer:saved", (post) => {
  // Check if we're in owner comment mode
  const isOwnerCommentMode = document.body.dataset.ownerCommentMode === "true";
  if (!isOwnerCommentMode) return;
  
  // Find the embedded posts section for the parent post
  const parentPostNumber = post.reply_to_post_number;
  if (!parentPostNumber) return;
  
  const parentPostElement = document.querySelector(
    `article.topic-post[data-post-number="${parentPostNumber}"]`
  );
  
  if (parentPostElement) {
    schedule("afterRender", () => {
      const embeddedSection = parentPostElement.querySelector("section.embedded-posts");
      const loadMoreBtn = embeddedSection?.querySelector(".load-more-replies");
      
      if (loadMoreBtn) {
        loadMoreBtn.click();
      }
    });
  }
});
```

### Approach 2: Use MutationObserver to Detect "Load More" Button

**Pros:**
- Waits for button to appear before clicking
- More reliable timing
- Handles async rendering

**Cons:**
- More complex
- Requires observer management

**Implementation:**
```javascript
appEvents.on("composer:saved", (post) => {
  const parentPostNumber = post.reply_to_post_number;
  if (!parentPostNumber) return;
  
  const parentPostElement = document.querySelector(
    `article.topic-post[data-post-number="${parentPostNumber}"]`
  );
  
  if (parentPostElement) {
    const observer = new MutationObserver((mutations) => {
      const loadMoreBtn = parentPostElement.querySelector(
        "section.embedded-posts .load-more-replies"
      );
      
      if (loadMoreBtn) {
        loadMoreBtn.click();
        observer.disconnect();
      }
    });
    
    observer.observe(parentPostElement, {
      childList: true,
      subtree: true
    });
    
    // Timeout to prevent infinite observation
    setTimeout(() => observer.disconnect(), 5000);
  }
});
```

### Approach 3: Direct Post Stream Manipulation

**Pros:**
- Most direct approach
- No reliance on UI buttons
- Cleanest from architecture perspective

**Cons:**
- Requires deep knowledge of Discourse internals
- May break with Discourse updates
- More complex implementation

**Implementation:**
```javascript
appEvents.on("composer:saved", (post) => {
  const topic = api.container.lookup("controller:topic")?.model;
  if (!topic) return;
  
  // Reload the post stream to include new post
  topic.postStream.refresh();
  
  // Or more targeted: reload specific post's replies
  const parentPostNumber = post.reply_to_post_number;
  if (parentPostNumber) {
    // Find parent post in stream
    const parentPost = topic.postStream.posts.find(
      p => p.post_number === parentPostNumber
    );
    
    if (parentPost) {
      // Trigger reload of embedded posts for this post
      // (Need to investigate exact method)
    }
  }
});
```

## Recommended Approach

**Start with Approach 1** (Composer Event + Click "Load More"):
- Simplest to implement
- Uses existing Discourse mechanisms
- Easy to test and debug
- Can be enhanced later if needed

**Enhancement with Approach 2** if timing issues occur:
- Add MutationObserver to wait for button
- Provides more reliable timing
- Still uses Discourse's built-in refresh logic

## Implementation Plan

1. **Add composer event listener** in `embedded-reply-buttons.gjs`
2. **Detect when reply is submitted** via `composer:saved` event
3. **Find the parent post element** using `reply_to_post_number`
4. **Locate the "load more replies" button** in embedded posts section
5. **Programmatically click the button** to refresh embedded posts
6. **Add safeguards**:
   - Only trigger in owner comment mode
   - Check if button exists before clicking
   - Use `schedule("afterRender")` for timing
   - Add timeout to prevent infinite waiting

## Testing Checklist

- [ ] Reply button click opens composer correctly
- [ ] Submit reply creates post successfully
- [ ] Embedded posts section refreshes automatically
- [ ] New reply appears without manual interaction
- [ ] Works when "load more" button is already present
- [ ] Works when "load more" button appears after delay
- [ ] Doesn't break normal (non-filtered) view
- [ ] Doesn't cause duplicate refreshes
- [ ] Handles edge cases (no parent post, etc.)

## Next Steps

1. Implement Approach 1 in `embedded-reply-buttons.gjs`
2. Test in development environment
3. Add logging for debugging
4. Refine based on test results
5. Consider Approach 2 if timing issues occur
6. Remove logging for production
7. Document the solution

