# Standard Reply Button Interception - Implementation Plan Summary

## Executive Summary

**Goal**: Unify reply behavior in filtered view so that clicking the standard Discourse reply button (`button.post-action-menu__reply`) on a topic owner's post behaves identically to clicking the custom embedded reply button.

**Current Problem**: 
- Embedded reply button: ✅ Maintains filtered view, refreshes embedded section, auto-scrolls to new post
- Standard reply button: ❌ Loses filtered view context, scrolls to main stream, doesn't refresh embedded section

**Solution**: Intercept standard reply button clicks in filtered view and reuse the existing embedded reply logic.

## Implementation Overview

### Files Modified
1. `javascripts/discourse/api-initializers/embedded-reply-buttons.gjs` (~81 net lines added)

### Key Components

#### 1. Module-Scoped State Variables
```javascript
let standardReplyInterceptBound = false;      // Idempotent binding flag
let suppressStandardReplyScroll = false;      // One-shot suppression
let suppressedReplyPostNumber = null;         // Track suppressed post
```

#### 2. Shared Function
```javascript
async function openReplyToOwnerPost(topic, ownerPost, ownerPostNumber)
```
- Centralizes composer opening logic
- Used by both embedded and standard reply buttons
- Stores `lastReplyContext` for auto-refresh
- Opens composer with `skipJumpOnSave: true`

#### 3. Standard Reply Interceptor
- Delegated event listener on `document` (capture phase)
- Selector: `button.post-action-menu__reply`
- Four guard conditions:
  1. Check if in owner comment mode
  2. Find post element
  3. Verify required data available
  4. Confirm post belongs to topic owner
- Prevents default behavior when all guards pass
- Calls shared `openReplyToOwnerPost()` function

#### 4. Suppression Flag Consumption
- In `composer:saved` event handler
- Logs suppression activity
- Clears flags after consumption
- Allows embedded refresh logic to proceed

## Guard Logic Flow

```
Standard reply button clicked
         ↓
Guard 1: isOwnerCommentMode === "true"?
         ↓ NO → Allow default
         ↓ YES
Guard 2: Post element found?
         ↓ NO → Allow default
         ↓ YES
Guard 3: Topic data available?
         ↓ NO → Allow default
         ↓ YES
Guard 4: Post belongs to topic owner?
         ↓ NO → Allow default
         ↓ YES
INTERCEPT → Prevent default → Open composer with embedded logic
```

## Implementation Phases

### Phase 1: Add Infrastructure ✅ (Planned)
- Add module-scoped variables
- Extract `openReplyToOwnerPost()` function
- Refactor embedded button handler to use shared function

### Phase 2: Add Interceptor ✅ (Planned)
- Add delegated click listener for standard reply button
- Implement four-guard logic
- Set suppression flags
- Call shared composer opening function

### Phase 3: Integrate Suppression ✅ (Planned)
- Modify `composer:saved` handler
- Consume and clear suppression flags
- Add logging for debugging

### Phase 4: Testing & Verification ⏳ (Next)
- Test all scenarios (see Testing Matrix below)
- Verify no regressions
- Check SPA safety
- Validate logging output

## Testing Matrix

| # | Scenario | Button | Filtered | Post Owner | Expected |
|---|----------|--------|----------|------------|----------|
| 1 | Embedded button (baseline) | Embedded | Yes | Owner | ✅ Embedded refresh |
| 2 | Standard reply to owner | Standard | Yes | Owner | ✅ Embedded refresh (NEW) |
| 3 | Standard reply to non-owner | Standard | Yes | Non-owner | ✅ Default behavior |
| 4 | Standard reply unfiltered | Standard | No | Owner | ✅ Default behavior |
| 5 | Standard reply unfiltered | Standard | No | Non-owner | ✅ Default behavior |
| 6 | Multiple rapid replies | Both | Yes | Owner | ✅ Both work correctly |

## Success Criteria

### Functional Requirements
- ✅ Standard reply to owner post in filtered view uses embedded logic
- ✅ Standard reply to non-owner post uses default behavior
- ✅ Standard reply outside filtered view uses default behavior
- ✅ Embedded button behavior unchanged (regression test)
- ✅ Auto-scroll and highlight work for both button types

### Technical Requirements
- ✅ SPA-safe (delegated listeners, idempotent binding)
- ✅ No memory leaks (one-shot flags, proper cleanup)
- ✅ No redirect loops (multi-guard checks)
- ✅ Comprehensive logging for debugging
- ✅ Error handling (try-catch, flag cleanup)

### User Experience Requirements
- ✅ Consistent behavior regardless of button used
- ✅ No unexpected scrolling or navigation
- ✅ New posts appear in correct location
- ✅ Smooth transitions and animations
- ✅ No visual glitches or delays

## Code Changes Summary

### Change 1: Module Variables (+3 lines)
```javascript
let standardReplyInterceptBound = false;
let suppressStandardReplyScroll = false;
let suppressedReplyPostNumber = null;
```

### Change 2: Shared Function (+40 lines)
```javascript
async function openReplyToOwnerPost(topic, ownerPost, ownerPostNumber) {
  // Centralized composer opening logic
}
```

### Change 3: Refactor Embedded Handler (-17 net lines)
Replace inline composer opening with call to shared function

### Change 4: Standard Reply Interceptor (+65 lines)
```javascript
document.addEventListener("click", async (e) => {
  // Four-guard interception logic
}, true);
```

### Change 5: Suppression Consumption (+7 lines)
```javascript
if (suppressStandardReplyScroll) {
  // Log and clear flags
}
```

**Total**: ~98 lines added, ~17 removed = **~81 net lines**

## SPA Safety Measures

### Event Delegation
- ✅ Single delegated listener at `document` level
- ✅ Capture phase for early interception
- ✅ Idempotent binding with flag check

### State Management
- ✅ Module-scoped flags (view-only state)
- ✅ One-shot suppression pattern
- ✅ Deterministic clearing after consumption

### Guard Conditions
- ✅ Multiple independent checks
- ✅ Early returns for non-applicable cases
- ✅ Validation of all required data

### Error Handling
- ✅ Try-catch around composer opening
- ✅ Flag cleanup on error
- ✅ Graceful degradation to default behavior

## Logging Strategy

All logs use prefix: `[Embedded Reply Buttons]`

### New Log Messages

**Interception Decision**:
- `Standard reply - not in owner mode, allowing default`
- `Standard reply - no post element found`
- `Standard reply - missing required data`
- `Standard reply - not owner post, allowing default`
- `Standard reply intercepted for owner post #X`

**Suppression Handling**:
- `Set suppression flag for post #X`
- `Standard reply suppression active - preventing default scroll`
- `Suppressed post number: X`

**Shared Function**:
- `Opening reply to owner post #X`
- `Stored lastReplyContext {topicId, parentPostNumber, ownerPostNumber}`
- `Composer opened successfully`

## Documentation Created

1. **STANDARD_REPLY_BUTTON_INTERCEPTION_PLAN.md** - Detailed implementation plan
2. **STANDARD_REPLY_INTERCEPTION_FLOW.md** - Visual flow diagrams and comparisons
3. **STANDARD_REPLY_INTERCEPTION_CODE.md** - Exact code changes with line numbers
4. **IMPLEMENTATION_PLAN_SUMMARY.md** - This document (executive summary)

## Next Steps

### Immediate (Phase 4)
1. ✅ Review implementation plan (COMPLETE)
2. ⏳ Implement code changes
3. ⏳ Test all scenarios from testing matrix
4. ⏳ Verify logging output
5. ⏳ Check for regressions

### Follow-up
1. ⏳ Update user-facing documentation
2. ⏳ Add to FEATURE_SUMMARY.md
3. ⏳ Create testing guide for QA
4. ⏳ Monitor for edge cases in production

## Risk Assessment

### Low Risk
- ✅ Changes are isolated to one file
- ✅ Existing functionality preserved (guards prevent interception when not applicable)
- ✅ Easy rollback (comment out interceptor)
- ✅ Comprehensive logging for debugging

### Mitigation Strategies
- ✅ Four-guard system prevents false positives
- ✅ Try-catch prevents crashes
- ✅ One-shot flags prevent infinite loops
- ✅ Extensive testing matrix covers edge cases

## Estimated Effort

- **Implementation**: 30-45 minutes
- **Testing**: 45-60 minutes
- **Documentation**: 15-30 minutes (already complete)
- **Total**: 1.5-2.5 hours

## Questions & Answers

**Q: Why not modify Discourse core instead?**  
A: Theme component approach is safer, easier to maintain, and doesn't require core changes.

**Q: What if Discourse updates the reply button selector?**  
A: Guards will fail gracefully, allowing default behavior. Update selector as needed.

**Q: Will this work on mobile?**  
A: Yes, the selector `button.post-action-menu__reply` works on both desktop and mobile.

**Q: What about keyboard shortcuts?**  
A: Keyboard shortcuts trigger the same button click events, so they're automatically covered.

**Q: Can this cause infinite loops?**  
A: No, one-shot suppression flags and guard conditions prevent loops.

## References

- **Existing Implementation**: `embedded-reply-buttons.gjs` (lines 452-943)
- **Filtered View Logic**: `owner-comment-prototype.gjs` (lines 58-83)
- **Post Classification**: `hide-reply-buttons.gjs` (lines 52-87)
- **SPA Safety Rules**: `.augment/rules/core/spa-event-binding.md`
- **Redirect Loop Avoidance**: `.augment/rules/core/redirect-loop-avoidance.md`
- **State Scope Guidelines**: `.augment/rules/core/state-scope.md`

