# Quick Reference - Hide Reply Buttons for Non-Owners

## 🎯 What It Does

Hides reply buttons in two ways:
1. **Post-level**: Hides buttons on posts by non-owners
2. **Top-level**: Hides timeline/topic footer buttons when viewer is not owner

## ⚙️ Configuration

**Admin → Customize → Themes → Log View → Settings**

| Setting | Value |
|---------|-------|
| `hide_reply_buttons_for_non_owners` | ✅ Enable |
| `owner_comment_categories` | Select categories |
| `debug_logging_enabled` | ✅ Enable (for testing) |

## 📊 Behavior Matrix

| Viewer | Top-Level Buttons | Owner's Posts | Non-Owner's Posts |
|--------|-------------------|---------------|-------------------|
| Owner | ✅ Visible | ✅ Visible | ✅ Visible |
| Non-Owner | ❌ Hidden | ✅ Visible | ❌ Hidden |
| Anonymous | ❌ Hidden | ✅ Visible | ❌ Hidden |

## 🔍 Quick Verification

### Browser Console Commands

```javascript
// Check body class (top-level hiding)
document.body.classList.contains('hide-reply-buttons-non-owners')
// Expected: true (non-owner), false (owner)

// Check post classification
document.querySelectorAll('article.topic-post.owner-post').length
document.querySelectorAll('article.topic-post.non-owner-post').length

// Check button visibility
const btn = document.querySelector('.timeline-footer-controls .create');
console.log('Timeline button:', btn ? window.getComputedStyle(btn).display : 'not found');
// Expected: "none" (non-owner), "inline-flex" or similar (owner)
```

### Visual Inspection

**As Non-Owner**:
- [ ] Timeline footer (right side) - NO "Reply" button
- [ ] Topic footer (bottom) - NO "Reply" button
- [ ] Owner's posts - HAS reply button
- [ ] Non-owner's posts - NO reply button

**As Owner**:
- [ ] Timeline footer - HAS "Reply" button
- [ ] Topic footer - HAS "Reply" button
- [ ] All posts - HAS reply button

## 🐛 Troubleshooting

### Buttons Not Hiding

**Check**:
1. Setting enabled? `hide_reply_buttons_for_non_owners = true`
2. Category configured? Check `owner_comment_categories`
3. Are you the owner? (Buttons should be visible for owner)
4. Body class present? `document.body.classList.contains('hide-reply-buttons-non-owners')`

**Debug**:
```javascript
const topic = Discourse.__container__.lookup("controller:topic")?.model;
const user = Discourse.__container__.lookup("service:current-user");
console.log("Owner ID:", topic?.details?.created_by?.id);
console.log("User ID:", user?.id);
console.log("Match:", user?.id === topic?.details?.created_by?.id);
```

### Buttons Hiding for Owner

**Check**:
```javascript
const topic = Discourse.__container__.lookup("controller:topic")?.model;
const user = Discourse.__container__.lookup("service:current-user");
console.log("Are you the owner?", user?.id === topic?.details?.created_by?.id);
// Should be true if you're the owner
```

### Posts Not Classified

**Check**:
```javascript
// Should be > 0 if classification is working
document.querySelectorAll('article.topic-post[data-owner-marked]').length

// Check console for errors
// Look for: "[Owner View] [Hide Reply Buttons]" logs
```

## 📁 Files Modified

```
javascripts/discourse/api-initializers/hide-reply-buttons.gjs  ← Main logic
common/common.scss                                             ← CSS rules
settings.yml                                                   ← Setting definition
test/acceptance/hide-reply-buttons-non-owners-test.js         ← Tests
```

## 📚 Documentation

| Document | Purpose |
|----------|---------|
| `IMPLEMENTATION_SUMMARY.md` | Quick overview |
| `HIDE_REPLY_BUTTONS_IMPLEMENTATION.md` | Implementation details |
| `docs/HIDE_REPLY_BUTTONS_COMPLETE.md` | Complete documentation |
| `docs/HIDE_REPLY_BUTTONS_TESTING_MANUAL.md` | Testing guide |
| `docs/HIDE_REPLY_BUTTONS_FLOW.md` | Visual diagrams |

## 🚀 Quick Test

1. **Enable setting** in admin panel
2. **Configure category** in `owner_comment_categories`
3. **Create test topic** in configured category
4. **Test as owner**: All buttons visible
5. **Test as non-owner**: Top-level hidden, post-level selective
6. **Check console**: Look for `[Hide Reply Buttons]` logs

## ⚠️ Limitations

- ❌ Cannot prevent keyboard shortcuts (Shift+R)
- ❌ Cannot prevent API calls
- ❌ Not a security feature
- ❌ Does not check Allowed groups

## 🔄 Rollback

**Quick**: Disable `hide_reply_buttons_for_non_owners` setting

**Full**: `git revert <commit-hash>`

## 💡 Tips

1. **Enable debug logging** during testing
2. **Use browser console** to verify behavior
3. **Test in multiple scenarios** (owner, non-owner, anonymous)
4. **Check both desktop and mobile** views
5. **Verify in configured and unconfigured categories**

## 🆘 Support

1. Check troubleshooting section above
2. Review `docs/HIDE_REPLY_BUTTONS_COMPLETE.md`
3. Enable debug logging and check console
4. Collect logs and screenshots for bug reports

## ✅ Success Checklist

- [ ] Setting enabled
- [ ] Category configured
- [ ] As owner: All buttons visible
- [ ] As non-owner: Top-level hidden
- [ ] As non-owner: Post-level selective
- [ ] No console errors
- [ ] Body class toggling correctly
- [ ] Posts classified correctly

---

**Implementation Date**: 2025-10-14  
**Status**: ✅ Code Complete  
**Next**: Deploy and test

