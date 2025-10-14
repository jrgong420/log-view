# 🧪 Quick Test Card - 5 Minute Verification

## Setup (30 seconds)
1. Deploy theme to Discourse
2. **Admin → Customize → Themes → log-view → Settings**
3. ✅ Enable `debug_logging_enabled`
4. Open browser console (`F12`)

---

## Critical Test: Second Reply Bug Fix 🎯

### The Bug We Fixed
**Problem**: Second reply without page reload reverted to stock behavior  
**Fix**: Eliminated stale state, added direct owner lookup

### Test Steps (3 minutes)

1. **Navigate** to topic in owner comment mode
2. **Collapse** owner's embedded replies section
3. **First Reply**:
   - Click Reply on collapsed section
   - Type: "First test"
   - Submit
   - ✅ Should expand, load replies, scroll to new post

4. **Second Reply** (THE BUG TEST):
   - Collapse section again
   - Click Reply on collapsed section
   - Type: "Second test"
   - Submit
   - ✅ **Should work exactly like first reply**
   - ✅ Reply appears below first reply in embedded section
   - ❌ **NOT** in main stream (old bug behavior)

5. **Check Console Logs**:
   ```
   ✅ GOOD: "AutoRefresh: collapsed detected for owner post #807"
            (same post number as first reply)
   
   ❌ BAD:  "AutoRefresh: collapsed detected for owner post #795"
            (different post number = bug still present)
   ```

---

## Quick Logging Test (1 minute)

1. ✅ Verify logs appear in console with prefixes:
   - `[Owner View] [Embedded Reply Buttons]`
   - `[Owner View] [Owner Comment Prototype]`

2. ✅ Disable `debug_logging_enabled` in settings

3. ✅ Refresh page - logs should disappear

---

## Success Criteria ✅

- ✅ Second reply works correctly (bug fixed)
- ✅ Logs appear when enabled
- ✅ Logs disappear when disabled
- ✅ No console errors
- ✅ No performance issues

---

## If Tests Pass ✅

Report: "All tests passed! Ready for production."

## If Tests Fail ❌

Share:
1. Which test failed
2. Console logs (copy/paste)
3. Expected vs actual behavior

---

**Full test guide**: See `docs/TEST_SESSION.md`

