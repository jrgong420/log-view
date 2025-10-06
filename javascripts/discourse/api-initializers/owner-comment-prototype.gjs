import { schedule } from "@ember/runloop";
import { apiInitializer } from "discourse/lib/api";
import DiscourseURL from "discourse/lib/url";

// Note: `settings` is a global variable provided by Discourse for theme components
// It contains all theme settings defined in settings.yml
export default apiInitializer("1.15.0", (api) => {
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

  function ensureServerSideFilter(topic) {
    const ownerUsername = topic?.details?.created_by?.username;
    if (!ownerUsername) {
      debugLog("No owner username found");
      return false;
    }

    const url = new URL(window.location.href);
    const currentFilter = url.searchParams.get("username_filters");

    if (currentFilter === ownerUsername) {
      // Already filtered by owner, mark dataset and continue
      document.body.dataset.ownerCommentMode = "true";
      return true;
    }

    // Preserve the current path and post_number. Only set username_filters.
    url.searchParams.set("username_filters", ownerUsername);

    debugLog("Navigating to server-filtered URL:", url.toString());

    // Use SPA route if available, otherwise hard replace
    try {
      DiscourseURL.routeTo(url.toString());
    } catch (e) {
      // eslint-disable-next-line no-console
      console.warn("[Owner Comments] SPA routeTo failed, falling back to hard replace", e);
      window.location.replace(url.toString());
    }

    return false; // We triggered navigation; current handler can stop further work
  }

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
        debugLog("Category is enabled; ensuring server-side filter");
        const ok = ensureServerSideFilter(topic);
        if (ok) {
          // filtered by server; mark dataset for CSS scoping
          document.body.dataset.ownerCommentMode = "true";
        }
      } else {
        debugLog("Category not enabled, clearing filter");
        clearOwnerFilter();
      }
    });
  });

});

