# Embedded Reply Buttons - Testing Guide

## Overview

This document provides comprehensive testing instructions for the embedded reply buttons feature, which allows users to reply to embedded posts directly from the filtered view without losing context.

## Feature Description

When viewing a topic in filtered mode (owner comment mode), embedded posts from other users are displayed in `section.embedded-posts`. This feature adds a "Reply" button to each embedded post that:

1. Opens the Discourse composer programmatically
2. Pre-populates the reply context (replying to the parent owner's post)
3. Keeps the user on the filtered view page
4. Maintains the filtered view after posting the reply

## Prerequisites

### Test Environment Setup

1. **Discourse Instance**: You need a Discourse instance with this theme component installed
2. **Test Topic**: Create a topic with:
   - An owner (topic creator) who makes several posts
   - Other users who reply to the owner's posts
   - Nested replies (replies to replies) for comprehensive testing
3. **User Accounts**: 
   - Topic owner account
   - Non-owner account(s) for testing

### Enable the Feature

1. Navigate to Admin → Customize → Themes
2. Select the log-view theme component
3. Ensure the component is active
4. The embedded reply buttons feature activates automatically when in owner comment mode

## Testing Procedure

### Test 1: Basic Button Injection

**Objective**: Verify that reply buttons are injected into embedded posts

**Steps**:
1. Navigate to a test topic
2. Click the "Show Owner Comments" toggle (or equivalent) to enter filtered view
3. Open browser DevTools Console
4. Look for embedded posts sections

**Expected Console Output**:
```
[Embedded Reply Buttons] Initializer starting...
[Embedded Reply Buttons] Binding global click handler...
[Embedded Reply Buttons] Global click handler bound successfully
[Embedded Reply Buttons] Initializer setup complete
[Embedded Reply Buttons] Page change detected: { url: "...", title: "..." }
[Embedded Reply Buttons] afterRender: Checking for embedded posts...
[Embedded Reply Buttons] Owner comment mode: true
[Embedded Reply Buttons] Found X embedded post sections
[Embedded Reply Buttons] Processing embedded section 1...
[Embedded Reply Buttons] Found Y embedded items in section 1
[Embedded Reply Buttons] Section 1, Item 1: Injecting reply button...
[Embedded Reply Buttons] Section 1, Item 1: Button injected successfully
```

**Expected Visual Result**:
- Each embedded post should have a small "Reply" button
- Button should be styled with theme colors (tertiary background)
- Button should be positioned near post info or post actions

**Pass Criteria**:
- ✅ Reply buttons appear on all embedded posts
- ✅ Console logs show successful injection
- ✅ No JavaScript errors in console

### Test 2: Button Idempotency

**Objective**: Verify that buttons are not duplicated on re-renders

**Steps**:
1. While in filtered view with embedded posts visible
2. Navigate away from the topic (e.g., to topic list)
3. Navigate back to the same topic
4. Check the embedded posts

**Expected Console Output**:
```
[Embedded Reply Buttons] Section 1, Item 1: Button already bound, skipping
[Embedded Reply Buttons] Section 1, Item 2: Button already bound, skipping
```

**Pass Criteria**:
- ✅ Only one reply button per embedded post
- ✅ Console shows "already bound, skipping" messages
- ✅ No duplicate buttons

### Test 3: Composer Opening

**Objective**: Verify that clicking a reply button opens the composer correctly

**Steps**:
1. In filtered view, locate an embedded post with a reply button
2. Click the "Reply" button
3. Observe the console output and composer behavior

**Expected Console Output**:
```
[Embedded Reply Buttons] Reply button clicked: <button>
[Embedded Reply Buttons] Topic model: { id: X, ... }
[Embedded Reply Buttons] Composer service: ComposerService { ... }
[Embedded Reply Buttons] Parent post number: "1"
[Embedded Reply Buttons] Parent post model: { id: Y, post_number: 1, ... }
[Embedded Reply Buttons] Draft key: "topic_123"
[Embedded Reply Buttons] Draft sequence: 0
[Embedded Reply Buttons] Opening composer with options: { action: "REPLY", ... }
[Embedded Reply Buttons] Composer opened successfully
```

**Expected Visual Result**:
- Composer opens at the bottom of the page
- Composer shows "Replying to [username]" indicator
- Reply context is set to the parent owner's post
- Page does not navigate away

**Pass Criteria**:
- ✅ Composer opens without errors
- ✅ Reply context is correct (replying to parent post)
- ✅ User remains on the filtered view page
- ✅ URL still contains `?username_filters=...`

### Test 4: Reply Context Verification

**Objective**: Verify that the reply is targeting the correct post

**Steps**:
1. Click reply button on an embedded post
2. In the composer, check the reply indicator
3. Type a test message
4. Submit the reply
5. Check where the reply appears in the topic

**Expected Behavior**:
- Reply indicator should show the username of the parent post author (topic owner)
- After posting, the reply should be a direct reply to the parent post
- The reply should appear in the correct position in the topic thread

**Pass Criteria**:
- ✅ Reply targets the correct parent post
- ✅ Reply appears in the correct thread position
- ✅ Reply-to relationship is correct in the topic structure

### Test 5: Filtered View Persistence

**Objective**: Verify that the filtered view is maintained after posting

**Steps**:
1. In filtered view, click reply button on an embedded post
2. Type and submit a reply
3. Observe the page behavior after posting

**Expected Behavior**:
- User should remain in filtered view (or return to it)
- URL should still contain `?username_filters=...`
- The new reply should be visible (if it's from the owner) or hidden (if from non-owner)

**Pass Criteria**:
- ✅ Filtered view is maintained
- ✅ URL parameter is preserved
- ✅ No unwanted navigation occurs

### Test 6: Non-Filtered View Behavior

**Objective**: Verify that buttons do NOT appear in normal (non-filtered) view

**Steps**:
1. Navigate to a topic in normal view (without username_filters)
2. Check for embedded posts
3. Verify no reply buttons are injected

**Expected Console Output**:
```
[Embedded Reply Buttons] Owner comment mode: false
[Embedded Reply Buttons] Not in owner comment mode, skipping button injection
```

**Pass Criteria**:
- ✅ No reply buttons appear in normal view
- ✅ Console shows "skipping button injection"
- ✅ Feature only activates in filtered view

### Test 7: Multiple Embedded Sections

**Objective**: Verify that buttons work across multiple embedded post sections

**Steps**:
1. Find or create a topic where multiple owner posts have embedded replies
2. Enter filtered view
3. Verify buttons appear in all embedded sections
4. Test clicking buttons in different sections

**Expected Behavior**:
- All embedded sections should have reply buttons
- Clicking any button should open the composer with correct context
- Each button should target its respective parent post

**Pass Criteria**:
- ✅ Buttons appear in all embedded sections
- ✅ Each button works independently
- ✅ Reply context is correct for each section

### Test 8: Error Handling

**Objective**: Verify graceful error handling when data is missing

**Steps**:
1. Test scenarios where data might be missing:
   - Click button before topic model is fully loaded
   - Test with malformed DOM structure
   - Test with missing post numbers

**Expected Console Output** (for errors):
```
[Embedded Reply Buttons] No topic model found
[Embedded Reply Buttons] No composer service found
[Embedded Reply Buttons] No parent post container found
[Embedded Reply Buttons] Could not find post model for post number X
```

**Pass Criteria**:
- ✅ Errors are logged clearly
- ✅ No uncaught exceptions
- ✅ Feature degrades gracefully

### Test 9: SPA Navigation

**Objective**: Verify that the feature works correctly with Discourse's SPA routing

**Steps**:
1. Navigate to a topic in filtered view
2. Click a reply button and open the composer
3. Close the composer
4. Navigate to a different topic (without page reload)
5. Navigate back to the original topic
6. Click a reply button again

**Expected Behavior**:
- Buttons should work after SPA navigation
- No duplicate event listeners
- No memory leaks

**Pass Criteria**:
- ✅ Buttons work after navigation
- ✅ Only one click handler is bound (check console on init)
- ✅ No performance degradation

### Test 10: Mobile/Responsive Testing

**Objective**: Verify that buttons work on mobile devices

**Steps**:
1. Test on mobile device or use browser DevTools mobile emulation
2. Navigate to filtered view
3. Verify buttons are visible and clickable
4. Test composer opening on mobile

**Pass Criteria**:
- ✅ Buttons are visible on mobile
- ✅ Buttons are easily tappable (adequate size)
- ✅ Composer opens correctly on mobile
- ✅ No layout issues

## Debugging Tips

### Enable Verbose Logging

The feature already includes comprehensive console logging. To view:
1. Open browser DevTools (F12)
2. Go to Console tab
3. Filter by "[Embedded Reply Buttons]"

### Common Issues and Solutions

**Issue**: Buttons not appearing
- **Check**: Is owner comment mode active? (`document.body.dataset.ownerCommentMode`)
- **Check**: Are there embedded posts? (`document.querySelectorAll('section.embedded-posts')`)
- **Check**: Console for error messages

**Issue**: Composer not opening
- **Check**: Console for error messages about missing models
- **Check**: Topic model is loaded (`api.container.lookup("controller:topic")?.model`)
- **Check**: Composer service is available

**Issue**: Wrong reply context
- **Check**: Parent post number in console logs
- **Check**: Post model lookup in topic.postStream.posts
- **Check**: Reply indicator in composer

## Success Criteria Summary

The feature is working correctly if:

1. ✅ Reply buttons appear on all embedded posts in filtered view
2. ✅ Buttons do NOT appear in normal (non-filtered) view
3. ✅ Clicking a button opens the composer without navigation
4. ✅ Reply context targets the correct parent post
5. ✅ Filtered view is maintained after posting
6. ✅ No duplicate buttons on re-renders
7. ✅ No JavaScript errors in console
8. ✅ Works across SPA navigation
9. ✅ Works on mobile devices
10. ✅ Comprehensive console logging aids debugging

## Reporting Issues

When reporting issues, please include:
1. Full console output (filter by "[Embedded Reply Buttons]")
2. Browser and version
3. Discourse version
4. Steps to reproduce
5. Expected vs actual behavior
6. Screenshots if applicable

