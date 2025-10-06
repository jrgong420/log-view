import { schedule } from "@ember/runloop";
import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("1.15.0", (api) => {
  const pluginId = "owner-comment-prototype";
  const DEBUG = true; // Set to false to disable debug logging

  function debugLog(...args) {
    if (DEBUG) {
      // eslint-disable-next-line no-console
      console.log("[Owner Comments]", ...args);
    }
  }

  // Helper function to check if category matches configured categories
  function isCategoryEnabled(topic, settings) {
    debugLog("Checking if category is enabled for topic:", topic.id);
    debugLog("Topic category_id:", topic.category_id);
    debugLog("Topic category:", topic.category);
    debugLog("Settings:", settings);

    if (!settings.owner_comment_categories) {
      debugLog("No categories configured in settings");
      return false;
    }

    // When list_type is 'category', Discourse provides category IDs as a pipe-separated string
    const categorySetting = settings.owner_comment_categories;
    debugLog("Raw category setting:", categorySetting);

    // Parse the category IDs from the setting
    const enabledCategoryIds = categorySetting
      .split("|")
      .map((c) => parseInt(c.trim(), 10))
      .filter((c) => !isNaN(c));

    debugLog("Enabled category IDs:", enabledCategoryIds);

    if (enabledCategoryIds.length === 0) {
      debugLog("No valid category IDs found in settings");
      return false;
    }

    const topicCategoryId = topic.category_id;
    const isEnabled = enabledCategoryIds.includes(topicCategoryId);

    debugLog(
      "Topic category ID:",
      topicCategoryId,
      "- Enabled:",
      isEnabled
    );

    return isEnabled;
  }

  // Helper function to apply owner filter
  function applyOwnerFilter(topic) {
    debugLog("Attempting to apply owner filter for topic:", topic.id);

    if (!topic) {
      debugLog("No topic provided");
      return;
    }

    if (topic.__ownerFilterApplied) {
      debugLog("Filter already applied to this topic");
      return;
    }

    const postStream = topic.postStream;
    if (!postStream) {
      debugLog("No postStream found");
      return;
    }

    // Only apply if no other filters are active
    if (postStream.userFilters && postStream.userFilters.length > 0) {
      debugLog("Other user filters already active:", postStream.userFilters);
      return;
    }

    const ownerUsername = topic.details?.created_by?.username;
    if (!ownerUsername) {
      debugLog("No owner username found");
      return;
    }

    debugLog("Applying filter for owner:", ownerUsername);

    // Mark as applied to prevent duplicate calls
    topic.__ownerFilterApplied = true;

    // Apply the participant filter
    postStream.filterParticipant(ownerUsername);

    // Set body data attribute for CSS scoping
    document.body.dataset.ownerCommentMode = "true";

    debugLog("✅ Owner filter applied successfully");
  }

  // Helper function to clear owner filter
  function clearOwnerFilter() {
    debugLog("Clearing owner filter");
    delete document.body.dataset.ownerCommentMode;
  }

  // Hook into page changes to detect topic navigation
  api.onPageChange(() => {
    debugLog("=== Page change detected ===");

    schedule("afterRender", () => {
      debugLog("Running afterRender hook");

      const topicController = api.container.lookup("controller:topic");
      debugLog("Topic controller:", topicController);

      const topic = topicController?.model;
      debugLog("Topic model:", topic);

      if (!topic) {
        debugLog("Not on a topic page, clearing filter");
        clearOwnerFilter();
        return;
      }

      // Access theme settings directly via the global settings object
      debugLog("Theme settings:", settings);

      if (!settings) {
        debugLog("No theme settings found, clearing filter");
        clearOwnerFilter();
        return;
      }

      // Check if this topic's category is enabled for owner comments
      if (isCategoryEnabled(topic, settings)) {
        debugLog("Category is enabled, applying filter");
        applyOwnerFilter(topic);
      } else {
        debugLog("Category not enabled, clearing filter");
        clearOwnerFilter();
        // Clear the flag if category doesn't match
        if (topic.__ownerFilterApplied) {
          delete topic.__ownerFilterApplied;
        }
      }
    });
  });

  // Modify the post component to auto-expand replies under owner posts
  api.modifyClass("component:post", {
    pluginId,

    async didReceiveAttrs() {
      this._super(...arguments);

      const post = this.args?.post;

      // Only proceed if this is an owner post
      if (!post?.topicOwner) {
        return;
      }

      debugLog("Processing owner post:", post.id);

      // Check if owner comment mode is active
      if (document.body.dataset.ownerCommentMode !== "true") {
        debugLog("Owner comment mode not active, skipping prefetch");
        return;
      }

      // Get theme settings
      const settings = this.siteSettings?.theme_settings;
      if (!settings) {
        debugLog("No theme settings found in post component");
        return;
      }

      const prefetchCount = parseInt(settings.owner_comment_prefetch, 10);
      debugLog("Prefetch count setting:", prefetchCount);

      if (isNaN(prefetchCount) || prefetchCount <= 0) {
        debugLog("Prefetch disabled or invalid");
        return;
      }

      // Guard against concurrent prefetching
      if (this.__ownerPrefetching) {
        debugLog("Already prefetching for this post");
        return;
      }

      // Check if we need to load more replies
      const currentReplyCount = this.repliesBelow?.length || 0;
      const targetReplyCount = Math.min(post.reply_count || 0, prefetchCount);

      debugLog(
        "Reply counts - Current:",
        currentReplyCount,
        "Target:",
        targetReplyCount,
        "Total:",
        post.reply_count
      );

      if (currentReplyCount >= targetReplyCount) {
        debugLog("Already have enough replies loaded");
        return;
      }

      // Start prefetching
      debugLog("Starting reply prefetch...");
      this.__ownerPrefetching = true;

      try {
        let iterations = 0;
        const maxIterations = 10; // Safety limit

        // Loop to load replies until we reach the target count
        while (
          (this.repliesBelow?.length || 0) < targetReplyCount &&
          this.canLoadMoreRepliesBelow &&
          iterations < maxIterations
        ) {
          debugLog(
            `Loading more replies (iteration ${iterations + 1})...`
          );
          await this.loadMoreReplies();
          iterations++;
        }

        debugLog(
          `✅ Prefetch complete. Loaded ${this.repliesBelow?.length || 0} replies`
        );
      } catch (error) {
        debugLog("❌ Error prefetching replies:", error);
        // eslint-disable-next-line no-console
        console.error("[Owner Comments] Error prefetching replies:", error);
      } finally {
        this.__ownerPrefetching = false;
      }
    },

    willDestroy() {
      this._super(...arguments);
      // Clean up prefetching flag
      delete this.__ownerPrefetching;
    },
  });
});

