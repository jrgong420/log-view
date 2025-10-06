import { schedule } from "@ember/runloop";
import { apiInitializer } from "discourse/lib/api";

// Note: `settings` is a global variable provided by Discourse for theme components
// It contains all theme settings defined in settings.yml
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

    // DOM fallback prefetch in case component hooks don't fire
    const prefetchCount = parseInt(settings?.owner_comment_prefetch, 10) || 0;
    if (prefetchCount > 0) {
      debugLog("Scheduling DOM prefetch with count:", prefetchCount);
      // Give Discourse a moment to render filtered posts before clicking toggles
      setTimeout(() => domPrefetchOwnerReplies(prefetchCount), 250);
    }
  }

  // Helper function to clear owner filter
  function clearOwnerFilter() {
    debugLog("Clearing owner filter");
    delete document.body.dataset.ownerCommentMode;
  }

  // DOM-based fallback: prefetch replies by clicking toggle buttons
  async function domPrefetchOwnerReplies(prefetchCount) {
    if (!prefetchCount || isNaN(prefetchCount) || prefetchCount <= 0) {
      return;
    }
    if (window.__ownerDomPrefetching) {
      debugLog("DOM prefetch already running; skipping");
      return;
    }
    window.__ownerDomPrefetching = true;

    try {
      // Look for owner posts in the stream
      const ownerPostSelectors = [
        ".topic-owner", // common class on OP posts
        '[data-topic-owner="true"]', // alternative data attribute
      ];
      const container = document.querySelector("#topic, .topic-area, .posts");
      if (!container) {
        debugLog("DOM prefetch: no topic container found");
        return;
      }

      let ownerPosts = [];
      for (const sel of ownerPostSelectors) {
        ownerPosts = Array.from(container.querySelectorAll(sel));
        if (ownerPosts.length) {
          break;
        }
      }
      debugLog("DOM prefetch: found owner posts:", ownerPosts.length);

      const replyToggleSelectors = [
        ".toggle-replies",
        ".more-replies",
        ".expand-hidden",
        ".show-replies",
        ".collapsed-replies .toggle-replies",
      ];

      let totalClicks = 0;
      const maxTotalClicks = 30;

      for (const postEl of ownerPosts) {
        let clicksForThisPost = 0;
        while (clicksForThisPost < prefetchCount && totalClicks < maxTotalClicks) {
          let toggleBtn;
          for (const sel of replyToggleSelectors) {
            toggleBtn = postEl.querySelector(sel);
            if (toggleBtn) {
              break;
            }
          }
          if (!toggleBtn) {
            debugLog("DOM prefetch: no reply toggle found for a post");
            break;
          }

          debugLog(
            `DOM prefetch: clicking replies toggle (postIdx=${ownerPosts.indexOf(postEl)}, click=${clicksForThisPost + 1})`
          );
          toggleBtn.click();
          totalClicks++;
          clicksForThisPost++;
          // small pause to let the DOM update
          await new Promise((r) => setTimeout(r, 150));
        }
      }

      debugLog(
        `DOM prefetch complete. Total clicks performed: ${totalClicks} (limit ${maxTotalClicks})`
      );
    } catch (e) {
      debugLog("DOM prefetch error:", e);
      // eslint-disable-next-line no-console
      console.error("[Owner Comments] DOM prefetch error:", e);
    } finally {
      window.__ownerDomPrefetching = false;
    }
  }

  // Per-post DOM prefetch helper for decorateCookedElement
  async function domPrefetchOwnerRepliesInPost(postEl, prefetchCount) {
    try {
      if (!postEl || !prefetchCount || isNaN(prefetchCount) || prefetchCount <= 0) {
        return;
      }

      const replyToggleSelectors = [
        ".toggle-replies",
        ".more-replies",
        ".expand-hidden",
        ".show-replies",
        ".collapsed-replies .toggle-replies",
      ];

      let clicks = 0;
      const maxClicks = Math.max(3, prefetchCount);

      while (clicks < prefetchCount && clicks < maxClicks) {
        let btn;
        for (const sel of replyToggleSelectors) {
          btn = postEl.querySelector(sel);
          if (btn) {
            break;
          }
        }
        if (!btn) {
          debugLog("Per-post prefetch: no toggle found");
          break;
        }
        debugLog("Per-post prefetch: clicking replies toggle", clicks + 1);
        btn.click();
        clicks++;
        await new Promise((r) => setTimeout(r, 150));
      }
    } catch (e) {
      debugLog("Per-post DOM prefetch error:", e);
      // eslint-disable-next-line no-console
      console.error("[Owner Comments] Per-post DOM prefetch error:", e);
    }
  }

  // Prefer modern hook that runs each time a post's cooked content renders
  api.decorateCookedElement(
    (elem) => {
      try {
        if (document.body.dataset.ownerCommentMode !== "true") {
          return;
        }
        const prefetchCount = parseInt(settings?.owner_comment_prefetch, 10) || 0;
        if (prefetchCount <= 0) {
          return;
        }

        // Find the outer post element for this cooked content
        const postEl = elem.closest(".topic-post, article");
        if (!postEl) {
          return;
        }

        // Only act on owner posts
        const isOwnerPost =
          postEl.classList.contains("topic-owner") ||
          postEl.getAttribute("data-topic-owner") === "true";
        if (!isOwnerPost) {
          return;
        }

        // Run per-post prefetch after a short delay to ensure buttons are in DOM
        setTimeout(() => domPrefetchOwnerRepliesInPost(postEl, prefetchCount), 50);
      } catch (e) {
        debugLog("decorateCookedElement prefetch error:", e);
      }
    },
    { id: "owner-comments-prefetch", onlyStream: true }
  );



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
  api.modifyClass("component:post-stream/post", {
    pluginId,

    didInsertElement() {
      this._super(...arguments);
      debugLog("post-stream/post didInsertElement fired");
      try {
        this.tryPrefetchReplies?.();
      } catch (e) {
        debugLog("Prefetch error in didInsertElement:", e);
      }
    },

    async didReceiveAttrs() {
      this._super(...arguments);
      debugLog("post-stream/post didReceiveAttrs fired");
      if (typeof this.tryPrefetchReplies === "function") {
        await this.tryPrefetchReplies();
      }
    },

    async tryPrefetchReplies() {
      const post = this.args?.post || this.post;
      if (!post) {
        debugLog("No post found on component args/state");
        return;
      }

      // Only proceed if this is an owner post
      if (!post.topicOwner) {
        return;
      }

      debugLog("Processing owner post:", post.id);

      // Check if owner comment mode is active
      if (document.body.dataset.ownerCommentMode !== "true") {
        debugLog("Owner comment mode not active, skipping prefetch");
        return;
      }

      // Access theme settings from global settings variable
      const prefetchCount = parseInt(settings?.owner_comment_prefetch, 10);
      debugLog("Prefetch count setting:", prefetchCount);

      if (!prefetchCount || isNaN(prefetchCount) || prefetchCount <= 0) {
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
          iterations < maxIterations
        ) {
          if (typeof this.loadMoreReplies === "function" && this.canLoadMoreRepliesBelow) {
            debugLog(`Calling loadMoreReplies (iteration ${iterations + 1})...`);
            await this.loadMoreReplies();
          } else {
            // Fallback: click the expand/hidden replies toggle in DOM
            const btn =
              this.element?.querySelector(
                ".toggle-replies, .more-replies, .expand-hidden, .show-replies, .collapsed-replies .toggle-replies"
              );
            if (btn) {
              debugLog(`Clicking replies toggle (iteration ${iterations + 1})...`);
              btn.click();
              await new Promise((r) => setTimeout(r, 150));
            } else {
              debugLog("No replies toggle button found for this post");
              break;
            }
          }
          iterations++;
        }

        debugLog(`✅ Prefetch complete. Loaded ${this.repliesBelow?.length || 0} replies`);
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

