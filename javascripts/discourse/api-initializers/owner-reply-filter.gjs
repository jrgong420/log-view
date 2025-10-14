import { apiInitializer } from "discourse/lib/api";

/**
 * Owner Reply Filter (Experimental Prototype)
 * 
 * This is a theme-only, client-side prototype that hides posts authored by the topic owner
 * when those posts are replies to other users (not top-level posts or self-replies).
 * 
 * LIMITATIONS:
 * - Timeline and scroll anchors may misalign because the underlying post stream is not modified
 * - Reply chains may reference hidden posts, causing UX confusion
 * - For production use, implement as a server-side plugin to filter the post stream properly
 * 
 * This initializer:
 * 1. Registers a value transformer to add 'hidden-owner-reply' class to qualifying posts
 * 2. The class is only effective when body has 'owner-reply-filter-active' (set by router logic)
 */

export default apiInitializer("1.34.0", (api) => {
  // Early exit if feature is disabled (theme setting)
  if (!settings.enable_owner_reply_filter) {
    return;
  }

  const debugLog = (...args) => {
    if (settings.debug_owner_reply_filter) {
      console.log("[OwnerReplyFilter]", ...args);
    }
  };

  debugLog("Initializing owner reply filter transformer");

  /**
   * Register value transformer to mark posts that should be hidden
   * 
   * A post is marked if ALL of these conditions are true:
   * 1. Post author is the topic owner (post.user_id === post.topic.user_id)
   * 2. Post is a reply (post.reply_to_post_number exists)
   * 3. Post is NOT a self-reply (post.reply_to_user.id !== topic owner id)
   */
  api.registerValueTransformer("post-class", ({ value, context }) => {
    const { post } = context;
    
    // Defensive checks - ensure we have the data we need
    if (!post || !post.topic) {
      return value;
    }

    const topicOwnerId = post.topic.user_id;
    const postAuthorId = post.user_id;
    
    // Not authored by topic owner - don't mark
    if (postAuthorId !== topicOwnerId) {
      return value;
    }

    // Top-level post (no reply_to_post_number) - don't mark
    if (!post.reply_to_post_number) {
      return value;
    }

    // Self-reply check - if reply_to_user exists and matches topic owner, don't mark
    // Be defensive: if reply_to_user is missing, we can't determine, so don't mark
    if (!post.reply_to_user || !post.reply_to_user.id) {
      debugLog(
        `Post ${post.id}: reply_to_user data missing, skipping mark`,
        post
      );
      return value;
    }

    const replyToUserId = post.reply_to_user.id;
    
    // Self-reply - don't mark
    if (replyToUserId === topicOwnerId) {
      return value;
    }

    // All conditions met: this is an owner reply to another user
    debugLog(
      `Post ${post.id}: Marking as hidden-owner-reply (owner ${topicOwnerId} replied to user ${replyToUserId})`
    );
    
    return [...value, "hidden-owner-reply"];
  });

  debugLog("Owner reply filter transformer registered");
});

