# Collapsed Section Expansion Flow Diagram

## Overview

This document visualizes the complete flow for handling replies to owner posts with collapsed embedded sections.

---

## Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    USER CLICKS REPLY BUTTON                      │
│                   (Standard Reply Interceptor)                   │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
                    ┌────────────────┐
                    │  Guard Checks  │
                    │  (4 guards)    │
                    └────────┬───────┘
                             │
                    ┌────────▼────────┐
                    │ All guards pass?│
                    └────────┬────────┘
                             │
                    ┌────────▼────────────────────────────────┐
                    │ Detect Collapsed State                  │
                    │ - Check for section.embedded-posts      │
                    │ - Check for toggle button               │
                    └────────┬────────────────────────────────┘
                             │
                ┌────────────▼────────────┐
                │                         │
         ┌──────▼──────┐          ┌──────▼──────┐
         │  COLLAPSED  │          │  EXPANDED   │
         └──────┬──────┘          └──────┬──────┘
                │                        │
                │                        │
    ┌───────────▼───────────┐            │
    │ Set State Flags:      │            │
    │ - replyToCollapsed    │            │
    │   Section = true      │            │
    │ - replyOwnerPost      │            │
    │   NumberForExpand     │            │
    │   = postNumber        │            │
    └───────────┬───────────┘            │
                │                        │
                └────────────┬───────────┘
                             │
                    ┌────────▼────────┐
                    │ Open Composer   │
                    │ (shared func)   │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │ User Types      │
                    │ Reply           │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │ User Submits    │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │ post:created    │
                    │ (store post)    │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │ composer:saved  │
                    └────────┬────────┘
                             │
                ┌────────────▼────────────┐
                │ Check needsExpansion?   │
                │ (replyToCollapsed &&    │
                │  ownerPostNumber match) │
                └────────┬────────────────┘
                         │
            ┌────────────▼────────────┐
            │                         │
     ┌──────▼──────┐          ┌──────▼──────┐
     │ YES (new)   │          │ NO (old)    │
     └──────┬──────┘          └──────┬──────┘
            │                        │
            │                        │
┌───────────▼───────────┐            │
│ COLLAPSED FLOW        │            │
│ (Orchestration)       │            │
└───────────┬───────────┘            │
            │                        │
   ┌────────▼────────┐               │
   │ Step 1: EXPAND  │               │
   │ - Click toggle  │               │
   │ - Wait for      │               │
   │   section       │               │
   │ - Timeout: 5s   │               │
   └────────┬────────┘               │
            │                        │
   ┌────────▼────────┐               │
   │ Expanded?       │               │
   └────────┬────────┘               │
            │                        │
       ┌────▼────┐                   │
       │   NO    │                   │
       └────┬────┘                   │
            │                        │
   ┌────────▼────────────┐           │
   │ Best-effort:        │           │
   │ - Hide duplicate    │           │
   │ - Finalize state    │           │
   │ - EXIT              │           │
   └─────────────────────┘           │
            │                        │
       ┌────▼────┐                   │
       │   YES   │                   │
       └────┬────┘                   │
            │                        │
   ┌────────▼────────┐               │
   │ Step 2: LOAD    │               │
   │ ALL REPLIES     │               │
   │ - Loop click    │               │
   │   load-more     │               │
   │ - Max: 20 clicks│               │
   │ - Timeout: 10s  │               │
   └────────┬────────┘               │
            │                        │
   ┌────────▼────────┐               │
   │ Step 3: SCROLL  │               │
   │ - Try immediate │               │
   │ - If fail, use  │               │
   │   observer      │               │
   │ - Timeout: 10s  │               │
   └────────┬────────┘               │
            │                        │
   ┌────────▼────────┐               │
   │ Step 4: HIDE    │               │
   │ DUPLICATE       │               │
   │ - Find main     │               │
   │   stream post   │               │
   │ - Set display:  │               │
   │   none          │               │
   └────────┬────────┘               │
            │                        │
   ┌────────▼────────┐               │
   │ Finalize State  │               │
   │ - Clear flags   │               │
   └─────────────────┘               │
            │                        │
            └────────────┬───────────┘
                         │
                ┌────────▼────────┐
                │ EXPANDED FLOW   │
                │ (Existing)      │
                └────────┬────────┘
                         │
                ┌────────▼────────┐
                │ Click load-more │
                │ (once)          │
                └────────┬────────┘
                         │
                ┌────────▼────────┐
                │ Scroll to new   │
                │ reply           │
                └────────┬────────┘
                         │
                ┌────────▼────────┐
                │ Hide duplicate  │
                └────────┬────────┘
                         │
                         ▼
                    ┌────────┐
                    │  DONE  │
                    └────────┘
```

---

## State Transitions

### Module-Level State Variables

```
Initial State:
├─ replyToCollapsedSection: false
├─ replyOwnerPostNumberForExpand: null
└─ expandOrchestratorActive: false

After Detecting Collapsed:
├─ replyToCollapsedSection: true
├─ replyOwnerPostNumberForExpand: <postNumber>
└─ expandOrchestratorActive: false

During Orchestration:
├─ replyToCollapsedSection: true
├─ replyOwnerPostNumberForExpand: <postNumber>
└─ expandOrchestratorActive: true

After Finalize:
├─ replyToCollapsedSection: false
├─ replyOwnerPostNumberForExpand: null
└─ expandOrchestratorActive: false
```

---

## Decision Points

### 1. Collapsed Detection (Interceptor)

```
IF section.embedded-posts exists:
  └─ EXPANDED
ELSE IF toggle button exists:
  └─ COLLAPSED
ELSE:
  └─ COLLAPSED (default)
```

### 2. Needs Expansion (composer:saved)

```
IF replyToCollapsedSection == true
   AND replyOwnerPostNumberForExpand == ownerPostNumber:
  └─ Run COLLAPSED FLOW
ELSE:
  └─ Run EXPANDED FLOW (existing)
```

### 3. Expansion Success

```
IF section appears within 5s:
  └─ Continue to Step 2 (Load All)
ELSE:
  └─ Best-effort fallback → EXIT
```

### 4. Load All Success

```
WHILE load-more button exists
      AND clicks < 20
      AND time < 10s:
  └─ Click button, wait for mutation
  
IF button gone:
  └─ All loaded (SUCCESS)
ELSE:
  └─ Timeout/max clicks (PARTIAL)
  └─ Continue anyway
```

### 5. Scroll Success

```
IF tryScrollToNewReply() succeeds:
  └─ Done
ELSE:
  └─ Set up MutationObserver
  └─ Wait up to 10s
  └─ If found: scroll
  └─ If timeout: give up
```

---

## Error Handling Paths

### Expansion Fails

```
expandEmbeddedReplies() returns false
  │
  ├─ Log: "expansion failed"
  ├─ hideMainStreamDuplicateInOwnerMode()
  ├─ finalizeCollapsedFlow()
  └─ EXIT (no scroll, no load-all)
```

### Load All Times Out

```
loadAllEmbeddedReplies() returns false
  │
  ├─ Log: "timeout after N clicks"
  ├─ Continue to Step 3 (scroll anyway)
  └─ New post might already be visible
```

### Scroll Fails

```
tryScrollToNewReply() returns false
  │
  ├─ Set up MutationObserver
  ├─ Wait 10s
  │
  ├─ IF found: scroll + disconnect
  └─ IF timeout: disconnect + clear state
```

### Exception in Orchestration

```
try {
  // Steps 1-4
} catch (err) {
  console.error(err);
  finalizeCollapsedFlow();
}
```

---

## Observer Lifecycle

### Expansion Observer

```
Created: When toggle button clicked
Observes: ownerPostElement (childList, subtree)
Triggers: When section.embedded-posts appears
Disconnects: On success OR timeout (5s)
```

### Load-More Observer (per click)

```
Created: After each load-more click
Observes: section.embedded-posts (childList, subtree)
Triggers: On any DOM mutation
Disconnects: After mutation OR timeout (1s)
Purpose: Wait for new replies to render
```

### Scroll Observer

```
Created: If immediate scroll fails
Observes: section.embedded-posts (childList, subtree)
Triggers: When new post appears
Disconnects: On success OR timeout (10s)
```

---

## Timing Breakdown

### Typical Collapsed Flow (Fast Network)

```
0ms     - User clicks reply
10ms    - Interceptor detects collapsed
20ms    - Composer opens
[user types]
5000ms  - User submits
5010ms  - post:created fires
5020ms  - composer:saved fires
5030ms  - Orchestration starts
5040ms  - Toggle clicked
5200ms  - Section appears (160ms)
5210ms  - Load-more click #1
5400ms  - Load-more click #2
5600ms  - Load-more click #3
5800ms  - No more button (all loaded)
5810ms  - Scroll attempt
5820ms  - Scroll success
5830ms  - Hide duplicate
5840ms  - Finalize state
TOTAL: ~840ms after submission
```

### Worst Case (Slow Network, Timeouts)

```
0ms     - User clicks reply
10ms    - Interceptor detects collapsed
20ms    - Composer opens
[user types]
10000ms - User submits
10010ms - post:created fires
10020ms - composer:saved fires
10030ms - Orchestration starts
10040ms - Toggle clicked
15040ms - Expansion timeout (5s)
15050ms - Best-effort fallback
15060ms - Hide duplicate
15070ms - Finalize state
TOTAL: ~5s after submission (expansion failed)
```

---

## Cleanup Triggers

### 1. Successful Completion

```
finalizeCollapsedFlow() called at end of orchestration
```

### 2. Error/Timeout

```
finalizeCollapsedFlow() called in catch block
```

### 3. Navigation

```
api.onPageChange() → finalizeCollapsedFlow()
```

### 4. Duplicate Orchestration Attempt

```
IF expandOrchestratorActive:
  └─ Early return (no cleanup needed)
```

---

## Integration with Existing Code

### Reused Functions

- `robustClick()` - Click buttons safely
- `tryScrollToNewReply()` - Scroll to new post
- `hideMainStreamDuplicateInOwnerMode()` - Hide duplicate
- `openReplyToOwnerPost()` - Open composer
- `extractPostNumberFromElement()` - Parse post numbers

### Reused State

- `lastCreatedPost` - Track new post for scroll
- `lastReplyContext` - Fallback parent post number
- `suppressStandardReplyScroll` - Prevent default scroll

### Reused Selectors

- `.post-controls .show-replies, .show-replies, .post-action-menu__show-replies` - Toggle button
- `section.embedded-posts` - Embedded section
- `.load-more-replies` - Load more button
- `article.topic-post[data-post-number]` - Owner post

---

## Key Differences: Collapsed vs Expanded

| Aspect | Collapsed Flow | Expanded Flow |
|--------|---------------|---------------|
| Detection | No section OR toggle exists | Section exists, no toggle |
| State flags | Set to true | Set to false |
| Orchestration | Full 4-step process | Simple load-more click |
| Expansion | Click toggle, wait | Skip (already expanded) |
| Load all | Loop until no button | Single click |
| Timing | 3-7s typical | 1-2s typical |
| Observers | 3 types (expand, load, scroll) | 1 type (scroll) |
| Complexity | High | Low |

---

## Success Indicators

### Console Logs (Collapsed)

```
✅ "Detected collapsed embedded section"
✅ "AutoRefresh: handling collapsed section"
✅ "Expand: clicking toggle button"
✅ "Expand: section appeared"
✅ "LoadAll: starting to load all replies"
✅ "LoadAll: clicking load-more button (click #N)"
✅ "LoadAll: no more load-more button, all replies loaded"
✅ "AutoScroll: scrolling to post"
✅ "Hidden main stream post"
✅ "Finalize: clearing collapsed expansion state"
```

### Console Logs (Expanded)

```
✅ "Embedded section is expanded"
✅ "AutoRefresh: clicking loadMoreBtn immediately"
✅ "AutoScroll: scrolling to post"
✅ "Hidden main stream post"
```

### Visual Indicators

```
✅ Section expands smoothly
✅ Replies load progressively
✅ Scroll animation to new post
✅ Highlight appears on new post
✅ No duplicate in main stream
✅ No UI freezing
```

