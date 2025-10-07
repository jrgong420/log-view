# Hide Reply Buttons for Non-Owners - Implementation Summary

## Status: ✅ Planning Complete - Ready for Implementation

Branch: `feat/hide-reply-buttons-non-owners`

## Quick Overview

This feature adds a new setting to hide reply buttons from non-owner users in categories configured for owner comments. It's a UI-only restriction that complements the existing owner-filtered view functionality.

## Key Decisions

### ✅ What We Will Do

1. **Add boolean setting** `hide_reply_buttons_for_non_owners` (default: false)
2. **Hide reply buttons via CSS** using body class `hide-reply-buttons-non-owners`
3. **Use `api.onPageChange()`** for SPA-friendly re-evaluation
4. **Compare user IDs**: `currentUser.id === topic.details.created_by.id`
5. **Scope to configured categories**: Only applies in `owner_comment_categories`
6. **Add comprehensive logging** for debugging
7. **Document limitations** clearly (UI-only, keyboard shortcuts still work)

### ❌ What We Will NOT Do

1. **Suppress keyboard shortcuts** (Shift+R):
   - Not feasible with theme components
   - Would conflict with Discourse core functionality
   - Violates theme component best practices
   
2. **Server-side enforcement**:
   - Requires Discourse plugin, not theme component
   - Out of scope for this feature
   
3. **Prevent API-based replies**:
   - UI-only restriction by design
   - Use Discourse category permissions for true access control

## Implementation Checklist

### Phase 1: Core Implementation

- [ ] **Step 1**: Add `hide_reply_buttons_for_non_owners` setting to `settings.yml`
- [ ] **Step 2**: Add localization strings to `locales/en.yml`
- [ ] **Step 3**: Create `javascripts/discourse/api-initializers/hide-reply-buttons.gjs`
  - [ ] Implement `api.onPageChange()` handler
  - [ ] Add setting check guard
  - [ ] Add category check guard
  - [ ] Add user ID comparison logic
  - [ ] Add/remove body class based on ownership
  - [ ] Add debug logging
- [ ] **Step 4**: Add CSS hiding rules to `common/common.scss`
  - [ ] Target timeline footer reply button
  - [ ] Target topic footer reply button
  - [ ] Target post-level reply buttons
- [ ] **Step 5**: Add `parseCategoryIds()` helper to `group-access-utils.js`

### Phase 2: Documentation

- [ ] **Step 6**: Update `README.md`
  - [ ] Add "Hide Reply Buttons for Non-Owners" section
  - [ ] Document limitations clearly
  - [ ] Add configuration instructions
- [ ] **Step 7**: Create `docs/REPLY_BUTTON_HIDING.md`
  - [ ] Explain feature scope
  - [ ] Document independence from access control
  - [ ] List technical implementation details
  - [ ] Clarify limitations

### Phase 3: Testing

- [ ] **Step 8**: Manual testing
  - [ ] Test setting toggle
  - [ ] Test as topic owner (buttons visible)
  - [ ] Test as non-owner (buttons hidden)
  - [ ] Test category filtering
  - [ ] Test both view modes (regular and owner-filtered)
  - [ ] Test SPA navigation
  - [ ] Test edge cases (anonymous, no owner data)
  - [ ] Test mobile and desktop views
- [ ] **Step 9**: Lint checks
  - [ ] Run ESLint
  - [ ] Run Ember Template Lint
  - [ ] Run Stylelint

### Phase 4: Finalization

- [ ] **Step 10**: Commit changes with descriptive message
- [ ] **Step 11**: Push to origin
- [ ] **Step 12**: Create PR with detailed description
- [ ] **Step 13**: Address review feedback
- [ ] **Step 14**: Merge to main after approval

## Validation Against Augment Rules

### ✅ Configuration Rules
- **Settings** (`.augment/rules/configuration/settings.md`):
  - Uses `bool` type with default value ✅
  - Clear, descriptive setting name ✅
  - Includes validation constraints ✅
  
- **Localization** (`.augment/rules/configuration/localization.md`):
  - Uses `theme_metadata.settings` namespace ✅
  - Provides clear description ✅
  - Documents limitations ✅

### ✅ Core Rules
- **SPA Event Binding** (`.augment/rules/core/spa-event-binding.md`):
  - Uses `api.onPageChange()` for navigation ✅
  - Uses `schedule("afterRender")` for DOM stability ✅
  - Avoids direct DOM binding on transient elements ✅
  
- **Redirect Loop Avoidance** (`.augment/rules/core/redirect-loop-avoidance.md`):
  - Uses multiple guard conditions ✅
  - Checks current state before acting ✅
  - No navigation triggers (only CSS class manipulation) ✅
  
- **State Scope** (`.augment/rules/core/state-scope.md`):
  - Uses body class for UI state (appropriate scope) ✅
  - No persistent state needed ✅
  - Re-evaluates on page change ✅

### ✅ JavaScript Rules
- **API Initializers** (`.augment/rules/javascript/api-initializers.md`):
  - Uses `apiInitializer("1.15.0", ...)` ✅
  - Specifies minimum API version ✅
  - Uses `api.onPageChange()` correctly ✅
  
- **Glimmer Components** (`.augment/rules/javascript/glimmer-components.md`):
  - No jQuery usage ✅
  - Uses native DOM APIs ✅
  - Follows modern patterns ✅

### ✅ Styling Rules
- **SCSS Guidelines** (`.augment/rules/styling/scss-guidelines.md`):
  - Uses body class for scoping ✅
  - Specific selectors to avoid conflicts ✅
  - Uses `!important` appropriately for overrides ✅

## File Changes Summary

### New Files
1. `javascripts/discourse/api-initializers/hide-reply-buttons.gjs` - Main logic
2. `docs/REPLY_BUTTON_HIDING.md` - Feature documentation
3. `docs/HIDE_REPLY_BUTTONS_IMPLEMENTATION_PLAN.md` - This plan

### Modified Files
1. `settings.yml` - Add new setting
2. `locales/en.yml` - Add translation strings
3. `common/common.scss` - Add CSS hiding rules
4. `javascripts/discourse/lib/group-access-utils.js` - Add helper function
5. `README.md` - Add feature documentation

## Expected Behavior

### When Setting is Enabled

**In configured categories**:
- Topic owner sees all reply buttons (normal behavior)
- Non-owners see no reply buttons (hidden via CSS)
- Anonymous users see no reply buttons (hidden via CSS)

**In non-configured categories**:
- All users see reply buttons (normal behavior)

### When Setting is Disabled

**All categories**:
- All users see reply buttons (normal behavior)

## Known Limitations (By Design)

1. **UI-only restriction**: Does not prevent replies via:
   - Keyboard shortcuts (Shift+R)
   - API calls
   - Browser console manipulation
   
2. **Not a security feature**: Use Discourse category permissions for true access control

3. **Requires category configuration**: Only works in categories defined in `owner_comment_categories`

## Next Steps

1. Review this implementation plan
2. Confirm approach aligns with requirements
3. Proceed with implementation (Phase 1)
4. Test thoroughly (Phase 3)
5. Document and finalize (Phases 2 & 4)

## Questions for Review

1. Are the CSS selectors correct for targeting reply buttons?
2. Should we hide reply buttons on individual posts, or only the main topic reply buttons?
3. Is the limitation documentation clear enough?
4. Should we add a visual indicator when buttons are hidden (e.g., tooltip or notice)?

---

**Ready to proceed with implementation?** All planning is complete and validated against Augment rules.

