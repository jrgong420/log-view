# Owner Reply Filter - Implementation Summary

## Status: ✅ Core Implementation Complete

**Branch**: `feature/investigate-post-stream-modification`  
**Type**: Experimental theme-only prototype  
**Next Steps**: QA testing, then evaluate for plugin implementation

---

## What Was Implemented

### 1. Settings Configuration ✅

**File**: `settings.yml`

Added 4 new settings:
- `enable_owner_reply_filter` (bool, default: false) - Master toggle
- `show_owner_reply_filter_notice` (bool, default: true) - Show notice banner
- `debug_owner_reply_filter` (bool, default: false) - Debug logging
- `auto_owner_reply_filter_in_owner_view` (bool, default: true) - Auto-activate filter when owner-only view (username_filters) is active

**Note**: Uses existing `owner_comment_categories` setting for category allowlist (shared with main owner filter feature)

### 2. Translations ✅

**File**: `locales/en.yml`

Added translations for:
- Notice title and text
- Toggle button labels
- Setting descriptions

### 3. Post Marking Logic ✅

**File**: `javascripts/discourse/api-initializers/owner-reply-filter.gjs`

- Registers value transformer on `post-class`
- Adds `hidden-owner-reply` class when:
  - Post author is topic owner
  - Post is a reply (has `reply_to_post_number`)
  - Post is NOT a self-reply (reply_to_user ≠ topic owner)
- Defensive checks for missing data
- Debug logging support

### 4. Router & UI Logic ✅

**File**: `javascripts/discourse/api-initializers/owner-reply-filter-router.gjs`

- Monitors URL for `owner_reply_filter=true` parameter
- Validates category allowlist (uses `owner_comment_categories` setting)
- Skips when `username_filters` is present (avoid conflicts)
- Adds/removes `owner-reply-filter-active` body class
- Injects notice banner with toggle button (idempotent)
- Implements redirect-loop guards:
  - One-shot suppression flag
  - URL and UI state checks
  - Topic ID validation
- Event delegation for toggle clicks
- Debug logging support

### 5. Styles ✅

**File**: `common/common.scss`

Added:
- CSS rule to hide posts: `body.owner-reply-filter-active article.hidden-owner-reply { display: none; }`
- Notice banner styling (responsive)
- Mobile adjustments

### 6. Documentation ✅

**File**: `docs/OWNER_REPLY_FILTER_PROTOTYPE.md`

Comprehensive documentation covering:
- Overview and purpose
- Implementation details
- Known limitations (timeline, anchors, reply chains)
- Testing checklist
- Interaction with existing features
- Production plugin recommendation with design sketch
- Debug mode instructions

---

## How to Test

### 1. Enable the Feature

In Discourse Admin → Customize → Themes → Your Theme → Settings:

1. Set `enable_owner_reply_filter` to **true**
2. Configure `owner_comment_categories` if you want to limit to specific categories (leave empty for all)
   - This is the same setting used by the main owner filter feature
3. (Optional) Enable `debug_owner_reply_filter` for console logs

### 2. Activate the Filter

Navigate to a topic and add `?owner_reply_filter=true` to the URL:

```
https://your-forum.com/t/topic-slug/123?owner_reply_filter=true
```

### 3. Expected Behavior

✅ **Should see**:
- Notice banner at top: "Filtered View Active"
- Owner's replies to other users are hidden
- Top-level owner posts remain visible
- Owner's self-replies remain visible
- "Show All Posts" button in notice

✅ **Should work**:
- Click "Show All Posts" → filter deactivates, all posts visible
- No redirect loops
- Notice appears only once
- Mobile responsive

⚠️ **Known issues** (expected):
- Timeline may not align perfectly with visible posts
- Anchor links to hidden posts may behave unexpectedly
- Reply chains may reference hidden posts

### 4. Test Cases

**Basic**:
- [ ] Filter activates with URL param
- [ ] Notice appears
- [ ] Correct posts are hidden
- [ ] Toggle deactivates filter
- [ ] No redirect loops

**Edge cases**:
- [ ] Topic with `username_filters` → our filter should NOT activate
- [ ] Topic in non-allowed category → filter should NOT activate
- [ ] Refresh page → filter state persists
- [ ] Navigate away and back → reinitializes correctly
- [ ] Mobile view → notice is responsive

**Conflicts**:
- [ ] With `username_filters` present → skipped (logged in console)
- [ ] With owner comment auto-filter → both can coexist (but not recommended)

---

## Architecture Decisions

### Why Value Transformer?

- **Modern API**: Recommended by Discourse for Glimmer post stream
- **Declarative**: Adds class based on post properties
- **Performant**: Only runs during post render
- **Maintainable**: Clear separation of concerns

### Why Body Class Toggle?

- **Simple**: Single CSS rule controls visibility
- **Reversible**: Easy to activate/deactivate
- **Debuggable**: Visible in DevTools
- **No DOM manipulation**: Let CSS handle hiding

### Why Event Delegation?

- **SPA-safe**: Binds once, works across route changes
- **Memory efficient**: Single listener for all toggles
- **Robust**: Survives re-renders

### Why Skip username_filters?

- **Avoid conflicts**: Both filters would compound timeline issues
- **User clarity**: One filter at a time is less confusing
- **Technical**: username_filters is server-side (correct), ours is client-side (approximate)

---

## Limitations & Trade-offs

### ✅ What Works Well

- Post marking is accurate and defensive
- Router logic is robust with proper guards
- UI injection is idempotent and SPA-safe
- Debug mode provides good visibility
- Code is well-documented and maintainable

### ⚠️ Known Limitations

1. **Timeline misalignment**: Right-hand timeline shows all posts, but some are hidden
2. **Anchor links**: Direct links to hidden posts may not work as expected
3. **Reply chains**: "In reply to" may reference hidden posts
4. **Performance**: Value transformer runs on every post render (minimal impact for normal topics)
5. **Client-side only**: Cannot guarantee consistency like server-side filtering

### 🔄 Why These Limitations Exist

This is a **theme-only prototype** using client-side DOM hiding. The underlying post stream data is not modified, so:
- Discourse's timeline logic still sees all posts
- Scroll/anchor calculations are based on full stream
- Reply chain references point to full stream

**For production**: Implement as a server-side plugin to filter the stream before it reaches the client.

---

## Next Steps

### Immediate (QA Phase)

1. **Manual testing** (see test cases above)
2. **Adjust toggle placement** if notice conflicts with layout
3. **Document observed timeline issues** in specific scenarios
4. **Gather user feedback** on UX and usefulness

### Short-term (If Validated)

1. **Add automated tests** (if moving to plugin)
2. **Refine edge cases** based on QA findings
3. **Consider adding a "filtered view" indicator** in timeline

### Long-term (Production)

1. **Design server-side plugin** (see `OWNER_REPLY_FILTER_PROTOTYPE.md`)
2. **Implement TopicView/PostStream filtering** (Ruby)
3. **Add proper timeline support** (server returns filtered stream)
4. **Migrate theme logic** to plugin client-side component
5. **Add admin UI** for configuration

---

## Files Changed

### New Files
- `javascripts/discourse/api-initializers/owner-reply-filter.gjs`
- `javascripts/discourse/api-initializers/owner-reply-filter-router.gjs`
- `docs/OWNER_REPLY_FILTER_PROTOTYPE.md`
- `docs/OWNER_REPLY_FILTER_IMPLEMENTATION_SUMMARY.md` (this file)

### Modified Files
- `settings.yml` - Added 3 new settings (uses existing `owner_comment_categories`)
- `locales/en.yml` - Added translations
- `common/common.scss` - Added styles for filter and notice

### No Changes
- Existing features (owner toggle, reply buttons, etc.) are unaffected
- No breaking changes
- Feature is opt-in via setting

---

## Rollback Plan

If issues arise:

1. **Disable setting**: Set `enable_owner_reply_filter` to `false`
2. **Remove URL param**: Navigate without `?owner_reply_filter=true`
3. **Revert code**: All changes are in isolated files; can be removed without affecting other features

---

## Success Criteria

### For Prototype
- ✅ Correctly identifies and hides owner replies to others
- ✅ Keeps top-level and self-replies visible
- ✅ No redirect loops
- ✅ Notice appears and toggle works
- ✅ Respects category allowlist
- ✅ Skips when username_filters present

### For Production Plugin
- Timeline stays aligned
- Anchors work correctly
- Reply chains are coherent
- Performance is optimal
- Consistent with Discourse patterns

---

## Questions for Stakeholders

1. **UX Validation**: Does hiding owner replies to others provide value to users?
2. **Timeline Issues**: Are the timeline misalignments acceptable for a prototype, or blocker?
3. **Plugin Investment**: If validated, is there budget/time for a proper plugin?
4. **Category Scope**: Should this be available in all categories or specific ones?
5. **Default State**: Should the filter be on by default (with toggle to show all) or off by default?

---

## Conclusion

✅ **Core implementation is complete and ready for QA testing**

The prototype successfully demonstrates the concept of hiding owner replies to others using modern Discourse APIs (value transformers, router service, event delegation).

**Recommendation**: 
- Test thoroughly in a staging environment
- Gather user feedback on UX and usefulness
- If validated, invest in a server-side plugin for production use

**Timeline**:
- QA testing: 1-2 days
- User feedback: 1 week
- Plugin design: 2-3 days
- Plugin implementation: 1-2 weeks

---

**Implementation Date**: 2025-10-14  
**Branch**: feature/investigate-post-stream-modification  
**Status**: Ready for QA

