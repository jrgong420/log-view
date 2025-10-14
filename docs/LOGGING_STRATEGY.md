# Logging Strategy for Debug Instrumentation

**Date**: 2025-10-14  
**Purpose**: Define comprehensive, structured logging approach for debugging theme component behavior while maintaining performance and usability.

---

## 1. Goals

1. **Comprehensive Coverage**: Log all critical decision points, state changes, and event flows
2. **Performance-Safe**: Minimal overhead when disabled, acceptable overhead when enabled
3. **User-Friendly**: Admin-controlled toggle, clear prefixes, structured output
4. **Debuggable**: Easy to trace flows, identify issues, and verify guards
5. **Production-Ready**: Safe to ship with logging code in place (disabled by default)

---

## 2. Settings-Based Toggle

### 2.1 New Setting: `debug_logging_enabled`

**File**: `settings.yml`

```yaml
debug_logging_enabled:
  type: bool
  default: false
  description: "Enable detailed console logging for debugging theme component behavior. Only enable when troubleshooting issues."
```

**Localization** (`locales/en.yml`):

```yaml
theme_metadata:
  settings:
    debug_logging_enabled: "Enable verbose console logging for debugging. Warning: This will generate significant console output. Only enable when troubleshooting."
```

### 2.2 Access Pattern

All initializers will access the setting via the global `settings` object:

```javascript
const DEBUG = settings.debug_logging_enabled;
```

**Rationale**: Simple, reactive (changes apply on next page load), no need for service injection.

---

## 3. Logger Utility API

### 3.1 Centralized Logger Module

**File**: `javascripts/discourse/lib/logger.js`

**Purpose**: Provide consistent logging API with:
- Automatic prefix injection
- Settings-based gating
- Rate-limiting for high-frequency logs
- Structured context objects
- Performance timing helpers

### 3.2 Logger API

```javascript
import { createLogger } from "../lib/logger";

const log = createLogger("[Owner View] [Feature Name]");

// Basic logging (gated by settings.debug_logging_enabled)
log.debug("Low-level detail", { context: "value" });
log.info("Lifecycle milestone", { topicId: 123 });
log.warn("Unexpected condition", { reason: "data missing" });
log.error("Critical failure", error);

// Grouped logging for multi-step flows
log.group("Reply Flow");
log.info("Step 1: Opening composer");
log.info("Step 2: Waiting for save");
log.groupEnd();

// Collapsed groups (less noisy)
log.groupCollapsed("Auto-Refresh Details");
log.debug("Parent post number:", 1);
log.debug("Section found:", true);
log.groupEnd();

// Performance timing
log.time("Refresh Operation");
// ... do work ...
log.timeEnd("Refresh Operation"); // Logs elapsed time

// Rate-limited logging (max 1 per 2 seconds for same message)
log.debugThrottled("High-frequency event", { count: 1 });
```

### 3.3 Implementation Details

**Rate-Limiting**:
- Track last log time per message key (hash of prefix + message)
- Default throttle: 2000ms
- Configurable via optional setting (future enhancement)

**Structured Context**:
- Accept objects as additional arguments
- Use `console.table` for tabular data
- Preserve stack traces for errors

**Performance**:
- When disabled: single boolean check, no string concatenation
- When enabled: minimal overhead (native console APIs)

---

## 4. Logging Levels and Usage

### 4.1 `log.debug(...)`
**When**: High-volume, low-level details  
**Examples**:
- DOM queries ("Found 3 embedded sections")
- Guard evaluations ("Guard passed: data available")
- State reads ("Current filter: username")

**Visibility**: Only when `debug_logging_enabled = true`

---

### 4.2 `log.info(...)`
**When**: Lifecycle milestones, user actions  
**Examples**:
- "Page changed to /t/topic/123"
- "Composer opened for post #1"
- "Auto-refresh triggered"
- "Button injected successfully"

**Visibility**: Only when `debug_logging_enabled = true`

---

### 4.3 `log.warn(...)`
**When**: Unexpected but recoverable conditions  
**Examples**:
- "Owner post number not found, using fallback"
- "Expansion timeout, continuing anyway"
- "Post not found in stream"

**Visibility**: Only when `debug_logging_enabled = true`

---

### 4.4 `log.error(...)`
**When**: Critical failures, exceptions  
**Examples**:
- "Composer service not available"
- "Failed to open composer: [error]"
- "CRITICAL: Could not determine owner post number"

**Visibility**: Always (even when debug disabled) ⚠️  
**Rationale**: Errors should always be visible to help users report issues

---

## 5. Prefix Conventions

### 5.1 Format
```
[Owner View] [Feature Name] Message
```

### 5.2 Feature Names
- `[Embedded Reply Buttons]` - embedded-reply-buttons.gjs
- `[Owner Comments]` - owner-comment-prototype.gjs
- `[Hide Reply Buttons]` - hide-reply-buttons.gjs
- `[Group Access Control]` - group-access-control.gjs
- `[Toggle Button]` - owner-toggle-button.gjs
- `[Toggle Outlets]` - owner-toggle-outlets.gjs

### 5.3 Sub-Features (Optional)
For complex flows within a feature:
```
[Owner View] [Embedded Reply Buttons] [AutoRefresh] Step 1: Expanding section
[Owner View] [Embedded Reply Buttons] [AutoScroll] Scrolling to post #123
```

---

## 6. Structured Logging Patterns

### 6.1 State Snapshots
```javascript
log.info("State snapshot", {
  topicId: topic.id,
  categoryId: topic.category_id,
  ownerUsername: topic.details?.created_by?.username,
  currentFilter: url.searchParams.get("username_filters"),
  isFiltered: document.body.dataset.ownerCommentMode === "true"
});
```

### 6.2 Guard Evaluations
```javascript
log.debug("Guard: Check if already filtered", {
  urlParam: currentFilter,
  uiIndicator: hasFilteredNotice,
  result: currentFilter || hasFilteredNotice ? "SKIP" : "PROCEED"
});
```

### 6.3 Event Flows
```javascript
log.group("Reply Button Click Flow");
log.info("Event target:", e.target);
log.info("Owner post number:", ownerPostNumber);
log.info("Composer options:", composerOptions);
log.groupEnd();
```

### 6.4 Performance Tracking
```javascript
log.time("Auto-Refresh: Expand + Load + Scroll");
await expandEmbeddedReplies(ownerPostElement);
log.timeLog("Auto-Refresh: Expand + Load + Scroll", "Expansion complete");
await loadAllEmbeddedReplies(ownerPostElement);
log.timeLog("Auto-Refresh: Expand + Load + Scroll", "Loading complete");
tryScrollToNewReply(section);
log.timeEnd("Auto-Refresh: Expand + Load + Scroll");
```

---

## 7. Diagnostic Helpers

### 7.1 Redirect Loop Detection
```javascript
let navigationAttempts = 0;
const MAX_ATTEMPTS = 5;

api.onPageChange(() => {
  navigationAttempts++;
  
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
    navigationAttempts = 0;
  });
});
```

### 7.2 Duplicate Listener Detection
```javascript
let clickHandlerBindCount = 0;

if (!globalClickHandlerBound) {
  clickHandlerBindCount++;
  
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

### 7.3 State Lifecycle Tracking
```javascript
function setState(newState, reason) {
  log.debug("State change", {
    before: currentState,
    after: newState,
    reason: reason
  });
  currentState = newState;
}

// Usage
setState({ suppressed: true, topicId: 123 }, "User clicked opt-out");
```

---

## 8. Rate-Limiting Strategy

### 8.1 High-Frequency Events
**Candidates**:
- MutationObserver callbacks
- Scroll events
- Resize events
- Repeated guard checks

**Implementation**:
```javascript
// Throttle to max 1 log per 2 seconds for same message
log.debugThrottled("MutationObserver: Node added", { nodeType: node.nodeName });
```

### 8.2 Throttle Configuration
**Default**: 2000ms  
**Future Enhancement**: Add setting `debug_log_throttle_ms` (integer, default 2000)

---

## 9. Migration Plan

### 9.1 Current State
- Each initializer has own `DEBUG` constant (hardcoded true/false)
- Each has own `logDebug`, `logInfo`, `logWarn`, `logError` helpers
- Inconsistent prefixes and patterns

### 9.2 Migration Steps
1. Create `lib/logger.js` utility
2. Add `debug_logging_enabled` setting
3. Update each initializer:
   - Import `createLogger`
   - Replace hardcoded `DEBUG` with `settings.debug_logging_enabled`
   - Replace local helpers with logger instance
   - Add structured context objects
   - Add performance timing where appropriate
4. Test each initializer individually
5. Verify no performance regression when disabled

---

## 10. Example: Before & After

### Before (embedded-reply-buttons.gjs)
```javascript
const DEBUG = false;

function logDebug(...args) {
  if (DEBUG) {
    console.log(LOG_PREFIX, ...args);
  }
}

function logInfo(...args) {
  console.log(LOG_PREFIX, ...args);
}

// Usage
logDebug("Section-level reply button clicked");
logInfo("Opening reply to owner post #" + ownerPostNumber);
```

### After (embedded-reply-buttons.gjs)
```javascript
import { createLogger } from "../lib/logger";

const log = createLogger("[Owner View] [Embedded Reply Buttons]");

// Usage
log.debug("Section-level reply button clicked", {
  button: btn,
  ownerPostNumber: btn.dataset.ownerPostNumber
});

log.info("Opening reply to owner post", {
  postNumber: ownerPostNumber,
  topicId: topic.id,
  hasPostModel: !!ownerPost
});
```

---

## 11. Testing Checklist

### 11.1 Functional Tests
- [ ] Setting toggle works (enable/disable in admin)
- [ ] Logs appear when enabled
- [ ] Logs hidden when disabled
- [ ] Errors always visible (even when disabled)
- [ ] Prefixes consistent across all features
- [ ] Structured context objects render correctly

### 11.2 Performance Tests
- [ ] No console output when disabled
- [ ] No performance degradation when disabled (< 1ms overhead)
- [ ] Acceptable performance when enabled (< 10ms per page load)
- [ ] Rate-limiting prevents console flooding

### 11.3 Usability Tests
- [ ] Logs are readable and actionable
- [ ] Groups/collapsed groups reduce noise
- [ ] Performance timings provide useful data
- [ ] Error messages include enough context to debug

---

## 12. Future Enhancements

### 12.1 Log Levels
Add granular control:
```yaml
debug_log_level:
  type: enum
  default: "info"
  choices:
    - "debug"
    - "info"
    - "warn"
    - "error"
```

### 12.2 Feature-Specific Toggles
```yaml
debug_log_embedded_replies:
  type: bool
  default: false

debug_log_auto_filter:
  type: bool
  default: false
```

### 12.3 Log Export
Add button to export console logs as JSON for support tickets.

---

**End of Strategy Document**

