# Logger Usage Examples

This document provides practical examples of using the centralized logger utility.

---

## Basic Setup

```javascript
import { createLogger } from "../lib/logger";

// Create a logger instance with your feature prefix
const log = createLogger("[Owner View] [Feature Name]");
```

---

## Example 1: Simple Logging

```javascript
// Debug-level (only when debug_logging_enabled = true)
log.debug("Processing topic", { topicId: 123, categoryId: 5 });

// Info-level (only when debug_logging_enabled = true)
log.info("Composer opened successfully");

// Warning (only when debug_logging_enabled = true)
log.warn("Owner username not available yet", { topic: topic });

// Error (ALWAYS logged, even when debug disabled)
log.error("Failed to open composer", error);
```

---

## Example 2: Structured Context Objects

```javascript
// State snapshot
log.info("Current state", {
  topicId: topic.id,
  categoryId: topic.category_id,
  ownerUsername: topic.details?.created_by?.username,
  currentFilter: url.searchParams.get("username_filters"),
  isFiltered: document.body.dataset.ownerCommentMode === "true"
});

// Guard evaluation
log.debug("Guard: Check if already filtered", {
  urlParam: currentFilter,
  uiIndicator: hasFilteredNotice,
  result: currentFilter || hasFilteredNotice ? "SKIP" : "PROCEED"
});
```

---

## Example 3: Grouped Logging

```javascript
// Standard group (expanded by default)
log.group("Reply Button Click Flow");
log.info("Event target:", e.target);
log.info("Owner post number:", ownerPostNumber);
log.info("Composer options:", composerOptions);
log.groupEnd();

// Collapsed group (less noisy)
log.groupCollapsed("Auto-Refresh Details");
log.debug("Parent post number:", parentPostNumber);
log.debug("Section found:", !!section);
log.debug("Is collapsed:", isCollapsed);
log.groupEnd();
```

---

## Example 4: Performance Timing

```javascript
// Simple timing
log.time("Refresh Operation");
await refreshEmbeddedPosts();
log.timeEnd("Refresh Operation");
// Output: [Owner View] [Feature Name] Refresh Operation: 234.56ms

// Timing with intermediate logs
log.time("Auto-Refresh: Expand + Load + Scroll");

await expandEmbeddedReplies(ownerPostElement);
log.timeLog("Auto-Refresh: Expand + Load + Scroll", "Expansion complete");

await loadAllEmbeddedReplies(ownerPostElement);
log.timeLog("Auto-Refresh: Expand + Load + Scroll", "Loading complete");

tryScrollToNewReply(section);
log.timeEnd("Auto-Refresh: Expand + Load + Scroll");

// Output:
// [Owner View] [Feature Name] Auto-Refresh: Expand + Load + Scroll: 123.45ms Expansion complete
// [Owner View] [Feature Name] Auto-Refresh: Expand + Load + Scroll: 456.78ms Loading complete
// [Owner View] [Feature Name] Auto-Refresh: Expand + Load + Scroll: 567.89ms
```

---

## Example 5: Rate-Limited Logging

```javascript
// High-frequency event (e.g., MutationObserver callback)
observer.observe(element, {
  childList: true,
  subtree: true
});

const observer = new MutationObserver((mutations) => {
  // This might fire dozens of times per second
  // Throttle to max 1 log per 2 seconds
  log.debugThrottled("MutationObserver: Mutations detected", {
    count: mutations.length
  });
});

// Custom throttle duration
log.debugThrottled("Scroll event", { throttleMs: 500 }, { scrollY: window.scrollY });
```

---

## Example 6: Table Logging

```javascript
// Display structured data as a table
const posts = [
  { postNumber: 1, author: "alice", isOwner: true },
  { postNumber: 2, author: "bob", isOwner: false },
  { postNumber: 3, author: "alice", isOwner: true }
];

log.table(posts);

// Output:
// [Owner View] [Feature Name]
// ┌─────────┬────────────┬────────┬─────────┐
// │ (index) │ postNumber │ author │ isOwner │
// ├─────────┼────────────┼────────┼─────────┤
// │    0    │     1      │ alice  │  true   │
// │    1    │     2      │  bob   │  false  │
// │    2    │     3      │ alice  │  true   │
// └─────────┴────────────┴────────┴─────────┘
```

---

## Example 7: Complete Flow (Embedded Reply Buttons)

```javascript
import { createLogger } from "../lib/logger";

const log = createLogger("[Owner View] [Embedded Reply Buttons]");

// Page change
api.onPageChange((url) => {
  log.info("Page changed", { url });
  
  schedule("afterRender", () => {
    const isOwnerMode = document.body.dataset.ownerCommentMode === "true";
    
    log.debug("Checking for embedded sections", {
      isOwnerMode,
      bodyClass: document.body.className
    });
    
    if (!isOwnerMode) {
      log.debug("Not in owner mode, skipping injection");
      return;
    }
    
    const sections = document.querySelectorAll("section.embedded-posts");
    log.info("Found embedded sections", { count: sections.length });
    
    sections.forEach((section, index) => {
      log.groupCollapsed(`Injecting button ${index + 1}/${sections.length}`);
      
      const result = injectEmbeddedReplyButtons(section);
      
      log.debug("Injection result", {
        injected: result.injected,
        reason: result.reason
      });
      
      log.groupEnd();
    });
  });
});

// Click handler
document.addEventListener("click", async (e) => {
  const btn = e.target?.closest?.(".embedded-reply-button");
  if (!btn) return;
  
  log.group("Embedded Reply Button Click");
  
  log.info("Button clicked", {
    ownerPostNumber: btn.dataset.ownerPostNumber,
    buttonElement: btn
  });
  
  try {
    log.time("Open Composer");
    
    const topic = api.container.lookup("controller:topic")?.model;
    const composer = api.container.lookup("service:composer");
    
    log.debug("Services resolved", {
      hasTopic: !!topic,
      hasComposer: !!composer
    });
    
    await openReplyToOwnerPost(topic, ownerPost, ownerPostNumber);
    
    log.timeEnd("Open Composer");
    log.info("Composer opened successfully");
    
  } catch (error) {
    log.error("Failed to open composer", error);
  } finally {
    log.groupEnd();
  }
}, true);
```

---

## Example 8: Diagnostic Helpers

### Redirect Loop Detection

```javascript
let navigationAttempts = 0;
const MAX_ATTEMPTS = 5;

api.onPageChange(() => {
  navigationAttempts++;
  
  log.debug("Navigation attempt", {
    attempt: navigationAttempts,
    maxAttempts: MAX_ATTEMPTS,
    url: window.location.href
  });
  
  if (navigationAttempts > MAX_ATTEMPTS) {
    log.error("REDIRECT LOOP DETECTED", {
      attempts: navigationAttempts,
      url: window.location.href,
      action: "Emergency brake activated"
    });
    return; // Stop processing
  }
  
  // Reset counter after successful navigation
  schedule("afterRender", () => {
    log.debug("Resetting navigation counter");
    navigationAttempts = 0;
  });
});
```

### Duplicate Listener Detection

```javascript
let clickHandlerBindCount = 0;

if (!globalClickHandlerBound) {
  clickHandlerBindCount++;
  
  log.debug("Binding click handler", {
    bindCount: clickHandlerBindCount
  });
  
  if (clickHandlerBindCount > 1) {
    log.warn("DUPLICATE LISTENER DETECTED", {
      bindCount: clickHandlerBindCount,
      handler: "globalClickHandler"
    });
  }
  
  document.addEventListener("click", handler, true);
  globalClickHandlerBound = true;
}
```

### State Lifecycle Tracking

```javascript
let currentState = { suppressed: false, topicId: null };

function setState(newState, reason) {
  log.debug("State change", {
    before: currentState,
    after: newState,
    reason: reason
  });
  currentState = { ...currentState, ...newState };
}

// Usage
setState({ suppressed: true, topicId: 123 }, "User clicked opt-out");
setState({ suppressed: false, topicId: null }, "Navigation to new topic");
```

---

## Best Practices

1. **Use structured objects** instead of string concatenation:
   ```javascript
   // Good
   log.info("Composer opened", { topicId: 123, postNumber: 1 });
   
   // Avoid
   log.info("Composer opened for topic " + topicId + " post " + postNumber);
   ```

2. **Group related logs** to reduce noise:
   ```javascript
   log.groupCollapsed("Processing 10 posts");
   posts.forEach(post => log.debug("Post", post));
   log.groupEnd();
   ```

3. **Use appropriate levels**:
   - `debug`: High-volume, low-level details
   - `info`: Lifecycle milestones, user actions
   - `warn`: Unexpected but recoverable conditions
   - `error`: Critical failures (always logged)

4. **Add context objects** for debugging:
   ```javascript
   log.warn("Post not found", {
     postNumber: 123,
     availablePosts: topic.postStream.posts.map(p => p.post_number),
     topicId: topic.id
   });
   ```

5. **Use performance timing** for slow operations:
   ```javascript
   log.time("Expensive Operation");
   await doExpensiveWork();
   log.timeEnd("Expensive Operation");
   ```

---

**End of Examples**

