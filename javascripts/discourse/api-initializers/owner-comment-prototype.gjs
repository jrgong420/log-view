import { schedule } from "@ember/runloop";
import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("1.15.0", (api) => {
  const pluginId = "owner-comment-prototype";

  // Helper function to check if category matches configured categories
  function isCategoryEnabled(topic, settings) {
    if (!settings.owner_comment_categories) {
      return false;
    }

    const enabledCategories = settings.owner_comment_categories
      .split("|")
      .map((c) => c.trim())
      .filter((c) => c.length > 0);

    if (enabledCategories.length === 0) {
      return false;
    }

    const categoryId = topic.category_id?.toString();
    const categorySlug = topic.category?.slug;

    return enabledCategories.some(
      (cat) => cat === categoryId || cat === categorySlug
    );
  }

  // Helper function to apply owner filter
  function applyOwnerFilter(topic) {
    if (!topic || topic.__ownerFilterApplied) {
      return;
    }

    const postStream = topic.postStream;
    if (!postStream) {
      return;
    }

    // Only apply if no other filters are active
    if (postStream.userFilters && postStream.userFilters.length > 0) {
      return;
    }

    const ownerUsername = topic.details?.created_by?.username;
    if (!ownerUsername) {
      return;
    }

    // Mark as applied to prevent duplicate calls
    topic.__ownerFilterApplied = true;

    // Apply the participant filter
    postStream.filterParticipant(ownerUsername);

    // Set body data attribute for CSS scoping
    document.body.dataset.ownerCommentMode = "true";
  }

  // Helper function to clear owner filter
  function clearOwnerFilter() {
    delete document.body.dataset.ownerCommentMode;
  }

  // Hook into page changes to detect topic navigation
  api.onPageChange(() => {
    schedule("afterRender", () => {
      const topicController = api.container.lookup("controller:topic");
      const topic = topicController?.model;

      if (!topic) {
        clearOwnerFilter();
        return;
      }

      const settings = api.container.lookup("service:site-settings");
      const themeSettings = settings.theme_settings;

      if (!themeSettings) {
        clearOwnerFilter();
        return;
      }

      // Check if this topic's category is enabled for owner comments
      if (isCategoryEnabled(topic, themeSettings)) {
        applyOwnerFilter(topic);
      } else {
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

      // Only proceed if this is an owner post
      if (!this.args?.post?.topicOwner) {
        return;
      }

      // Check if owner comment mode is active
      if (document.body.dataset.ownerCommentMode !== "true") {
        return;
      }

      // Get theme settings
      const settings = this.siteSettings?.theme_settings;
      if (!settings) {
        return;
      }

      const prefetchCount = parseInt(settings.owner_comment_prefetch, 10);
      if (isNaN(prefetchCount) || prefetchCount <= 0) {
        return;
      }

      // Guard against concurrent prefetching
      if (this.__ownerPrefetching) {
        return;
      }

      // Check if we need to load more replies
      const post = this.args.post;
      const currentReplyCount = this.repliesBelow?.length || 0;
      const targetReplyCount = Math.min(post.reply_count || 0, prefetchCount);

      if (currentReplyCount >= targetReplyCount) {
        return;
      }

      // Start prefetching
      this.__ownerPrefetching = true;

      try {
        // Loop to load replies until we reach the target count
        while (
          (this.repliesBelow?.length || 0) < targetReplyCount &&
          this.canLoadMoreRepliesBelow
        ) {
          await this.loadMoreReplies();
        }
      } catch (error) {
        // eslint-disable-next-line no-console
        console.error("Error prefetching replies:", error);
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

