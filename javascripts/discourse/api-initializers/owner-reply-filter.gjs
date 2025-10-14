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

// Track owner's post numbers we've seen to infer self-replies when reply_to_user is missing
const ownerPostNumbers = new Set();

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
   * 3. Post is NOT a self-reply (try multiple strategies; if unknown, assume reply-to-others)
   */
  api.registerValueTransformer("post-class", ({ value, context }) => {
    const { post } = context;

    // If debug is enabled, add a visible marker class to all posts to verify transformer is running
    let classes = Array.isArray(value) ? [...value] : [value].filter(Boolean);
    if (settings.debug_owner_reply_filter) {
      classes.push("owner-reply-filter-mark");
    }

    // Defensive checks - ensure we have the data we need
    if (!post || !post.topic) {
      return classes.length ? classes : value;
    }

    const topicOwnerId = post.topic.user_id;
    const postAuthorId = post.user_id;
    const postNumber = post.post_number;

    // Debug: log transformer entry
    debugLog("[post-class]", {
      id: post.id,
      post_number: postNumber,
      user_id: postAuthorId,
      topic_owner_id: topicOwnerId,
      reply_to_post_number: post.reply_to_post_number,
      reply_to_user_id: post.reply_to_user?.id ?? post.reply_to_user_id,
    });

    // If this post is by owner, remember its number for self-reply inference
    if (postAuthorId === topicOwnerId && postNumber) {
      ownerPostNumbers.add(postNumber);
    }

    // Not authored by topic owner - don't mark
    if (postAuthorId !== topicOwnerId) {
      return classes.length ? classes : value;
    }

    // Top-level post (no reply_to_post_number) - don't mark
    if (!post.reply_to_post_number) {
      return classes.length ? classes : value;
    }

    // Determine if this is a self-reply
    let isSelfReply = false;

    // Strategy 1: reply_to_user.id
    const replyToUserId = post.reply_to_user?.id ?? post.reply_to_user_id;
    if (replyToUserId != null) {
      isSelfReply = replyToUserId === topicOwnerId;
    } else {
      // Strategy 2: infer via seen owner's post numbers
      const repliedNumber = post.reply_to_post_number;
      if (repliedNumber != null) {
        isSelfReply = ownerPostNumbers.has(repliedNumber);
      }
    }

    if (isSelfReply) {
      debugLog(`Post ${post.id}: owner self-reply detected; not hiding`);
      return classes.length ? classes : value;
    }

    // All conditions met: this is an owner reply to another user
    debugLog(
      `Post ${post.id}: Marking as hidden-owner-reply (owner ${topicOwnerId} replied to non-owner)`
    );

    classes.push("hidden-owner-reply");
    return classes.length ? classes : value;
  });

  debugLog("Owner reply filter transformer registered");
});

