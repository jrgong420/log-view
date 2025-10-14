# Phase 9: Manual Testing and Verification Workflow

**Status**: 🔄 IN PROGRESS  
**Date**: 2025-10-14

---

## Overview

This phase verifies that:
1. ✅ Centralized logger migration works correctly
2. ✅ Stale-state bug fix is effective
3. ✅ No regressions introduced
4. ✅ Performance is acceptable

---

## Pre-Deployment Checklist

### Local Verification
- [x] All files migrated to centralized logger (8/8 files)
- [x] No syntax errors (`diagnostics` passed)
- [x] Logger import correct in all files
- [x] Bug fix changes in place (embedded-reply-buttons.gjs)

### Deployment Steps
- [ ] Deploy theme to Discourse instance
  ```bash
  # Option 1: Using discourse_theme CLI
  discourse_theme watch .
  
  # Option 2: Manual upload
  # Admin → Customize → Themes → Import → From directory
  ```

- [ ] Verify theme is active
- [ ] Enable `debug_logging_enabled` setting
  - Admin → Customize → Themes → log-view → Settings
  - Toggle `debug_logging_enabled` to ON
  - Save

---

## Test Scenarios

### Scenario A: Critical Bug Fix Verification 🎯

**Priority**: CRITICAL  
**Estimated Time**: 5 minutes

**Setup**:
1. Navigate to a topic in owner comment mode (filtered view)
2. Ensure owner's embedded replies section is collapsed
3. Open browser console (F12)

**Test Steps**:
1. **First Reply**:
   - Click Reply button on collapsed owner section
   - Type: "Test reply 1"
   - Submit
   - ✅ Verify: Section expands, replies load, new post appears, auto-scroll works

2. **Second Reply** (WITHOUT PAGE RELOAD):
   - Collapse owner section again
   - Click Reply button on collapsed owner section
   - Type: "Test reply 2"
   - Submit
   - ✅ Verify: Section expands, replies refresh, new post appears BELOW first reply

3. **Console Log Check**:
   - Look for: `AutoRefresh: collapsed detected for owner post #XXX`
   - ✅ Verify: Same post number for both replies
   - ❌ Fail if: Different post numbers (indicates stale state bug)

**Success Criteria**:
- [ ] Both replies work identically
- [ ] Second reply appears in embedded section (not main stream)
- [ ] Console shows same owner post number
- [ ] No errors in console

**If Failed**: STOP and report - this is a critical regression

---

### Scenario B: Logging System Verification

**Priority**: HIGH  
**Estimated Time**: 3 minutes

**Test Steps**:
1. **Logging Enabled**:
   - Navigate to any topic in owner comment mode
   - ✅ Verify logs appear in console with prefixes:
     - `[Owner View] [Embedded Reply Buttons]`
     - `[Owner View] [Owner Comment Prototype]`
     - `[Owner View] [Toggle Button]`
   - ✅ Verify structured context objects (expandable in console)

2. **Logging Disabled**:
   - Admin → Settings → Disable `debug_logging_enabled`
   - Refresh page
   - Navigate to topic
   - ✅ Verify: No debug/info/warn logs appear
   - ✅ Verify: Features still work normally

**Success Criteria**:
- [ ] Logs appear when enabled
- [ ] Logs disappear when disabled
- [ ] Errors (if any) still visible when disabled
- [ ] No performance degradation

---

### Scenario C: Embedded Reply Flow

**Priority**: HIGH  
**Estimated Time**: 5 minutes

**Test Steps**:
1. Navigate to topic in owner comment mode
2. Test embedded reply button:
   - Click Reply on owner's embedded section
   - Type message
   - Submit
   - ✅ Verify: Reply appears in embedded section
   - ✅ Verify: Auto-scroll to new reply
   - ✅ Verify: Reply highlighted briefly

3. Test with expanded section:
   - Expand owner section (if collapsed)
   - Click Reply
   - Submit
   - ✅ Verify: Reply appears, no expansion needed
   - ✅ Verify: Auto-scroll works

**Success Criteria**:
- [ ] Reply buttons work correctly
- [ ] Auto-refresh works (collapsed and expanded)
- [ ] Auto-scroll works
- [ ] No duplicate posts in main stream

---

### Scenario D: Standard Reply Interception

**Priority**: MEDIUM  
**Estimated Time**: 2 minutes

**Test Steps**:
1. Navigate to topic in owner comment mode (filtered view)
2. Find a non-owner post (reply from someone else)
3. Click standard Reply button on that post
4. ✅ Verify: Composer opens to reply to OWNER post (not clicked post)
5. Check console: `Standard reply intercepted for owner post #XXX`

**Success Criteria**:
- [ ] Reply interception works
- [ ] Composer targets owner post
- [ ] Console shows interception log
- [ ] No errors

---

### Scenario E: Toggle Button

**Priority**: MEDIUM  
**Estimated Time**: 2 minutes

**Test Steps**:
1. Navigate to topic in owner comment mode (filtered)
2. Click "Show All Posts" toggle button
3. ✅ Verify: URL changes (username_filters removed)
4. ✅ Verify: All posts visible
5. ✅ Verify: Button text changes to "Show Owner Comments Only"
6. Click toggle again
7. ✅ Verify: Returns to filtered view

**Success Criteria**:
- [ ] Toggle switches between filtered/unfiltered
- [ ] URL updates correctly
- [ ] Button text updates
- [ ] Console shows navigation logs

---

### Scenario F: Rate-Limiting (MutationObserver)

**Priority**: LOW  
**Estimated Time**: 2 minutes

**Test Steps**:
1. Navigate to topic in owner comment mode
2. Rapidly expand/collapse owner sections (click 10+ times quickly)
3. Watch console logs
4. ✅ Verify: Logs appear but are throttled (not flooding)
5. ✅ Verify: Features still work despite rapid clicking

**Success Criteria**:
- [ ] Console doesn't flood with hundreds of logs
- [ ] Throttling works (2-second gaps)
- [ ] No performance issues
- [ ] Features remain responsive

---

### Scenario G: Performance Check

**Priority**: MEDIUM  
**Estimated Time**: 3 minutes

**Test Steps**:
1. Disable `debug_logging_enabled`
2. Open DevTools → Performance tab
3. Start recording
4. Navigate to topic in owner comment mode
5. Interact with features (reply, toggle, etc.)
6. Stop recording
7. Analyze performance trace

**Success Criteria**:
- [ ] No logging overhead visible in trace
- [ ] Page load time unchanged
- [ ] No console.log calls in trace
- [ ] Smooth interactions

---

## Test Results Summary

### Critical Tests
- [ ] Scenario A: Bug Fix ✅ / ❌
- [ ] Scenario B: Logging System ✅ / ❌
- [ ] Scenario C: Embedded Reply Flow ✅ / ❌

### Important Tests
- [ ] Scenario D: Reply Interception ✅ / ❌
- [ ] Scenario E: Toggle Button ✅ / ❌

### Optional Tests
- [ ] Scenario F: Rate-Limiting ✅ / ❌
- [ ] Scenario G: Performance ✅ / ❌

---

## Issues Found

### Critical Issues
```
(None expected - report here if found)
```

### Non-Critical Issues
```
(Report minor issues here)
```

---

## Performance Metrics

| Metric | Before | After | Change |
|--------|--------|-------|--------|
| Page Load Time | ___ ms | ___ ms | ___ |
| Console Log Count (debug ON) | N/A | ___ | N/A |
| Console Log Count (debug OFF) | 0 | ___ | ___ |
| Memory Usage | ___ MB | ___ MB | ___ |

---

## Next Steps

### If All Tests Pass ✅
1. Mark Phase 9 as COMPLETE
2. Proceed to Phase 10 (Documentation and Cleanup)
3. Consider production deployment

### If Tests Fail ❌
1. Document failures in detail
2. Share console logs
3. Create bug report
4. Fix issues before proceeding

---

## Sign-Off

**Tester**: _______________  
**Date**: _______________  
**Overall Status**: [ ] PASS [ ] FAIL [ ] NEEDS WORK

**Ready for Production**: [ ] YES [ ] NO

---

**End of Phase 9 Testing Workflow**

