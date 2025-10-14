# Logging Guide

## Overview

The embedded-reply-buttons feature includes a configurable logging system to help with debugging while keeping console output manageable in production.

## Log Levels

The logging system has four levels:

1. **logDebug** - Verbose debugging information (118 calls)
   - Only shown when `DEBUG = true`
   - Includes detailed state changes, observer setup, element searches, etc.
   
2. **logInfo** - Important events (16 calls)
   - Always shown
   - Includes composer opening, reply submission, auto-refresh triggers
   
3. **logWarn** - Warnings (9 calls)
   - Always shown
   - Includes failed operations that don't break functionality
   
4. **logError** - Errors (10 calls)
   - Always shown
   - Includes critical failures that prevent features from working

## Enabling Debug Logging

To enable verbose debug logging:

1. Open `javascripts/discourse/api-initializers/embedded-reply-buttons.gjs`
2. Find the line: `const DEBUG = false;`
3. Change it to: `const DEBUG = true;`
4. Save and refresh your Discourse instance

## Default Console Output (DEBUG = false)

With debug logging disabled, you'll see approximately **35 log messages** during typical usage:

### Info Messages (16)
- `Opening reply to owner post #X`
- `Composer opened successfully`
- `Stored lastReplyContext`
- `Standard reply suppression active`
- `Standard reply intercepted for owner post #X`
- `AutoRefresh: initializing composer event listeners`
- `AutoRefresh: binding composer:saved`
- `AutoRefresh: composer:saved fired`
- `AutoRefresh: target parent post #X`
- `AutoRefresh: skipping - not in owner comment mode`
- `AutoRefresh: skipping - could not determine parent post number`
- `AutoRefresh: using lastReplyContext fallback`
- `AutoRefresh: composer.model snapshot`
- `AutoScroll: scrolling to post #X`

### Warning Messages (9)
- `Could not extract post number from owner post element`
- `Could not find owner post element for section`
- `Failed to hide duplicate in main stream`
- `Failed to hide main stream duplicate`

### Error Messages (10)
- `CRITICAL: Could not determine owner post number - button will not work!`
- `Owner post number not found on button`
- `All approaches failed`
- `Error opening composer`
- `Error opening composer for standard reply`
- `AutoRefresh: error in collapsed flow orchestration`
- `AutoRefresh: error inside composer:saved`

## Debug Console Output (DEBUG = true)

With debug logging enabled, you'll see approximately **153 log messages** including:

### AutoScroll Details
- Searching for newly created posts
- Element selector matching
- Scroll attempts and results
- Duplicate hiding in main stream

### AutoRefresh Details
- Schedule timing
- Embedded section detection
- Load more button clicks
- Observer setup and timeouts
- Step-by-step expansion flow

### Button Injection Details
- Section detection
- Owner post resolution
- Button creation and placement
- Observer setup for dynamic content

### Reply Interception Details
- Standard reply button clicks
- Collapsed vs expanded state detection
- Suppression flag management

## Filtering Console Output

To focus on specific functionality, use browser console filters:

```
[Embedded Reply Buttons] AutoScroll
[Embedded Reply Buttons] AutoRefresh
[Embedded Reply Buttons] Expand
[Embedded Reply Buttons] LoadAll
[Embedded Reply Buttons] Opening reply
[Embedded Reply Buttons] Composer opened
```

## Typical Usage Scenarios

### Scenario 1: Reply to Collapsed Embedded Posts

**With DEBUG = false (5-8 messages):**
```
[Embedded Reply Buttons] Standard reply intercepted for owner post #1
[Embedded Reply Buttons] Opening reply to owner post #1
[Embedded Reply Buttons] Stored lastReplyContext
[Embedded Reply Buttons] Composer opened successfully
[Embedded Reply Buttons] AutoRefresh: composer:saved fired
[Embedded Reply Buttons] AutoRefresh: target parent post #1
[Embedded Reply Buttons] AutoScroll: scrolling to post #5
```

**With DEBUG = true (40-50 messages):**
Includes all of the above plus:
- Detected collapsed embedded section
- Set suppression flag
- Expand: attempting to expand
- Expand: clicking toggle button
- Expand: section appeared
- LoadAll: starting to load all replies
- LoadAll: clicking load-more button (multiple times)
- LoadAll: all replies loaded
- AutoScroll: searching for post
- AutoScroll: found element with selector
- AutoScroll: clearing lastCreatedPost
- Hidden main stream post #5

### Scenario 2: Reply to Expanded Embedded Posts

**With DEBUG = false (4-6 messages):**
```
[Embedded Reply Buttons] Opening reply to owner post #1
[Embedded Reply Buttons] Stored lastReplyContext
[Embedded Reply Buttons] Composer opened successfully
[Embedded Reply Buttons] AutoRefresh: composer:saved fired
[Embedded Reply Buttons] AutoRefresh: target parent post #1
[Embedded Reply Buttons] AutoScroll: scrolling to post #5
```

**With DEBUG = true (20-30 messages):**
Includes all of the above plus:
- Embedded section is expanded
- AutoRefresh: schedule(afterRender) start
- AutoRefresh: embeddedSection found
- AutoRefresh: loadMoreBtn found
- AutoRefresh: clicking loadMoreBtn immediately
- AutoRefresh: robustClick(loadMoreBtn) => true
- AutoScroll: searching for post
- AutoScroll: found element
- AutoScroll: clearing lastCreatedPost

## Troubleshooting

### Issue: Too much console output

**Solution:** Ensure `DEBUG = false` in the code. This reduces output from ~150 messages to ~35.

### Issue: Need to debug specific functionality

**Solution:** Temporarily set `DEBUG = true` and use console filters to focus on specific prefixes:
- `AutoScroll` - New post scrolling
- `AutoRefresh` - Embedded posts refresh
- `Expand` - Collapsed section expansion
- `LoadAll` - Loading all embedded replies

### Issue: Missing critical information

**Solution:** Check that you're looking at `logInfo`, `logWarn`, and `logError` messages. These are always shown and contain the most important events.

## Best Practices

1. **Development:** Use `DEBUG = true` to understand flow and diagnose issues
2. **Production:** Use `DEBUG = false` to keep console clean
3. **Bug Reports:** Include console output with `DEBUG = true` for detailed diagnostics
4. **Performance:** Debug logging has minimal performance impact when disabled

## Log Message Reference

### Key Info Messages

| Message | Meaning |
|---------|---------|
| `Opening reply to owner post #X` | User clicked reply button, opening composer |
| `Composer opened successfully` | Composer opened without errors |
| `AutoRefresh: composer:saved fired` | Reply was submitted successfully |
| `AutoScroll: scrolling to post #X` | Scrolling to newly created reply |

### Key Warning Messages

| Message | Meaning |
|---------|---------|
| `Could not extract post number` | Unable to determine post number from DOM |
| `Could not find owner post element` | Unable to locate parent post for embedded section |
| `Failed to hide duplicate` | Could not hide duplicate post in main stream |

### Key Error Messages

| Message | Meaning |
|---------|---------|
| `CRITICAL: Could not determine owner post number` | Reply button won't work - missing data |
| `Owner post number not found on button` | Button missing required data attribute |
| `Error opening composer` | Composer failed to open |
| `AutoRefresh: error inside composer:saved` | Auto-refresh failed after reply submission |

## Related Documentation

- [EMBEDDED_REPLY_BUTTONS_TESTING.md](EMBEDDED_REPLY_BUTTONS_TESTING.md) - Testing procedures
- [AUTO_REFRESH_EMBEDDED_POSTS_INVESTIGATION.md](AUTO_REFRESH_EMBEDDED_POSTS_INVESTIGATION.md) - Auto-refresh implementation
- [EMBEDDED_REPLY_CONTEXT_FIX.md](EMBEDDED_REPLY_CONTEXT_FIX.md) - Reply context handling

