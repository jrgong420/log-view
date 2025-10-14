# Collapsed Section Auto-Expand Implementation

## Status: ✅ COMPLETE

Implementation completed for auto-expanding collapsed embedded replies sections after reply submission.

---

## What Was Implemented

### 1. Module-Level State Variables (Lines 22-25)

Added three new state variables to track collapsed section expansion:

```javascript
// Collapsed section expansion state
let replyToCollapsedSection = false;
let replyOwnerPostNumberForExpand = null;
let expandOrchestratorActive = false;
```

**Purpose**:
- `replyToCollapsedSection`: Tracks if the user replied to a post with collapsed embedded section
- `replyOwnerPostNumberForExpand`: Stores the owner post number to expand after submission
- `expandOrchestratorActive`: Prevents duplicate orchestration attempts

---

### 2. Helper Functions (Lines 267-425)

#### `expandEmbeddedReplies(ownerPostElement, { timeoutMs = 5000 })`

**Purpose**: Programmatically expand a collapsed embedded replies section

**Logic**:
1. Check if section already exists (early return if expanded)
2. Find toggle button using selectors: `.post-controls .show-replies, .show-replies, .post-action-menu__show-replies`
3. Click toggle button using `robustClick()`
4. Wait for `section.embedded-posts` to appear using MutationObserver
5. Timeout after 5 seconds if section doesn't appear

**Returns**: Promise<boolean> - true if expansion succeeded

---

#### `loadAllEmbeddedReplies(ownerPostElement, { maxClicks = 20, timeoutMs = 10000 })`

**Purpose**: Load all embedded replies by clicking "load more" until no button remains

**Logic**:
1. Find `section.embedded-posts` within owner post
2. Loop up to `maxClicks` times (default: 20):
   - Find `.load-more-replies` button
   - If no button found, all replies are loaded (return true)
   - If button is disabled/loading, wait 500ms and retry
   - Click button using `robustClick()`
   - Wait for DOM mutation (new replies to load)
   - Small delay (200ms) between clicks
3. Timeout after 10 seconds total

**Returns**: Promise<boolean> - true if all replies loaded, false if timed out

---

#### `finalizeCollapsedFlow()`

**Purpose**: Clear all collapsed section expansion state

**Logic**:
- Reset `replyToCollapsedSection` to false
- Reset `replyOwnerPostNumberForExpand` to null
- Reset `expandOrchestratorActive` to false

---

### 3. Detection Logic in Standard Reply Interceptor (Lines 945-958)

Added collapsed state detection when intercepting standard reply button clicks:

```javascript
// Detect if embedded section is collapsed
const section = postElement?.querySelector("section.embedded-posts");
const hasToggleBtn = postElement?.querySelector(
  ".post-controls .show-replies, .show-replies, .post-action-menu__show-replies"
);
const isCollapsed = !section || !!hasToggleBtn;

if (isCollapsed) {
  console.log(`${LOG_PREFIX} Detected collapsed embedded section for post #${postNumber}`);
  replyToCollapsedSection = true;
  replyOwnerPostNumberForExpand = postNumber;
} else {
  console.log(`${LOG_PREFIX} Embedded section is expanded for post #${postNumber}`);
  replyToCollapsedSection = false;
  replyOwnerPostNumberForExpand = null;
}
```

**Detection heuristics**:
- Section is collapsed if:
  - `section.embedded-posts` doesn't exist, OR
  - Toggle/expand button is present

---

### 4. Orchestration Logic in composer:saved (Lines 1193-1279)

Added complete orchestration flow for collapsed sections:

```javascript
const needsExpansion = replyToCollapsedSection && replyOwnerPostNumberForExpand === ownerPostNumber;

if (needsExpansion) {
  // Prevent duplicate orchestration
  if (expandOrchestratorActive) return;
  expandOrchestratorActive = true;

  schedule("afterRender", async () => {
    try {
      // Step 1: Expand
      const expanded = await expandEmbeddedReplies(ownerPostElement, { timeoutMs: 5000 });
      if (!expanded) {
        // Best-effort: hide duplicate, finalize
        hideMainStreamDuplicateInOwnerMode(...);
        finalizeCollapsedFlow();
        return;
      }

      // Step 2: Load all replies
      const allLoaded = await loadAllEmbeddedReplies(ownerPostElement, { maxClicks: 20, timeoutMs: 10000 });

      // Step 3: Scroll to new reply
      const section = ownerPostElement.querySelector("section.embedded-posts");
      if (section && lastCreatedPost) {
        const scrolled = tryScrollToNewReply(section);
        if (!scrolled) {
          // Set up observer to wait for new post
          const scrollObserver = new MutationObserver(...);
          // Timeout after 10s
        }
      }

      // Step 4: Hide duplicate in main stream
      hideMainStreamDuplicateInOwnerMode(lastCreatedPost.postNumber, lastCreatedPost.postId);

      // Clear state
      finalizeCollapsedFlow();
    } catch (err) {
      console.error(...);
      finalizeCollapsedFlow();
    }
  });

  return; // Exit early - collapsed flow handled
}

// Normal flow (expanded section) continues below...
```

**Sequence**:
1. Expand collapsed section (5s timeout)
2. Load all replies (20 clicks max, 10s timeout)
3. Scroll to new reply (with observer fallback)
4. Hide duplicate in main stream
5. Clear collapsed state

**Error handling**:
- If expansion fails: hide duplicate, finalize, exit
- If loading times out: continue to scroll anyway
- Always finalize state in try/catch

---

### 5. State Cleanup on Navigation (Lines 989-993)

Added cleanup in `api.onPageChange`:

```javascript
// Clear collapsed section expansion state on navigation
if (replyToCollapsedSection || replyOwnerPostNumberForExpand || expandOrchestratorActive) {
  console.log(`${LOG_PREFIX} onPageChange: clearing stale collapsed expansion state`);
  finalizeCollapsedFlow();
}
```

**Purpose**: Prevent stale state from carrying over to new pages

---

## How It Works

### Collapsed Section Flow

1. **User clicks standard reply button** on owner post with collapsed embedded section
2. **Interceptor detects collapsed state**:
   - Sets `replyToCollapsedSection = true`
   - Sets `replyOwnerPostNumberForExpand = postNumber`
3. **Composer opens** (existing behavior)
4. **User submits reply**
5. **composer:saved fires**:
   - Detects `needsExpansion = true`
   - Sets `expandOrchestratorActive = true`
   - Orchestrates:
     - Expand section (click toggle, wait for section)
     - Load all replies (click load-more until gone)
     - Scroll to new reply (with observer fallback)
     - Hide duplicate in main stream
   - Clears all state flags

### Expanded Section Flow (Unchanged)

1. User clicks reply button on owner post with expanded section
2. Interceptor detects expanded state:
   - Sets `replyToCollapsedSection = false`
3. Composer opens
4. User submits reply
5. composer:saved fires:
   - Detects `needsExpansion = false`
   - Continues with existing auto-refresh logic (click load-more once)

---

## Testing Checklist

### Collapsed Section Tests

- [ ] Reply to owner post with collapsed embedded section
- [ ] Verify section auto-expands after submission
- [ ] Verify all replies load (not just first 20)
- [ ] Verify new reply is visible and scrolled/highlighted
- [ ] Verify new reply does NOT appear in main stream
- [ ] Test with long threads (>20 replies)
- [ ] Test timeout scenarios (slow network)

### Expanded Section Tests (Regression)

- [ ] Reply to owner post with expanded section
- [ ] Verify existing behavior still works
- [ ] Verify no duplicate expansion attempts
- [ ] Verify auto-scroll still works

### Edge Cases

- [ ] Multiple owner posts on page - reply to each with collapsed state
- [ ] Navigate away during expansion - verify state clears
- [ ] Manually expand while posting - verify orchestrator detects already-expanded
- [ ] Mobile vs desktop layouts
- [ ] Very long threads (test max clicks guard)

---

## Console Logs to Expect

### Collapsed Flow Success

```
[Embedded Reply Buttons] Standard reply intercepted for owner post #814
[Embedded Reply Buttons] Detected collapsed embedded section for post #814
[Embedded Reply Buttons] AutoRefresh: handling collapsed section for owner post #814
[Embedded Reply Buttons] AutoRefresh: Step 1 - Expanding collapsed section for post #814
[Embedded Reply Buttons] Expand: clicking toggle button for post #814
[Embedded Reply Buttons] Expand: section appeared for post #814
[Embedded Reply Buttons] AutoRefresh: Step 2 - Loading all replies for post #814
[Embedded Reply Buttons] LoadAll: clicking load-more button (click #1) for post #814
[Embedded Reply Buttons] LoadAll: no more load-more button, all replies loaded for post #814 (3 clicks)
[Embedded Reply Buttons] AutoRefresh: Step 3 - Attempting to scroll to new post #830
[Embedded Reply Buttons] AutoScroll: scrolling to post #830
[Embedded Reply Buttons] Hidden main stream post #830 in owner mode
[Embedded Reply Buttons] Finalize: clearing collapsed expansion state
```

### Expanded Flow (Unchanged)

```
[Embedded Reply Buttons] Standard reply intercepted for owner post #814
[Embedded Reply Buttons] Embedded section is expanded for post #814
[Embedded Reply Buttons] AutoRefresh: clicking loadMoreBtn immediately
[Embedded Reply Buttons] AutoScroll: scrolling to post #830
[Embedded Reply Buttons] Hidden main stream post #830 in owner mode
```

---

## Configuration

### Timeouts (Configurable)

- **Expansion timeout**: 5000ms (5 seconds)
- **Load all timeout**: 10000ms (10 seconds)
- **Scroll observer timeout**: 10000ms (10 seconds)

### Limits

- **Max load-more clicks**: 20
- **Wait between clicks**: 200ms
- **Wait for disabled button**: 500ms

To adjust, modify the function calls in the orchestration:

```javascript
const expanded = await expandEmbeddedReplies(ownerPostElement, { timeoutMs: 7000 }); // 7s
const allLoaded = await loadAllEmbeddedReplies(ownerPostElement, { maxClicks: 30, timeoutMs: 15000 }); // 30 clicks, 15s
```

---

## Files Modified

- `javascripts/discourse/api-initializers/embedded-reply-buttons.gjs`
  - Added module state variables (lines 22-25)
  - Added helper functions (lines 267-425)
  - Added detection logic in interceptor (lines 945-958)
  - Added orchestration in composer:saved (lines 1193-1279)
  - Added state cleanup in onPageChange (lines 989-993)

---

## Next Steps

1. Test collapsed section flow in development
2. Test expanded section flow (regression)
3. Test edge cases (multiple posts, navigation, timeouts)
4. Monitor console logs for any errors
5. Adjust timeouts/limits if needed based on real-world performance

---

## Known Limitations

- Maximum 20 "load more" clicks (configurable)
- 10-second total timeout for loading all replies (configurable)
- If expansion fails, falls back to hiding duplicate only (no scroll)
- Assumes toggle button uses standard selectors (may need adjustment for custom themes)

