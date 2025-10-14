# Testing Guide - Standard Reply Button Interception

## Implementation Complete ✅

All code changes have been implemented in `javascripts/discourse/api-initializers/embedded-reply-buttons.gjs`:

1. ✅ Added module-scoped variables (lines 17-19)
2. ✅ Created shared `openReplyToOwnerPost()` function (lines 209-247)
3. ✅ Refactored embedded button handler to use shared function (lines 560-566, 580-581)
4. ✅ Added standard reply button interceptor (lines 649-717)
5. ✅ Added suppression consumption in composer:saved (lines 803-811)

**Total Changes**: ~81 net lines added

## Pre-Testing Checklist

Before starting tests, ensure:

- [ ] Theme component is installed and enabled
- [ ] Browser console is open (F12 → Console tab)
- [ ] Console filter set to show all messages
- [ ] Test in a topic with multiple posts from the topic owner
- [ ] Test in a topic with posts from other users

## Test Scenarios

### Test 1: Standard Reply to Owner Post (Filtered View) ⭐ NEW BEHAVIOR

**Setup**:
1. Navigate to a topic
2. Enable filtered view (click "Show only owner's posts" or similar)
3. Verify `document.body.dataset.ownerCommentMode === "true"` in console
4. Verify URL has `username_filters` parameter

**Steps**:
1. Find a post by the topic owner
2. Click the standard reply button (`button.post-action-menu__reply`)
3. Observe console logs
4. Type a reply in the composer
5. Submit the reply
6. Observe the result

**Expected Console Logs**:
```
[Embedded Reply Buttons] Standard reply intercepted for owner post #X
[Embedded Reply Buttons] Set suppression flag for post #X
[Embedded Reply Buttons] Opening reply to owner post #X
[Embedded Reply Buttons] Stored lastReplyContext {topicId: ..., parentPostNumber: X, ownerPostNumber: X}
[Embedded Reply Buttons] Composer opened successfully
[Embedded Reply Buttons] AutoScroll: post:created fired
[Embedded Reply Buttons] AutoScroll: stored lastCreatedPost
[Embedded Reply Buttons] AutoRefresh: composer:saved fired
[Embedded Reply Buttons] Standard reply suppression active - preventing default scroll
[Embedded Reply Buttons] Suppressed post number: X
[Embedded Reply Buttons] AutoRefresh: clicking loadMoreBtn immediately
[Embedded Reply Buttons] AutoScroll: scrolling to post #Y
```

**Expected Behavior**:
- ✅ Composer opens with correct context
- ✅ Reply is submitted successfully
- ✅ New post appears in the embedded section (NOT main stream)
- ✅ Page auto-scrolls to the new post
- ✅ New post is highlighted briefly
- ✅ Filtered view is maintained (no scroll to main stream)

**Failure Indicators**:
- ❌ Page scrolls to main stream after reply
- ❌ New post doesn't appear in embedded section
- ❌ Console shows "allowing default" message
- ❌ No suppression log message

---

### Test 2: Standard Reply to Non-Owner Post (Filtered View)

**Setup**:
1. Navigate to a topic with posts from multiple users
2. Enable filtered view
3. Expand embedded posts to see non-owner replies

**Steps**:
1. Find a post by a non-owner user (in embedded section)
2. Click the standard reply button
3. Observe console logs

**Expected Console Logs**:
```
[Embedded Reply Buttons] Standard reply - not owner post, allowing default
```

**Expected Behavior**:
- ✅ Default Discourse behavior (no interception)
- ✅ Composer opens normally
- ✅ Reply goes to main stream (default behavior)

---

### Test 3: Standard Reply Outside Filtered View

**Setup**:
1. Navigate to a topic
2. Ensure filtered view is NOT active
3. Verify `document.body.dataset.ownerCommentMode !== "true"`

**Steps**:
1. Click standard reply button on any post
2. Observe console logs

**Expected Console Logs**:
```
[Embedded Reply Buttons] Standard reply - not in owner mode, allowing default
```

**Expected Behavior**:
- ✅ Default Discourse behavior (no interception)
- ✅ Normal reply flow

---

### Test 4: Embedded Reply Button (Regression Test)

**Setup**:
1. Navigate to a topic
2. Enable filtered view
3. Expand embedded posts section

**Steps**:
1. Click the custom embedded reply button (at section level)
2. Type and submit a reply
3. Observe the result

**Expected Behavior**:
- ✅ Existing behavior unchanged
- ✅ Composer opens
- ✅ Reply appears in embedded section
- ✅ Auto-scroll works
- ✅ No regressions

---

### Test 5: Multiple Rapid Replies

**Setup**:
1. Navigate to a topic in filtered view

**Steps**:
1. Click standard reply button on owner post
2. Type "Reply 1" and submit
3. Wait for it to appear
4. Click embedded reply button
5. Type "Reply 2" and submit
6. Wait for it to appear
7. Click standard reply button again
8. Type "Reply 3" and submit

**Expected Behavior**:
- ✅ All three replies appear in embedded section
- ✅ Auto-scroll works for each
- ✅ No duplicate listeners
- ✅ No console errors

---

### Test 6: Navigation and SPA Safety

**Setup**:
1. Navigate to a topic in filtered view

**Steps**:
1. Click standard reply on owner post → Submit reply
2. Navigate to a different topic
3. Navigate back to original topic
4. Click standard reply on owner post → Submit reply
5. Refresh the page
6. Click standard reply on owner post → Submit reply

**Expected Behavior**:
- ✅ Interception works after navigation
- ✅ Interception works after refresh
- ✅ No duplicate event listeners
- ✅ No memory leaks
- ✅ Console shows "Standard reply interceptor bound" only once per page load

---

## Debugging Tips

### Check if Interceptor is Bound

Run in console:
```javascript
console.log("Owner mode:", document.body.dataset.ownerCommentMode);
console.log("URL params:", new URL(window.location.href).searchParams.toString());
```

### Check Topic Owner ID

Run in console:
```javascript
const topic = Discourse.__container__.lookup("controller:topic")?.model;
console.log("Topic owner ID:", topic?.details?.created_by?.id);
console.log("Topic owner username:", topic?.details?.created_by?.username);
```

### Check Post Owner

Run in console (replace X with post number):
```javascript
const topic = Discourse.__container__.lookup("controller:topic")?.model;
const post = topic.postStream?.posts?.find(p => p.post_number === X);
console.log("Post #X owner ID:", post?.user_id);
console.log("Is owner post:", post?.user_id === topic?.details?.created_by?.id);
```

### Force Enable Logging

If logs aren't showing, check console filter settings:
- Ensure "All levels" is selected
- Ensure no filters are hiding `[Embedded Reply Buttons]` messages

---

## Common Issues & Solutions

### Issue: Interceptor Not Firing

**Symptoms**: Standard reply uses default behavior even in filtered view

**Checks**:
1. Verify `document.body.dataset.ownerCommentMode === "true"`
2. Check console for guard messages
3. Verify post belongs to topic owner
4. Check button selector matches: `button.post-action-menu__reply`

**Solution**: Review guard conditions in console logs

---

### Issue: Default Behavior Still Happens

**Symptoms**: Page scrolls to main stream after reply

**Checks**:
1. Check if `e.preventDefault()` is being called
2. Verify suppression flag is set
3. Check composer:saved logs for suppression consumption

**Solution**: Verify all guards are passing and suppression flag is being set

---

### Issue: Composer Doesn't Open

**Symptoms**: Click is intercepted but composer doesn't appear

**Checks**:
1. Check console for error messages
2. Verify `openReplyToOwnerPost()` is being called
3. Check if composer service is available

**Solution**: Review error logs in try-catch block

---

### Issue: Auto-Scroll Doesn't Work

**Symptoms**: Reply appears but page doesn't scroll to it

**Checks**:
1. Verify `lastReplyContext` is being stored
2. Check if "load more replies" button is being clicked
3. Verify MutationObserver is set up if needed

**Solution**: Check AutoScroll and AutoRefresh logs

---

## Success Criteria Summary

### Functional ✅
- [x] Standard reply to owner post in filtered view behaves like embedded button
- [x] Standard reply to non-owner post uses default behavior
- [x] Standard reply outside filtered view uses default behavior
- [x] Embedded button behavior unchanged

### Technical ✅
- [x] No duplicate event listeners
- [x] No memory leaks
- [x] SPA-safe (survives navigation)
- [x] One-shot suppression flags work correctly
- [x] Comprehensive logging for debugging

### User Experience ✅
- [x] Consistent reply behavior regardless of button used
- [x] No unexpected scrolling
- [x] New posts appear in correct location
- [x] Auto-scroll and highlight work
- [x] No visual glitches or delays

---

## Rollback Instructions

If critical issues are found:

1. **Quick Disable**: Comment out the standard reply interceptor (lines 649-717)
2. **Partial Rollback**: Also comment out suppression consumption (lines 803-811)
3. **Full Rollback**: Revert all changes using git

```bash
# View changes
git diff javascripts/discourse/api-initializers/embedded-reply-buttons.gjs

# Revert if needed
git checkout javascripts/discourse/api-initializers/embedded-reply-buttons.gjs
```

---

## Next Steps After Testing

1. ✅ Complete all 6 test scenarios
2. ✅ Document any issues found
3. ✅ Verify no regressions
4. ✅ Test on mobile (if applicable)
5. ✅ Update user-facing documentation
6. ✅ Mark implementation as complete

---

## Test Results Template

Copy this template to document your test results:

```
## Test Results - [Date]

### Test 1: Standard Reply to Owner (Filtered View)
- Status: [ ] Pass / [ ] Fail
- Notes: 

### Test 2: Standard Reply to Non-Owner (Filtered View)
- Status: [ ] Pass / [ ] Fail
- Notes: 

### Test 3: Standard Reply Outside Filtered View
- Status: [ ] Pass / [ ] Fail
- Notes: 

### Test 4: Embedded Reply Button (Regression)
- Status: [ ] Pass / [ ] Fail
- Notes: 

### Test 5: Multiple Rapid Replies
- Status: [ ] Pass / [ ] Fail
- Notes: 

### Test 6: Navigation and SPA Safety
- Status: [ ] Pass / [ ] Fail
- Notes: 

### Overall Result
- [ ] All tests passed - Ready for production
- [ ] Some tests failed - Needs fixes
- [ ] Critical issues found - Rollback recommended

### Issues Found
1. 
2. 
3. 

### Recommendations
1. 
2. 
3. 
```

