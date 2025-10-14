# Hide Reply Buttons for Non-Owners - Expanded Implementation

## Overview

This feature hides reply buttons on posts authored by non-owners in categories configured for owner comments. It applies in both filtered and regular topic views, providing a consistent experience regardless of view mode.

## Behavior

### What Gets Hidden

- **Reply buttons on posts by non-owners**: When a post is authored by someone other than the topic owner, the reply-to button on that post is hidden via CSS.
- **Posts by topic owner**: Reply buttons remain visible on all posts authored by the topic owner.

### Scope

- **Categories**: Only applies in categories listed in the "Owner Comment Categories" setting
- **View modes**: Works in both:
  - Regular (unfiltered) topic view
  - Filtered (owner-only) view
- **Group filtering**: Does NOT check the "Allowed Groups" setting - applies to all users regardless of group membership

### What Does NOT Get Hidden

- Top-level reply buttons (timeline, topic footer) - these remain visible
- Embedded reply buttons in filtered view - these continue to work normally
- Reply functionality via keyboard shortcuts (Shift+R) or API calls

## Implementation Details

### JavaScript Logic

**File**: `javascripts/discourse/api-initializers/hide-reply-buttons.gjs`

The initializer:
1. Checks if the setting is enabled
2. Verifies the topic is in a configured category
3. Gets the topic owner ID
4. Classifies each visible post as `owner-post` or `non-owner-post`
5. Sets up a MutationObserver to classify newly rendered posts (e.g., from "load more" or "show replies")

**Post Classification**:
- Extracts post number from DOM element
- Looks up post model in `topic.postStream.posts`
- Compares `post.user_id` with `topic.details.created_by.id`
- Adds CSS class: `owner-post` or `non-owner-post`
- Marks post with `data-owner-marked="1"` to avoid reprocessing

### CSS Targeting

**File**: `common/common.scss`

```scss
/* Hide post-level reply buttons on posts authored by non-owners */
article.topic-post.non-owner-post {
  nav.post-controls .actions button.create,
  nav.post-controls .actions button.reply,
  nav.post-controls .actions button.reply-to-post {
    display: none !important;
  }
}
```

### SPA Compatibility

- Uses `api.onPageChange` with `schedule("afterRender")` for Ember routing
- MutationObserver watches for new posts added to the stream
- Observer is cleaned up on route changes to prevent memory leaks
- Posts are marked with `data-owner-marked` to ensure idempotent processing

## Configuration

### Settings

**hide_reply_buttons_for_non_owners** (Boolean, default: false)
- Enable/disable the feature

**owner_comment_categories** (List of categories)
- Categories where this feature applies
- Must be configured for the feature to work

**allowed_groups** (List of groups)
- NOT used by this feature
- Feature applies regardless of group membership

### Admin Setup

1. Go to **Admin** > **Customize** > **Themes**
2. Select the **Log View** theme component
3. Click **Settings**
4. Enable **Hide Reply Buttons for Non-Owners**
5. Configure **Owner Comment Categories** (required)
6. Save changes

## Testing

### Manual Testing Checklist

**In a configured category:**

1. **Regular view**:
   - [ ] Posts by topic owner show reply buttons
   - [ ] Posts by other users hide reply buttons
   - [ ] Scroll and load more posts - new posts are classified correctly

2. **Filtered view** (if toggle enabled):
   - [ ] Toggle to filtered view
   - [ ] Owner posts still show reply buttons
   - [ ] Non-owner posts (if visible) hide reply buttons
   - [ ] Embedded reply buttons continue to work

3. **Unconfigured category**:
   - [ ] Navigate to a topic in a different category
   - [ ] All reply buttons remain visible (no classification)

4. **Edge cases**:
   - [ ] Expand "show replies" - embedded posts are classified
   - [ ] Refresh page - classification persists
   - [ ] Navigate away and back - observer is reset correctly

### Browser DevTools Verification

**Check post classification:**
```javascript
// In browser console
document.querySelectorAll('article.topic-post.owner-post').length
document.querySelectorAll('article.topic-post.non-owner-post').length
```

**Check for observer leaks:**
```javascript
// Navigate between topics and check console for:
// "[Hide Reply Buttons] MutationObserver set up for post stream"
// Should only appear once per page load
```

### Automated Tests

**File**: `test/acceptance/hide-reply-buttons-non-owners-test.js`

Run tests:
```bash
# Run all theme tests
npm test

# Run specific test file
npm test -- --filter="Hide Reply Buttons"
```

## Troubleshooting

### Reply buttons not hiding

**Check**:
1. Is the setting enabled?
2. Is the topic in a configured category?
3. Are posts being classified? (Check for `owner-post` or `non-owner-post` classes in DevTools)
4. Check browser console for debug logs: `[Hide Reply Buttons]`

### Posts not being classified

**Possible causes**:
- Topic owner ID not available (`topic.details.created_by.id`)
- Post not in `topic.postStream.posts` (may need to scroll/load more)
- JavaScript error preventing classification (check console)

### Observer not working for new posts

**Check**:
- Console logs for "MutationObserver set up for post stream"
- Verify post stream container exists: `document.querySelector('.post-stream')`
- Check for JavaScript errors that might prevent observer setup

## Performance Considerations

- **Initial classification**: Processes all visible posts on page load (typically 20-50 posts)
- **Observer overhead**: Minimal - only processes newly added posts
- **Memory**: Observer is cleaned up on route changes to prevent leaks
- **Idempotency**: Posts marked with `data-owner-marked` are skipped on subsequent passes

## Compatibility

- **Discourse version**: Requires API version 1.15.0+
- **Browser support**: Modern browsers with MutationObserver support
- **Mobile**: Works on both desktop and mobile views
- **Other features**: Does not interfere with:
  - Embedded reply buttons
  - Toggle view button
  - Group access control
  - Auto-scroll functionality

## Future Enhancements

Potential improvements:
- Option to also hide top-level reply buttons
- Configurable CSS styling for owner vs non-owner posts
- Per-category override settings
- Integration with Discourse's permission system for server-side enforcement

## References

- [SPA Event Binding](.augment/rules/core/spa-event-binding.md)
- [Redirect Loop Avoidance](.augment/rules/core/redirect-loop-avoidance.md)
- [Theme Settings Configuration](.augment/rules/configuration/settings.md)

