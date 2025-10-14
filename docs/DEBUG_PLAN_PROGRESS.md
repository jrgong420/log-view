# Debug Plan Progress Report

**Date**: 2025-10-14  
**Status**: Phase 3 Complete ✅

---

## Completed Phases

### ✅ Phase 1: Inventory and Triage

**Deliverables**:
- ✅ `docs/DEBUG_INVENTORY.md` - Comprehensive catalog of all project files
- ✅ Entry points documented (6 api-initializers, 1 component, 1 utility)
- ✅ Expected behaviors defined for each feature
- ✅ 6 reproduction scenarios documented (A-F)
- ✅ 5 risk areas identified with mitigation strategies

**Key Findings**:
- `embedded-reply-buttons.gjs` is the most complex file (1442 lines)
- Multiple module-level state variables across initializers
- Existing logging is inconsistent (hardcoded DEBUG flags)
- `lib/group-access-utils.js` has DEBUG=true always on ⚠️

---

### ✅ Phase 2: Design Logging Strategy

**Deliverables**:
- ✅ `docs/LOGGING_STRATEGY.md` - Complete logging architecture
- ✅ Settings-based toggle design (debug_logging_enabled)
- ✅ Logger utility API specification
- ✅ Logging levels and usage guidelines
- ✅ Prefix conventions established
- ✅ Structured logging patterns defined
- ✅ Diagnostic helpers designed (loop detection, duplicate listeners)
- ✅ Rate-limiting strategy
- ✅ Migration plan from current to new approach

**Key Decisions**:
- Single boolean setting controls all logging
- Errors always logged (even when debug disabled)
- Centralized logger utility for consistency
- Rate-limiting for high-frequency events (2000ms default)
- Performance timing for slow operations

---

### ✅ Phase 3: Implement Core Logging Infrastructure

**Deliverables**:
- ✅ `settings.yml` - Added `debug_logging_enabled` setting (default: false)
- ✅ `locales/en.yml` - Added localization for new setting
- ✅ `javascripts/discourse/lib/logger.js` - Complete logger utility (220 lines)
- ✅ `docs/LOGGER_USAGE_EXAMPLES.md` - Comprehensive usage examples

**Implementation Details**:

#### New Setting
```yaml
debug_logging_enabled:
  type: bool
  default: false
  description: "Enable detailed console logging for debugging..."
```

#### Logger API
```javascript
import { createLogger } from "../lib/logger";

const log = createLogger("[Owner View] [Feature Name]");

log.debug("message", { context });    // Only when enabled
log.info("message", { context });     // Only when enabled
log.warn("message", { context });     // Only when enabled
log.error("message", error);          // ALWAYS logged

log.group("label");                   // Start group
log.groupCollapsed("label");          // Start collapsed group
log.groupEnd();                       // End group

log.time("label");                    // Start timer
log.timeLog("label", "checkpoint");   // Log intermediate time
log.timeEnd("label");                 // End timer

log.table(data);                      // Display as table

log.debugThrottled("message", { throttleMs: 2000 }, { context });
```

#### Features
- ✅ Settings-based gating (checks `settings.debug_logging_enabled`)
- ✅ Automatic prefix injection
- ✅ Rate-limiting with configurable throttle duration
- ✅ Performance timing helpers
- ✅ Grouped logging for multi-step flows
- ✅ Structured context objects
- ✅ Errors always visible (even when debug disabled)
- ✅ Zero overhead when disabled (single boolean check)

---

## Next Phases (Pending)

### 🔄 Phase 4: Instrument Router and Page Lifecycle

**Tasks**:
- [ ] Update `owner-comment-prototype.gjs` to use new logger
- [ ] Add comprehensive logging to `api.onPageChange` handlers
- [ ] Log router service events (routeWillChange/routeDidChange)
- [ ] Add timing measurements for page transitions
- [ ] Document navigation flow with logs

**Estimated Effort**: 30-45 minutes

---

### 🔄 Phase 5: Instrument Event Handlers and User Actions

**Tasks**:
- [ ] Update `embedded-reply-buttons.gjs` click handlers
- [ ] Log event delegation flow (target, guards, actions)
- [ ] Track one-shot suppression flags with state transitions
- [ ] Add structured context for composer events
- [ ] Document reply flow with logs

**Estimated Effort**: 45-60 minutes

---

### 🔄 Phase 6: Instrument URL/Navigation Guards

**Tasks**:
- [ ] Add logging before any URL parameter changes
- [ ] Implement redirect loop detection with attempt counters
- [ ] Log all guard conditions (already-applied, data-ready, applicability)
- [ ] Add emergency brake logging
- [ ] Document guard evaluation flow

**Estimated Effort**: 30-45 minutes

---

### 🔄 Phase 7: Instrument Refresh and Network Operations

**Tasks**:
- [ ] Add before/after logging for post stream refresh
- [ ] Track timing with performance.mark/measure
- [ ] Log input parameters (topicId, postId, context)
- [ ] Log outcomes (success/failure, post count, elapsed time)
- [ ] Document auto-refresh flow

**Estimated Effort**: 30-45 minutes

---

### 🔄 Phase 8: Add Diagnostic Safety Checks

**Tasks**:
- [ ] Implement duplicate listener detection
- [ ] Add redirect loop emergency brakes
- [ ] Add memory/performance monitoring
- [ ] Add UI state verification logging
- [ ] Document diagnostic patterns

**Estimated Effort**: 30-45 minutes

---

### 🔄 Phase 9: Manual Testing and Verification

**Tasks**:
- [ ] Execute Scenario A: Embedded Reply (Expanded Section)
- [ ] Execute Scenario B: Embedded Reply (Collapsed Section)
- [ ] Execute Scenario C: Navigation Between Topics
- [ ] Execute Scenario D: Toggle Button
- [ ] Execute Scenario E: Mobile View
- [ ] Execute Scenario F: Group Access Control
- [ ] Verify logs appear correctly
- [ ] Confirm no regressions
- [ ] Check performance impact

**Estimated Effort**: 60-90 minutes

---

### 🔄 Phase 10: Documentation and Cleanup

**Tasks**:
- [ ] Update `about.json` version (0.1.0 → 0.2.0)
- [ ] Add usage notes for debug logging
- [ ] Verify all logs are gated behind debug flag
- [ ] Ensure no PII in logs
- [ ] Create testing checklist documentation
- [ ] Final code review

**Estimated Effort**: 30-45 minutes

---

## Files Created/Modified

### Created Files
1. `docs/DEBUG_INVENTORY.md` - Project inventory and triage
2. `docs/LOGGING_STRATEGY.md` - Logging architecture and patterns
3. `docs/LOGGER_USAGE_EXAMPLES.md` - Practical usage examples
4. `docs/DEBUG_PLAN_PROGRESS.md` - This progress report
5. `javascripts/discourse/lib/logger.js` - Logger utility module

### Modified Files
1. `settings.yml` - Added `debug_logging_enabled` setting
2. `locales/en.yml` - Added localization for new setting

---

## Summary Statistics

- **Total Phases**: 10
- **Completed**: 3 (30%)
- **Remaining**: 7 (70%)
- **Files Created**: 5
- **Files Modified**: 2
- **Lines of Code Added**: ~220 (logger.js)
- **Documentation Pages**: 4

---

## Recommendations for Next Session

1. **Start with Phase 4** (Router and Page Lifecycle)
   - Begin with `owner-comment-prototype.gjs` (simpler than embedded-reply-buttons)
   - Test logging toggle works correctly
   - Verify no performance regression

2. **Then Phase 5** (Event Handlers)
   - Tackle `embedded-reply-buttons.gjs` (most complex)
   - Use grouped logging extensively
   - Add performance timing for async operations

3. **Quick Wins**
   - Fix `lib/group-access-utils.js` DEBUG=true issue immediately
   - Update `hide-reply-buttons.gjs` (simple, good practice)
   - Update `group-access-control.gjs` (simple, good practice)

4. **Testing Strategy**
   - Enable debug logging in admin settings
   - Navigate to a topic in configured category
   - Verify logs appear in console
   - Disable debug logging
   - Verify logs disappear (except errors)

---

## Risk Mitigation

### Identified Risks
1. **Performance**: Logger adds overhead when enabled
   - ✅ Mitigated: Single boolean check when disabled
   - ✅ Mitigated: Rate-limiting for high-frequency events

2. **Console Noise**: Too many logs make debugging harder
   - ✅ Mitigated: Grouped/collapsed logging
   - ✅ Mitigated: Structured context objects
   - ✅ Mitigated: Rate-limiting

3. **Breaking Changes**: Refactoring might introduce bugs
   - ⚠️ Mitigation: Test each initializer individually
   - ⚠️ Mitigation: Keep old DEBUG constants during migration
   - ⚠️ Mitigation: Gradual rollout (one file at a time)

4. **Settings Not Available**: Global `settings` object might be undefined
   - ✅ Mitigated: Logger checks `typeof settings !== "undefined"`
   - ✅ Mitigated: Graceful fallback (no logging if settings unavailable)

---

## Next Steps

**Immediate**:
1. Review this progress report
2. Confirm approach for Phase 4-10
3. Decide: migrate all files at once, or one at a time?

**Recommended Approach**:
- Migrate one initializer at a time
- Test each migration individually
- Start with simplest files (group-access-control, hide-reply-buttons)
- End with most complex (embedded-reply-buttons)

---

**End of Progress Report**

