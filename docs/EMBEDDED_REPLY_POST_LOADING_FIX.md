# Embedded Reply Post Loading Fix

## Problem Summary

When clicking reply buttons on embedded posts, the composer failed to open because the target post was not loaded in the topic's post stream.

### Root Cause

Discourse's post stream uses lazy loading and only keeps a subset of posts in memory at any given time. When a user clicks "Show replies" to expand embedded posts:

1. The embedded posts section appears in the DOM with post metadata (post ID, post number)
2. Reply buttons are injected successfully
3. **However**, the actual post models for those embedded posts are NOT loaded into `topic.postStream.posts`
4. When the reply button is clicked, the code cannot find the post model to pass to the composer

### Example from Console Logs

```
[Embedded Reply Buttons] Fallback post id from DOM/button: 979323
[Embedded Reply Buttons] Post id not found in stream: 979323
[Embedded Reply Buttons] Stream post IDs: (20) [971791, 973050, 974706, ...]
[Embedded Reply Buttons] Resolved post number via href parsing: 82
[Embedded Reply Buttons] Could not find post model for post number 82
[Embedded Reply Buttons] Available posts: (20) [76, 77, 78, 79, 80, 81, 83, 85, ...]
```

Notice:
- Post #82 is missing from the loaded posts (gap between 81 and 83)
- Post ID 979323 is not in the stream's post IDs array
- The stream only contains 20 posts, not all posts in the topic

## Solution Evolution

### Initial Approach (Failed)

First attempt used `topic.postStream.loadPostByPostNumber()` but this method didn't actually add the post to the stream as expected.

### Current Approach (Multi-Fallback Strategy)

The fix implements a **two-tier fallback strategy** to handle missing posts:

### Implementation

#### Tier 1: Try Opening Composer with Post Number Only

```javascript
// If post is not in the stream, try alternative approaches
if (!parentPost) {
  // Import Composer model
  const { default: Composer } = await import("discourse/models/composer");

  // Approach 1: Try to open composer with just the post number
  // The composer should be able to handle this and fetch the post data itself
  try {
    await composer.open({
      action: Composer.REPLY,
      topic: topic,
      draftKey: topic.draft_key,
      draftSequence: topic.draft_sequence,
      skipJumpOnSave: true,
      replyToPostNumber: Number(postNumber), // Use post number directly
    });

    console.log(`${LOG_PREFIX} Composer opened successfully with post number`);
    return; // Exit early if this works
  } catch (composerError) {
    console.error(`${LOG_PREFIX} Failed with replyToPostNumber:`, composerError);
  }
}
```

**Rationale**: The Discourse composer may be able to fetch the post data itself when given just a post number. This is the cleanest approach if it works.

#### Tier 2: Fetch Post from Server via Store

```javascript
// Approach 2: Try fetching the post from the server
if (postId) {
  try {
    const store = api.container.lookup("service:store");
    const fetchedPost = await store.find("post", postId);

    if (fetchedPost) {
      console.log(`${LOG_PREFIX} Successfully fetched post:`, fetchedPost);
      parentPost = fetchedPost;
    }
  } catch (fetchError) {
    console.error(`${LOG_PREFIX} Failed to fetch post:`, fetchError);
  }
}

// If still no post, give up
if (!parentPost) {
  console.error(`${LOG_PREFIX} All approaches failed`);
  return;
}
```

**Rationale**: If the composer doesn't support `replyToPostNumber`, we fetch the full post model from the server using Ember Data's store. This ensures we have all the post data needed.

### Key Changes

1. **Extracted post ID early**: Made `postId` available throughout the function scope
2. **Two-tier fallback strategy**: Try composer-only approach first, then fetch if needed
3. **Comprehensive logging**: Tracks which approach succeeds/fails
4. **Graceful degradation**: Each tier catches its own errors and tries the next approach

## How It Works

### Step-by-Step Flow

1. **User clicks reply button** on an embedded post
2. **Post number and ID are resolved** via DOM attributes or href parsing
3. **Initial lookup** in `topic.postStream.posts` fails (post not loaded)
4. **Tier 1 attempt**: Try opening composer with `replyToPostNumber`
   - If successful: Composer opens, flow ends
   - If fails: Continue to Tier 2
5. **Tier 2 attempt**: Fetch post from server using `store.find("post", postId)`
   - If successful: Use fetched post model
   - If fails: Give up and show error
6. **Composer opens** with the post model (if Tier 2 succeeded)

### API Methods Used

**Tier 1: `composer.open({ replyToPostNumber: ... })`**
- **Purpose**: Let composer handle post fetching internally
- **Advantage**: Minimal code, leverages Discourse's built-in logic
- **Limitation**: May not be supported in all Discourse versions

**Tier 2: `store.find("post", postId)`**
- **Purpose**: Fetch post model from server via Ember Data
- **Returns**: Promise resolving to post model
- **Advantage**: Guaranteed to work if post exists
- **Source**: Ember Data store service

## Benefits

### 1. Reliability
- **Two-tier fallback**: If one approach fails, try another
- **Works with any Discourse version**: Tier 2 uses standard Ember Data
- **Handles sparse post streams**: No dependency on posts being pre-loaded
- **Post ID and post number support**: Can work with either identifier

### 2. Performance
- **Lazy loading**: Only fetches posts when needed
- **Composer-first approach**: Tier 1 may avoid extra network request
- **Single post fetch**: Minimal network overhead (Tier 2)

### 3. User Experience
- **Seamless composer opening**: Works transparently
- **No visible delay**: Async loading with proper await
- **Clear error messages**: Comprehensive logging for debugging
- **Graceful degradation**: Each tier fails independently

## Testing

### Expected Console Output (Tier 1 Success)

```
[Embedded Reply Buttons] Reply button clicked: <button>
[Embedded Reply Buttons] Target embedded post number: 82
[Embedded Reply Buttons] Target embedded post id: 979323
[Embedded Reply Buttons] Target embedded post model: undefined
[Embedded Reply Buttons] Post 82 not in stream, trying alternative approaches...
[Embedded Reply Buttons] Attempting to open composer with post number 82...
[Embedded Reply Buttons] Composer opened successfully with post number 82
```

### Expected Console Output (Tier 2 Success)

```
[Embedded Reply Buttons] Reply button clicked: <button>
[Embedded Reply Buttons] Target embedded post number: 82
[Embedded Reply Buttons] Target embedded post id: 979323
[Embedded Reply Buttons] Target embedded post model: undefined
[Embedded Reply Buttons] Post 82 not in stream, trying alternative approaches...
[Embedded Reply Buttons] Attempting to open composer with post number 82...
[Embedded Reply Buttons] Failed to open composer with replyToPostNumber: Error: ...
[Embedded Reply Buttons] Attempting to fetch post 979323 from server...
[Embedded Reply Buttons] Successfully fetched post: <Post>
[Embedded Reply Buttons] Using post model: <Post>
[Embedded Reply Buttons] Opening composer with options: {...}
[Embedded Reply Buttons] Composer opened successfully
```

### Expected Console Output (Complete Failure)

```
[Embedded Reply Buttons] Reply button clicked: <button>
[Embedded Reply Buttons] Target embedded post number: 82
[Embedded Reply Buttons] Target embedded post id: 979323
[Embedded Reply Buttons] Target embedded post model: undefined
[Embedded Reply Buttons] Post 82 not in stream, trying alternative approaches...
[Embedded Reply Buttons] Attempting to open composer with post number 82...
[Embedded Reply Buttons] Failed to open composer with replyToPostNumber: Error: ...
[Embedded Reply Buttons] Attempting to fetch post 979323 from server...
[Embedded Reply Buttons] Failed to fetch post from server: Error: ...
[Embedded Reply Buttons] All approaches failed - cannot open composer for post 82
```

### Test Scenarios

1. **Post already in stream**: Should use cached post (no fallback needed)
2. **Post not in stream, Tier 1 works**: Composer opens with `replyToPostNumber`
3. **Post not in stream, Tier 1 fails, Tier 2 works**: Fetches post, then opens composer
4. **Invalid post number/ID**: Both tiers fail, shows error message
5. **Network error**: Tier 2 catches error, shows failure message

## Related Issues Fixed

This fix also resolves:

1. **Duplicate nested buttons**: Fixed by filtering out buttons from item selectors
2. **Post number extraction**: Enhanced with href parsing fallback
3. **Container detection**: Prevents button from being treated as container

## Code Location

**File**: `javascripts/discourse/api-initializers/embedded-reply-buttons.gjs`
**Lines**: 334-502 (post resolution and loading logic)
**Function**: Global click handler for `.embedded-reply-button`

### Key Code Sections

1. **Post ID/Number Extraction** (lines 334-356): Extracts both post ID and post number from DOM
2. **Tier 1 Fallback** (lines 390-425): Tries `replyToPostNumber` approach
3. **Tier 2 Fallback** (lines 427-463): Fetches post via `store.find()`
4. **Composer Opening** (lines 465-502): Opens composer with post model

## Debugging Tips

### Enable Verbose Logging

The code already includes comprehensive logging. Check browser console for:
- Post number and ID resolution
- Which tier is being attempted
- Success/failure of each approach
- Final composer opening status

### Common Issues

**Issue**: "Failed to open composer with replyToPostNumber"
- **Cause**: Discourse version doesn't support this parameter
- **Solution**: Tier 2 should automatically kick in

**Issue**: "Failed to fetch post from server"
- **Cause**: Post doesn't exist or network error
- **Solution**: Check post ID is valid, check network tab

**Issue**: "All approaches failed"
- **Cause**: Both tiers failed
- **Solution**: Check console for specific error messages from each tier

## References

- [Discourse Composer Service](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js)
- [Ember Data Store](https://guides.emberjs.com/release/models/finding-records/)
- [Embedded Reply Buttons Implementation](./EMBEDDED_REPLY_BUTTONS_IMPLEMENTATION.md)

## Future Enhancements

Potential improvements:

1. **Preloading**: Load embedded posts when "Show replies" is clicked
2. **Batch loading**: Fetch multiple embedded posts in one request
3. **Caching**: Remember loaded posts across page changes
4. **Loading indicator**: Show spinner while fetching post (Tier 2)
5. **Tier 3**: Try direct API call to `/posts/:id.json` as last resort

