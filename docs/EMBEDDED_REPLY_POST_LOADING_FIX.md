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

## Solution

### On-Demand Post Loading

The fix uses Discourse's `topic.postStream.loadPostByPostNumber()` method to load missing posts on-demand when the reply button is clicked.

### Implementation

```javascript
// Find the post model from the topic's post stream
let parentPost = topic.postStream?.posts?.find(
  (p) => p.post_number === Number(postNumber)
);

// If post is not in the stream, load it on-demand
if (!parentPost && topic.postStream) {
  console.log(`${LOG_PREFIX} Post ${postNumber} not in stream, loading on-demand...`);
  
  try {
    // Load the specific post into the stream
    await topic.postStream.loadPostByPostNumber(Number(postNumber));
    
    // Try to find it again after loading
    parentPost = topic.postStream.posts?.find(
      (p) => p.post_number === Number(postNumber)
    );
    
    if (parentPost) {
      console.log(`${LOG_PREFIX} Successfully loaded post ${postNumber}`);
    }
  } catch (loadError) {
    console.error(`${LOG_PREFIX} Failed to load post ${postNumber}:`, loadError);
  }
}

if (!parentPost) {
  console.error(`${LOG_PREFIX} Could not find or load post model for post number ${postNumber}`);
  return;
}

// Continue with composer.open() using the loaded parentPost
```

### Key Changes

1. **Changed `const` to `let`**: Allows reassignment after loading
2. **Added on-demand loading**: Calls `loadPostByPostNumber()` when post is missing
3. **Added comprehensive logging**: Tracks loading attempts and results
4. **Graceful error handling**: Catches and logs loading failures

## How It Works

### Step-by-Step Flow

1. **User clicks reply button** on an embedded post
2. **Post number is resolved** via DOM attributes or href parsing (e.g., post #82)
3. **Initial lookup** in `topic.postStream.posts` fails (post not loaded)
4. **On-demand loading triggered**:
   - Calls `topic.postStream.loadPostByPostNumber(82)`
   - Discourse fetches the post from the server
   - Post is added to `topic.postStream.posts` array
5. **Second lookup** finds the newly loaded post
6. **Composer opens** with the correct post model

### API Method Used

**`topic.postStream.loadPostByPostNumber(postNumber)`**

- **Purpose**: Loads a specific post by its post number
- **Returns**: Promise that resolves when post is loaded
- **Side Effect**: Adds the post to `topic.postStream.posts` array
- **Source**: Discourse core post-stream model

## Benefits

### 1. Reliability
- Works even when embedded posts aren't pre-loaded
- Handles sparse post streams (gaps in post numbers)
- No dependency on post ID → post number mapping

### 2. Performance
- Only loads posts when needed (lazy loading)
- Doesn't preload all embedded posts unnecessarily
- Minimal network overhead (single post fetch)

### 3. User Experience
- Seamless composer opening
- No visible delay (async loading)
- Clear error messages if loading fails

## Testing

### Expected Console Output (Success Case)

```
[Embedded Reply Buttons] Reply button clicked: <button>
[Embedded Reply Buttons] Target embedded post number: 82
[Embedded Reply Buttons] Target embedded post model: undefined
[Embedded Reply Buttons] Post 82 not in stream, loading on-demand...
[Embedded Reply Buttons] Available posts before load: [76, 77, 78, 79, 80, 81, 83, 85, ...]
[Embedded Reply Buttons] Successfully loaded post 82
[Embedded Reply Buttons] Opening composer with options: {...}
[Embedded Reply Buttons] Composer opened successfully
```

### Expected Console Output (Failure Case)

```
[Embedded Reply Buttons] Reply button clicked: <button>
[Embedded Reply Buttons] Target embedded post number: 82
[Embedded Reply Buttons] Target embedded post model: undefined
[Embedded Reply Buttons] Post 82 not in stream, loading on-demand...
[Embedded Reply Buttons] Failed to load post 82: Error: Post not found
[Embedded Reply Buttons] Could not find or load post model for post number 82
```

### Test Scenarios

1. **Embedded post in stream**: Should use cached post (no loading)
2. **Embedded post not in stream**: Should load on-demand
3. **Invalid post number**: Should fail gracefully with error message
4. **Network error**: Should catch and log loading error

## Related Issues Fixed

This fix also resolves:

1. **Duplicate nested buttons**: Fixed by filtering out buttons from item selectors
2. **Post number extraction**: Enhanced with href parsing fallback
3. **Container detection**: Prevents button from being treated as container

## Code Location

**File**: `javascripts/discourse/api-initializers/embedded-reply-buttons.gjs`  
**Lines**: 376-431 (post loading logic)  
**Function**: Global click handler for `.embedded-reply-button`

## References

- [Discourse Post Stream Model](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/models/post-stream.js)
- [Composer Service](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js)
- [Embedded Reply Buttons Implementation](./EMBEDDED_REPLY_BUTTONS_IMPLEMENTATION.md)

## Future Enhancements

Potential improvements:

1. **Batch loading**: Load multiple embedded posts at once
2. **Preloading**: Load embedded posts when section expands
3. **Caching**: Remember loaded posts across page changes
4. **Loading indicator**: Show spinner while loading post

