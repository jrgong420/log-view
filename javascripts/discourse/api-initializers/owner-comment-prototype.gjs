import { schedule } from "@ember/runloop";
import { apiInitializer } from "discourse/lib/api";

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
      debugLog("Owner username not yet available; skip navigation this cycle");
      return false;
    }

    const url = new URL(window.location.href);
    const currentFilter = url.searchParams.get("username_filters");

    if (currentFilter === ownerUsername) {
      // Already filtered by owner; mark and continue
      document.body.dataset.ownerCommentMode = "true";
      return true;
    }

    // Preserve current path/post_number; only set the filter username
    url.searchParams.set("username_filters", ownerUsername);

    debugLog("Navigating to server-filtered URL:", url.toString());

    // Force a full navigation so the server builds the filtered TopicView
    window.location.replace(url.toString());

    return false; // We triggered navigation; stop further work in this cycle
  }

  function clearOwnerFilter() {
    debugLog("Clearing owner filter");
    delete document.body.dataset.ownerCommentMode;
  }

  // Per-topic auto-mode opt-out helpers (session-scoped)
  const OPT_OUT_PREFIX = "ownerCommentsOptOut:";
  function optOutKey(topicId) {
    return `${OPT_OUT_PREFIX}${topicId}`;
  }
  function isOptOut(topicId) {
    try {
      return sessionStorage.getItem(optOutKey(topicId)) === "1";
    } catch {
      return false;
    }
  }
  function clearOptOut(topicId) {
    try {
      sessionStorage.removeItem(optOutKey(topicId));
    } catch {}
  }
  function bindOptOutClick() {
    // No-op: opt-out click is handled via a global delegated listener
    // This function remains for backward compatibility with earlier logic.
  }

  // Toggle button is now rendered via renderInOutlet registrations:
  // - Desktop: timeline-footer-controls-after
  // - Mobile: before-topic-progress
  // See: javascripts/discourse/api-initializers/owner-toggle-outlets.gjs


  // One-shot suppression flags for current view only
  let suppressNextAutoFilter = false;
  let suppressedTopicId = null;

  // Global delegated click listener for opt-out that survives re-renders
  let optOutDelegationBound = false;
  if (!optOutDelegationBound) {
    document.addEventListener(
      "click",
      (e) => {
        const target = e.target?.closest?.(
          ".posts-filtered-notice button, .posts-filtered-notice a"
        );
        if (!target) { return; }
        try {
          const topic = api.container.lookup("controller:topic")?.model;
          const topicId = topic?.id;
          if (topicId) {
            debugLog(
              "User opted out via filtered notice (delegated); suppressing auto-mode for this view only"
            );
            suppressNextAutoFilter = true;
            suppressedTopicId = topicId;
          }
        } catch {
          // no-op
        }
      },
      true
    );
    optOutDelegationBound = true;
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

      // Evaluate current filter state and auto-mode
      const url = new URL(window.location.href);
      const currentFilter = url.searchParams.get("username_filters");
      const hasFilteredNotice = !!document.querySelector(".posts-filtered-notice");


      // One-shot per-topic opt-out (set when user toggles to unfiltered)
      if (isOptOut(topic.id)) {
        debugLog("Opt-out present; skipping auto-filter once for this topic");
        clearOptOut(topic.id);
        clearOwnerFilter();
        return;
      }

      // If the page is already filtered (URL param or UI notice), do not re-apply.
      if (currentFilter || hasFilteredNotice) {
        debugLog(
          hasFilteredNotice
            ? "Already server-filtered (UI notice present); marking mode and binding opt-out"
            : "Already server-filtered (some username); marking mode and binding opt-out"
        );
        document.body.dataset.ownerCommentMode = "true";
        bindOptOutClick(topic.id);
        return;
      }

      // One-shot suppression after user opted out: skip auto-filter for this view only
      if (suppressNextAutoFilter) {
        if (topic.id === suppressedTopicId) {
          debugLog("One-shot suppression active; skipping auto-filter for this view");
          suppressNextAutoFilter = false;
          suppressedTopicId = null;
          clearOwnerFilter();
          return;
        } else {
          // Topic changed unexpectedly; clear the suppression
          suppressNextAutoFilter = false;
          suppressedTopicId = null;
        }
      }


      if (settings.auto_mode === false) {
        debugLog("Auto-mode disabled via setting; skipping auto-filter");
        clearOwnerFilter();
        return;
      }


      // Check if this topic's category is enabled for owner comments
      if (isCategoryEnabled(topic, settings)) {
        debugLog("Category is enabled; ensuring server-side filter");
        const ok = ensureServerSideFilter(topic);
        if (ok) {
          document.body.dataset.ownerCommentMode = "true";
        }
      } else {
        debugLog("Category not enabled, clearing filter");
        clearOwnerFilter();
      }
    });
  });

});
