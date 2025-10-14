# Testing Guide: Collapsed Section Auto-Expansion

## Quick Test Scenarios

### Scenario 1: Basic Collapsed Section Expansion

**Setup**:
1. Navigate to a topic in filtered view (owner comment mode)
2. Find an owner post with collapsed embedded replies (shows "Show replies" button)

**Steps**:
1. Click the standard reply button on the owner post
2. Type a reply in the composer
3. Submit the reply

**Expected Results**:
- ✅ Embedded replies section auto-expands
- ✅ All embedded replies load (not just first 20)
- ✅ New reply appears in the embedded section
- ✅ Page auto-scrolls to the new reply with highlight
- ✅ New reply does NOT appear at the bottom of the main stream

**Console Logs to Check**:
```
[Embedded Reply Buttons] Detected collapsed embedded section for post #XXX
[Embedded Reply Buttons] AutoRefresh: handling collapsed section for owner post #XXX
[Embedded Reply Buttons] Expand: clicking toggle button for post #XXX
[Embedded Reply Buttons] Expand: section appeared for post #XXX
[Embedded Reply Buttons] LoadAll: starting to load all replies for post #XXX
[Embedded Reply Buttons] LoadAll: no more load-more button, all replies loaded for post #XXX
[Embedded Reply Buttons] AutoScroll: scrolling to post #YYY
[Embedded Reply Buttons] Hidden main stream post #YYY in owner mode
[Embedded Reply Buttons] Finalize: clearing collapsed expansion state
```

---

### Scenario 2: Expanded Section (Regression Test)

**Setup**:
1. Navigate to a topic in filtered view
2. Find an owner post with expanded embedded replies (section visible)

**Steps**:
1. Click the standard reply button on the owner post
2. Type a reply
3. Submit

**Expected Results**:
- ✅ Existing behavior continues to work
- ✅ No expansion attempt (already expanded)
- ✅ Load more button clicked once
- ✅ New reply appears and scrolls
- ✅ New reply does NOT appear in main stream

**Console Logs to Check**:
```
[Embedded Reply Buttons] Embedded section is expanded for post #XXX
[Embedded Reply Buttons] AutoRefresh: clicking loadMoreBtn immediately
[Embedded Reply Buttons] AutoScroll: scrolling to post #YYY
[Embedded Reply Buttons] Hidden main stream post #YYY in owner mode
```

**Should NOT see**:
- ❌ "Detected collapsed embedded section"
- ❌ "Expand: clicking toggle button"
- ❌ "LoadAll: starting to load all replies"

---

### Scenario 3: Long Thread (>20 Replies)

**Setup**:
1. Find or create an owner post with >20 embedded replies
2. Ensure section is collapsed

**Steps**:
1. Click reply button
2. Submit reply

**Expected Results**:
- ✅ Section expands
- ✅ Multiple "load more" clicks occur (check console)
- ✅ All replies eventually load
- ✅ New reply appears at the end
- ✅ Auto-scroll works

**Console Logs to Check**:
```
[Embedded Reply Buttons] LoadAll: clicking load-more button (click #1) for post #XXX
[Embedded Reply Buttons] LoadAll: clicking load-more button (click #2) for post #XXX
[Embedded Reply Buttons] LoadAll: clicking load-more button (click #3) for post #XXX
...
[Embedded Reply Buttons] LoadAll: no more load-more button, all replies loaded for post #XXX (N clicks)
```

---

### Scenario 4: Multiple Owner Posts

**Setup**:
1. Navigate to a topic with multiple owner posts
2. Ensure some have collapsed embedded sections

**Steps**:
1. Reply to first owner post (collapsed)
2. Verify expansion works
3. Reply to second owner post (collapsed)
4. Verify expansion works for correct post

**Expected Results**:
- ✅ Each owner post expands independently
- ✅ Correct section expands (not other posts)
- ✅ State clears between replies

---

### Scenario 5: Navigation During Expansion

**Setup**:
1. Start replying to owner post with collapsed section
2. Submit reply
3. Immediately navigate away (click another topic link)

**Expected Results**:
- ✅ State clears on navigation
- ✅ No errors in console
- ✅ No stale state on next page

**Console Logs to Check**:
```
[Embedded Reply Buttons] onPageChange: clearing stale collapsed expansion state
[Embedded Reply Buttons] Finalize: clearing collapsed expansion state
```

---

### Scenario 6: Manual Expansion During Reply

**Setup**:
1. Click reply on collapsed owner post
2. While composer is open, manually click "Show replies" to expand
3. Submit reply

**Expected Results**:
- ✅ Orchestrator detects section is already expanded
- ✅ Skips expansion step
- ✅ Proceeds to load all and scroll

**Console Logs to Check**:
```
[Embedded Reply Buttons] Expand: section already exists for post #XXX
[Embedded Reply Buttons] LoadAll: starting to load all replies for post #XXX
```

---

### Scenario 7: Timeout Scenarios

**Setup**:
1. Throttle network to "Slow 3G" in DevTools
2. Reply to collapsed owner post

**Expected Results**:
- ✅ Expansion may timeout (5s)
- ✅ Loading may timeout (10s)
- ✅ Graceful fallback: hide duplicate, finalize state
- ✅ No infinite loops or hanging

**Console Logs to Check**:
```
[Embedded Reply Buttons] Expand: timeout waiting for section to appear for post #XXX
OR
[Embedded Reply Buttons] LoadAll: timeout after N clicks for post #XXX
```

---

### Scenario 8: Embedded Reply Button (Expanded Only)

**Setup**:
1. Expand an owner post's embedded section
2. Click the embedded reply button (inside the section)

**Steps**:
1. Click embedded reply button
2. Submit reply

**Expected Results**:
- ✅ Works as before (no collapsed detection needed)
- ✅ No expansion attempt
- ✅ Normal auto-refresh flow

**Note**: Embedded reply button only appears when section is already expanded, so collapsed flow doesn't apply.

---

## Debugging Tips

### Check State Variables

Add temporary logging to see state:

```javascript
console.log("State check:", {
  replyToCollapsedSection,
  replyOwnerPostNumberForExpand,
  expandOrchestratorActive
});
```

### Verify Toggle Button Selector

If expansion fails, check if toggle button exists:

```javascript
const toggleBtn = ownerPostElement.querySelector(
  ".post-controls .show-replies, .show-replies, .post-action-menu__show-replies"
);
console.log("Toggle button:", toggleBtn);
```

### Monitor MutationObserver Activity

Check if observers are firing:

```javascript
// In expandEmbeddedReplies
const observer = new MutationObserver(() => {
  console.log("Expansion observer fired");
  // ... rest of logic
});
```

### Check Load More Button

If loading fails:

```javascript
const loadMoreBtn = section.querySelector(".load-more-replies");
console.log("Load more button:", loadMoreBtn);
console.log("Disabled?", loadMoreBtn?.disabled);
console.log("Loading?", loadMoreBtn?.classList.contains("loading"));
```

---

## Performance Monitoring

### Expected Timings

- **Expansion**: < 1 second (typical)
- **Load all (20 replies)**: 2-5 seconds (typical)
- **Scroll**: < 1 second (typical)
- **Total (collapsed flow)**: 3-7 seconds (typical)

### If Slow

1. Check network tab for API calls
2. Verify no infinite loops in load-more clicking
3. Check for excessive DOM mutations
4. Consider increasing timeouts if network is slow

---

## Common Issues and Solutions

### Issue: Section doesn't expand

**Possible causes**:
- Toggle button selector doesn't match
- Button is disabled or hidden
- Expansion timeout too short

**Solutions**:
- Inspect toggle button element, verify selector
- Check button state (disabled, aria-hidden)
- Increase timeout: `{ timeoutMs: 10000 }`

---

### Issue: Not all replies load

**Possible causes**:
- Max clicks reached (20)
- Timeout reached (10s)
- Load more button selector doesn't match

**Solutions**:
- Increase max clicks: `{ maxClicks: 30 }`
- Increase timeout: `{ timeoutMs: 15000 }`
- Verify button selector: `.load-more-replies`

---

### Issue: New reply doesn't scroll

**Possible causes**:
- Post not rendered yet when scroll attempted
- Selector doesn't match new post element
- Observer timeout

**Solutions**:
- Observer should catch late renders (10s timeout)
- Check post element selectors in `tryScrollToNewReply`
- Increase observer timeout if needed

---

### Issue: Duplicate still appears in main stream

**Possible causes**:
- `hideMainStreamDuplicateInOwnerMode` not called
- Post element selector doesn't match
- Race condition (post appended after hide attempt)

**Solutions**:
- Verify function is called in collapsed flow
- Check selectors in hide function
- Add retry logic if needed

---

### Issue: State doesn't clear

**Possible causes**:
- `finalizeCollapsedFlow` not called
- Exception thrown before finalize
- Navigation cleanup not working

**Solutions**:
- Ensure try/catch always calls finalize
- Check onPageChange cleanup logic
- Add defensive cleanup in multiple places

---

## Success Criteria

### All Tests Pass

- ✅ Collapsed section expands automatically
- ✅ All replies load (not just first page)
- ✅ New reply appears in embedded section
- ✅ Auto-scroll works
- ✅ Duplicate hidden from main stream
- ✅ Expanded section flow unchanged (regression)
- ✅ State clears properly
- ✅ No console errors
- ✅ No infinite loops
- ✅ Graceful timeout handling

### Performance Acceptable

- ✅ Expansion completes in < 2s (typical)
- ✅ Loading completes in < 10s (typical)
- ✅ No UI freezing or blocking
- ✅ Smooth scrolling animation

### User Experience

- ✅ Feels natural and automatic
- ✅ No jarring jumps or flashes
- ✅ Clear visual feedback (highlight)
- ✅ Works on mobile and desktop
- ✅ Works across different themes

---

## Rollback Plan

If issues arise, you can disable the collapsed flow by commenting out the detection:

```javascript
// Temporarily disable collapsed flow
const isCollapsed = false; // was: !section || !!hasToggleBtn;
```

Or disable the orchestration:

```javascript
// Temporarily disable orchestration
const needsExpansion = false; // was: replyToCollapsedSection && ...
```

This will revert to the expanded-only behavior while you debug.

