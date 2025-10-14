# Testing Checklist

**Date**: 2025-10-14  
**Phase**: 4 Complete - Ready for Testing

---

## Pre-Test Setup

- [ ] All files saved
- [ ] No syntax errors (verified by IDE)
- [ ] Theme deployed to Discourse instance
- [ ] Admin access available
- [ ] Browser DevTools ready (F12)

---

## Quick Test (5 minutes)

### 1. Verify No Errors
- [ ] Navigate to any topic
- [ ] Open console (F12)
- [ ] No JavaScript errors appear
- [ ] Page loads normally

### 2. Test Logging Disabled (Default)
- [ ] Clear console
- [ ] Navigate to topic in configured category
- [ ] Console is clean (no `[Owner View]` logs)
- [ ] Features work normally

### 3. Enable Debug Logging
- [ ] Go to Admin → Customize → Themes → Owner Comments → Settings
- [ ] Find `debug_logging_enabled` setting
- [ ] Check the box to enable
- [ ] Click "Save"
- [ ] Refresh the page (Ctrl+Shift+R)

### 4. Test Logging Enabled
- [ ] Clear console
- [ ] Navigate to topic in configured category
- [ ] Logs appear with `[Owner View]` prefix
- [ ] Logs include structured context objects
- [ ] Logs are readable and helpful

### 5. Test Feature Functionality
- [ ] Auto-filter applies (URL has `?username_filters=<owner>`)
- [ ] Only owner's posts visible
- [ ] Toggle button appears
- [ ] Toggle button works (click to unfiltered/filtered)
- [ ] No console errors

### 6. Disable Logging Again
- [ ] Go to Admin → Settings
- [ ] Uncheck `debug_logging_enabled`
- [ ] Save and refresh
- [ ] Console is clean again
- [ ] Features still work

---

## Expected Console Output

### When Disabled:
```
(empty - no [Owner View] logs)
```

### When Enabled:
```
[Owner View] [Owner Comments] === Page change detected === {url: "..."}
[Owner View] [Owner Comments] Running afterRender hook
[Owner View] [Owner Comments] Topic controller resolved {...}
[Owner View] [Owner Comments] Current state {...}
[Owner View] [Owner Comments] Category check result {...}
[Owner View] [Group Access Control] Access decision {...}
```

---

## Full Test (Optional - 30-60 minutes)

See `docs/TESTING_GUIDE.md` for comprehensive testing.

### Core Tests:
- [ ] Test 1: Logging disabled by default
- [ ] Test 2: Enable debug logging
- [ ] Test 3: Feature functionality (logging disabled)
- [ ] Test 4: Logging content (logging enabled)
- [ ] Test 5: Throttling verification
- [ ] Test 6: Error logging (always on)
- [ ] Test 7: Performance check
- [ ] Test 8: Cross-browser compatibility
- [ ] Test 9: Mobile view
- [ ] Test 10: Regression testing

---

## Issues Found

### Issue Template:
```
Issue #: ___
Test: ___________
Problem: ___________
Console Error: ___________
Expected: ___________
Actual: ___________
Screenshot: ___________
```

---

## Test Results

### Quick Test Result:
- [ ] ✅ PASS - All tests passed, ready to proceed
- [ ] ❌ FAIL - Issues found (document above)

### Full Test Result (if performed):
- [ ] ✅ PASS - All tests passed
- [ ] ❌ FAIL - Issues found (document above)

---

## Next Steps

### If All Tests Pass ✅:
1. [ ] Commit changes to git
2. [ ] Update progress document
3. [ ] Proceed to Phase 5 (embedded-reply-buttons.gjs)

### If Tests Fail ❌:
1. [ ] Document all issues
2. [ ] Share issues for debugging
3. [ ] Fix issues
4. [ ] Re-test
5. [ ] Do not proceed until all pass

---

## Sign-Off

**Tested by**: ___________  
**Date**: ___________  
**Result**: ✅ PASS / ❌ FAIL  
**Notes**: ___________

---

**Ready to proceed to Phase 5**: YES / NO


