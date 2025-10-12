# Auto-Scroll Feature Testing Guide

## Prerequisites

1. Theme component installed and enabled
2. Owner comment mode active (filtered view with `?username_filters=owner`)
3. Topic with embedded posts/replies
4. Browser console open to view logs

## Test Cases

### Test 1: Basic Auto-Scroll (Fast Network)

**Setup:**
1. Navigate to a topic in owner comment mode
2. Find a post with embedded replies
3. Click "show replies" to expand if needed

**Steps:**
1. Click the embedded reply button
2. Type a test message in composer
3. Click "Create Post"

**Expected Result:**
- ✅ Console shows: `[Embedded Reply Buttons] AutoScroll: post:created fired`
- ✅ Console shows: `[Embedded Reply Buttons] AutoScroll: stored lastCreatedPost`
- ✅ "Load more replies" button clicked automatically
- ✅ New post appears in embedded section
- ✅ Page scrolls smoothly to new post
- ✅ New post has yellow/tertiary highlight for 2 seconds
- ✅ Console shows: `[Embedded Reply Buttons] AutoScroll: scrolling to post #X`
- ✅ Console shows: `[Embedded Reply Buttons] AutoScroll: clearing lastCreatedPost`

**Failure Indicators:**
- ❌ No scroll happens
- ❌ Scroll to wrong post
- ❌ No highlight appears
- ❌ Console errors

---

### Test 2: Slow Network Simulation

**Setup:**
1. Open Chrome DevTools → Network tab
2. Set throttling to "Slow 3G"
3. Navigate to topic in owner comment mode

**Steps:**
1. Click embedded reply button
2. Submit reply
3. Wait for observer to detect new post

**Expected Result:**
- ✅ Console shows: `[Embedded Reply Buttons] AutoScroll: setting up observer for new post`
- ✅ Observer waits for post to render (may take 2-5 seconds)
- ✅ Console shows: `[Embedded Reply Buttons] AutoScroll: observer successfully scrolled to new post`
- ✅ Scroll and highlight happen when post appears
- ✅ No timeout errors

**Failure Indicators:**
- ❌ Observer timeout after 10 seconds
- ❌ Post appears but no scroll
- ❌ Multiple scroll attempts

---

### Test 3: Already Expanded Section

**Setup:**
1. Navigate to topic in owner comment mode
2. Manually click "show replies" to expand embedded posts
3. Ensure "load more replies" button is NOT visible

**Steps:**
1. Click embedded reply button
2. Submit reply

**Expected Result:**
- ✅ No "load more replies" button to click
- ✅ Observer set up directly on embedded section
- ✅ New post appears
- ✅ Auto-scroll and highlight work correctly

**Failure Indicators:**
- ❌ Console error about missing button
- ❌ No scroll happens

---

### Test 4: Multiple Rapid Replies

**Setup:**
1. Navigate to topic in owner comment mode
2. Expand embedded posts

**Steps:**
1. Click embedded reply button
2. Submit first reply → Wait for scroll
3. Immediately click embedded reply button again
4. Submit second reply → Wait for scroll

**Expected Result:**
- ✅ First reply: Scrolls and highlights correctly
- ✅ State cleared after first scroll
- ✅ Second reply: Scrolls and highlights correctly
- ✅ No interference between the two
- ✅ Console shows state cleared between replies

**Failure Indicators:**
- ❌ Second reply doesn't scroll
- ❌ Scroll to first reply instead of second
- ❌ Duplicate scrolls

---

### Test 5: Non-Owner Comment Mode

**Setup:**
1. Navigate to topic WITHOUT `?username_filters` parameter
2. Or navigate with different user filter

**Steps:**
1. Try to use embedded reply button (if visible)
2. Submit reply

**Expected Result:**
- ✅ Console shows: `[Embedded Reply Buttons] AutoScroll: skipping - not in owner comment mode`
- ✅ No auto-scroll happens
- ✅ No state stored

**Failure Indicators:**
- ❌ Auto-scroll happens when it shouldn't
- ❌ State stored unnecessarily

---

### Test 6: Timeout Scenario

**Setup:**
1. Open Chrome DevTools → Network tab
2. Set throttling to "Offline"
3. Navigate to topic in owner comment mode

**Steps:**
1. Click embedded reply button
2. Submit reply
3. Wait 10+ seconds

**Expected Result:**
- ✅ Observer set up
- ✅ After 10 seconds: Console shows `[Embedded Reply Buttons] AutoScroll: observer timeout`
- ✅ Observer disconnects
- ✅ State cleared: `lastCreatedPost = null`
- ✅ No memory leaks

**Failure Indicators:**
- ❌ Observer never times out
- ❌ State not cleared
- ❌ Console errors

---

### Test 7: Mobile View

**Setup:**
1. Open Chrome DevTools → Toggle device toolbar
2. Select mobile device (e.g., iPhone 12)
3. Navigate to topic in owner comment mode

**Steps:**
1. Click embedded reply button
2. Submit reply

**Expected Result:**
- ✅ Auto-scroll works on mobile
- ✅ Highlight visible on mobile
- ✅ Smooth scroll animation
- ✅ No layout issues

**Failure Indicators:**
- ❌ Scroll doesn't work on mobile
- ❌ Highlight not visible
- ❌ Layout broken

---

### Test 8: Highlight Animation

**Setup:**
1. Navigate to topic in owner comment mode
2. Ensure browser supports CSS animations

**Steps:**
1. Click embedded reply button
2. Submit reply
3. Observe the highlight effect

**Expected Result:**
- ✅ New post has yellow/tertiary background pulse
- ✅ Left border appears in tertiary color
- ✅ Box shadow expands and contracts
- ✅ Animation lasts exactly 2 seconds
- ✅ Highlight class removed after animation

**Failure Indicators:**
- ❌ No highlight appears
- ❌ Highlight doesn't fade out
- ❌ Animation too fast/slow

---

## Console Log Checklist

When testing, verify these logs appear in order:

```
[Embedded Reply Buttons] AutoScroll: binding post:created listener
[Embedded Reply Buttons] AutoScroll: post:created fired {post_number: X, ...}
[Embedded Reply Buttons] AutoScroll: stored lastCreatedPost {postNumber: X, ...}
[Embedded Reply Buttons] AutoRefresh: composer:saved fired
[Embedded Reply Buttons] AutoRefresh: clicking loadMoreBtn immediately
[Embedded Reply Buttons] AutoScroll: searching for post #X in section
[Embedded Reply Buttons] AutoScroll: found element with selector: [data-post-number="X"]
[Embedded Reply Buttons] AutoScroll: scrolling to post #X
[Embedded Reply Buttons] AutoScroll: clearing lastCreatedPost after successful scroll
```

## Network Request Verification

When "load more replies" is clicked, verify this request in Network tab:

```
GET /posts/{post_id}/replies?after={number}
Status: 200 OK
Response: JSON with embedded posts
```

## Common Issues and Solutions

### Issue: No scroll happens
**Check:**
- Is `lastCreatedPost` set? (Check console)
- Is the post number correct?
- Is the element selector matching? (Try manual `document.querySelector()`)

### Issue: Scroll to wrong post
**Check:**
- Is `lastCreatedPost.postNumber` correct?
- Are there duplicate post numbers in DOM?
- Is the selector too broad?

### Issue: Highlight doesn't appear
**Check:**
- Is CSS loaded? (Check Elements tab)
- Is `.highlighted-reply` class added? (Check Elements tab)
- Are theme colors defined? (Check CSS variables)

### Issue: Observer timeout
**Check:**
- Is network slow/offline?
- Is the post actually being created?
- Is the embedded section rendering?

## Performance Testing

### Memory Leak Check
1. Open Chrome DevTools → Memory tab
2. Take heap snapshot
3. Submit 10 replies with auto-scroll
4. Take another heap snapshot
5. Compare: Should not see growing `MutationObserver` or `lastCreatedPost` objects

### Scroll Performance
1. Open Chrome DevTools → Performance tab
2. Start recording
3. Submit reply and wait for auto-scroll
4. Stop recording
5. Check: Scroll should be smooth (60fps), no jank

## Browser Compatibility Testing

Test in:
- ✅ Chrome/Edge (latest)
- ✅ Firefox (latest)
- ✅ Safari (latest)
- ✅ Mobile Safari (iOS)
- ✅ Chrome Mobile (Android)

## Regression Testing

After changes, verify:
1. Embedded reply buttons still work
2. Manual "load more replies" still works
3. Composer still opens correctly
4. Filtered view still works
5. Non-owner mode still blocks features

## Success Criteria

All tests pass with:
- ✅ No console errors
- ✅ Smooth scroll animation
- ✅ Visible highlight for 2 seconds
- ✅ Correct post scrolled to
- ✅ State cleaned up properly
- ✅ No memory leaks
- ✅ Works on mobile and desktop
- ✅ Works in all supported browsers

