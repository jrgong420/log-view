# Owner Reply Filter - Experimental Prototype

## Overview

This is a **theme-only, client-side prototype** that hides posts authored by the topic owner when those posts are replies to other users. It keeps top-level posts and self-replies visible.

**Status**: Experimental prototype for evaluation purposes only  
**Recommendation**: For production use, implement as a server-side plugin

## What It Does

When activated (via `?owner_reply_filter=true` URL parameter):

1. **Hides specific posts**: Posts authored by the topic owner that are replies to other users
2. **Keeps visible**:
   - Top-level posts by the topic owner (no `reply_to_post_number`)
   - Self-replies by the topic owner (replies to their own posts)
   - All posts by other users
3. **Shows a notice**: Banner at top of topic with "Show All Posts" toggle
4. **Respects settings**: Only works in configured categories when feature is enabled

## Implementation Details

### Files Created/Modified

1. **Settings** (`settings.yml`):
   - `enable_owner_reply_filter` - Feature toggle (default: false)
   - `owner_reply_filter_categories` - Category allowlist (empty = all)
   - `show_owner_reply_filter_notice` - Show/hide notice banner
   - `debug_owner_reply_filter` - Debug logging

2. **Translations** (`locales/en.yml`):
   - Notice title, text, and button labels
   - Setting descriptions

3. **JavaScript**:
   - `owner-reply-filter.gjs` - Value transformer to mark posts
   - `owner-reply-filter-router.gjs` - URL param handling and UI injection

4. **Styles** (`common/common.scss`):
   - CSS to hide marked posts when filter is active
   - Notice banner styling

### How It Works

1. **Marking posts** (value transformer):
   ```javascript
   api.registerValueTransformer("post-class", ...)
   ```
   - Adds `hidden-owner-reply` class when:
     - `post.user_id === post.topic.user_id` (topic owner)
     - `post.reply_to_post_number` exists (not top-level)
     - `post.reply_to_user.id !== post.topic.user_id` (reply to someone else)

2. **Hiding posts** (CSS):
   ```scss
   body.owner-reply-filter-active article.hidden-owner-reply {
     display: none;
   }
   ```
   - Only hides when body has `owner-reply-filter-active` class

3. **Router logic**:
   - Checks URL for `owner_reply_filter=true` parameter
   - Validates category allowlist
   - Skips if `username_filters` is present (avoid double-filtering)
   - Adds/removes body class
   - Injects notice banner with toggle button
   - Implements redirect-loop guards

## Known Limitations

### 1. Timeline Misalignment ⚠️

**Problem**: The right-hand timeline shows positions for ALL posts, but hidden posts reduce visible content height.

**Impact**:
- Timeline markers may not align with visible posts
- Clicking timeline positions may jump to unexpected locations
- Post count in timeline doesn't match visible posts

**Why**: The underlying post stream data is not modified; we only hide posts in the DOM.

**Mitigation**: For production, use a server-side plugin to filter the stream before it reaches the client.

### 2. Anchor/Jump Links ⚠️

**Problem**: Direct links to hidden posts (e.g., `#post_123`) may not work as expected.

**Impact**:
- Clicking "in reply to" links may jump to a hidden post
- Sharing links to specific posts may confuse users
- Browser back/forward may land on hidden content

**Why**: Discourse's scroll/anchor logic expects all posts in the stream to be visible.

### 3. Reply Chain Confusion ⚠️

**Problem**: Reply chains may reference hidden posts.

**Impact**:
- "In reply to" indicators may point to non-visible posts
- Conversation flow may seem disjointed
- Users may not understand why some replies are missing context

**Example**:
```
Post 1 (owner, top-level) ✓ visible
  ├─ Post 2 (user A) ✓ visible
  │   └─ Post 3 (owner reply to A) ✗ HIDDEN
  │       └─ Post 4 (user A reply to owner) ✓ visible (but context is hidden!)
  └─ Post 5 (owner reply to owner) ✓ visible (self-reply)
```

### 4. Interaction with username_filters

**Problem**: Discourse's built-in `username_filters` parameter is server-side and keeps timeline correct.

**Impact**:
- Our filter is skipped when `username_filters` is present
- Cannot combine both filters
- Users may be confused why toggle doesn't work

**Why**: Layering client-side filtering on top of server-side filtering would compound timeline issues.

### 5. Performance Considerations

**Problem**: Value transformer runs on every post render.

**Impact**:
- Minimal for normal topics (<100 posts)
- May cause lag on very large topics (>500 posts)
- Re-renders trigger re-evaluation

**Mitigation**: Transformer logic is lightweight; only adds a class.

## Testing Checklist

### Basic Functionality
- [ ] Enable setting, navigate to topic in allowed category
- [ ] Add `?owner_reply_filter=true` to URL
- [ ] Verify notice banner appears
- [ ] Verify owner's replies to others are hidden
- [ ] Verify top-level owner posts remain visible
- [ ] Verify owner's self-replies remain visible
- [ ] Click "Show All Posts" - verify filter deactivates
- [ ] Verify no redirect loops

### Edge Cases
- [ ] Topic with `username_filters` present - filter should not activate
- [ ] Topic in non-allowed category - filter should not activate
- [ ] Anonymous user - filter should work (if category allows)
- [ ] Mobile view - notice should be responsive
- [ ] Very large topic (>100 posts) - check performance
- [ ] Refresh page with filter active - should persist
- [ ] Navigate away and back - should reinitialize correctly

### Known Issues to Document
- [ ] Note timeline misalignment in specific scenarios
- [ ] Note anchor links to hidden posts behavior
- [ ] Note reply chain context issues

## Interaction with Existing Features

### username_filters (Core Discourse)
- **Behavior**: Our filter is **skipped** when `username_filters` is present
- **Reason**: Avoid double-filtering and compounding timeline issues
- **User impact**: Toggle button should be hidden/disabled when `username_filters` is active

### Owner Comment Categories (This Theme)
- **Behavior**: Independent features; both can be active
- **Interaction**: 
  - Owner comment auto-filter uses `username_filters` (server-side, correct timeline)
  - Owner reply filter uses client-side hiding (timeline may misalign)
- **Recommendation**: Don't enable both in the same category

### Hide Reply Buttons (This Theme)
- **Behavior**: Independent; no conflicts
- **Interaction**: Reply buttons may be hidden while filter is active
- **User impact**: Consistent UX (both restrict interaction)

## Production Implementation Recommendation

For production use, implement as a **server-side plugin**:

### Approach

1. **Add new query parameter**: `owner_reply_filter=true`

2. **Modify TopicView/PostStream** (server-side):
   ```ruby
   # In TopicView or PostStream serializer
   def filtered_post_ids
     if params[:owner_reply_filter] == "true"
       # Return only post IDs that should be visible:
       # - All posts by non-owners
       # - Top-level posts by owner (reply_to_post_number IS NULL)
       # - Self-replies by owner (reply_to_user_id = topic.user_id)
       # Exclude: owner replies to others
     end
   end
   ```

3. **Client-side integration**:
   - Add toggle button (similar to current prototype)
   - Use router to add/remove query param
   - Discourse core handles timeline/anchors correctly

4. **Benefits**:
   - ✅ Timeline stays aligned (server returns filtered stream)
   - ✅ Anchors work correctly
   - ✅ Reply chains are coherent
   - ✅ Performance is better (server-side filtering)
   - ✅ Consistent with `username_filters` pattern

### Plugin Structure (Sketch)

```
plugins/discourse-owner-reply-filter/
├── plugin.rb
├── config/
│   └── settings.yml
├── app/
│   ├── serializers/
│   │   └── topic_view_serializer_extension.rb
│   └── models/
│       └── topic_view_extension.rb
└── assets/
    └── javascripts/
        └── discourse/
            ├── initializers/
            │   └── owner-reply-filter.js
            └── components/
                └── owner-reply-filter-toggle.gjs
```

## Debug Mode

Enable `debug_owner_reply_filter` setting to see console logs:

```
[OwnerReplyFilter] Initializing owner reply filter transformer
[OwnerReplyFilter] Post 123: Marking as hidden-owner-reply (owner 1 replied to user 5)
[OwnerReplyFilterRouter] Initializing router logic
[OwnerReplyFilterRouter] Activating filter
[OwnerReplyFilterRouter] Notice injected
[OwnerReplyFilterRouter] Toggle handler bound (event delegation)
```

## Conclusion

This prototype demonstrates the **concept** of hiding owner replies to others, but has significant limitations due to being client-side only.

**For evaluation/testing**: This prototype is sufficient  
**For production**: Implement as a server-side plugin following the pattern of `username_filters`

The value of this prototype is to:
1. Validate the UX concept
2. Test user acceptance
3. Identify edge cases
4. Inform the plugin design

Once validated, invest in a proper plugin implementation for production use.

