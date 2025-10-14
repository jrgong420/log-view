import { schedule } from "@ember/runloop";
import { apiInitializer } from "discourse/lib/api";
import { createLogger } from "../lib/logger";

/**
 * Owner Comment Prototype - Auto-filter topics to show only owner's posts
 *
 * Settings used:
 * - owner_comment_categories: list of category IDs where auto-filter applies
 * - auto_mode: enable automatic filtering
 * - debug_logging_enabled: enable verbose console logging
 *
 * Note: `settings` is a global variable provided by Discourse for theme components
 */
export default apiInitializer("1.15.0", (api) => {
  const log = createLogger("[Owner View] [Owner Comments]");

  // Helper function to check if category matches configured categories
  function isCategoryEnabled(topic, settings) {
    log.debug("Checking if category is enabled", {
      topicId: topic.id,
      categoryId: topic.category_id
    });

    if (!settings.owner_comment_categories) {
      log.debug("No categories configured in settings");
      return false;
    }

    // When list_type is 'category', Discourse provides category IDs as a pipe-separated string
    const categorySetting = settings.owner_comment_categories;

    // Parse the category IDs from the setting
    const enabledCategoryIds = categorySetting
      .split("|")
      .map((c) => parseInt(c.trim(), 10))
      .filter((c) => !isNaN(c));

    log.debug("Category configuration", {
      rawSetting: categorySetting,
      enabledCategoryIds
    });

    if (enabledCategoryIds.length === 0) {
      log.debug("No valid category IDs found in settings");
      return false;
    }

    const topicCategoryId = topic.category_id;
    const isEnabled = enabledCategoryIds.includes(topicCategoryId);

    log.info("Category check result", {
      topicCategoryId,
      isEnabled,
      enabledCategoryIds
    });

    return isEnabled;
  }

  function ensureServerSideFilter(topic) {
    const ownerUsername = topic?.details?.created_by?.username;
    if (!ownerUsername) {
      log.debug("Owner username not yet available; skip navigation this cycle");
      return false;
    }

    const url = new URL(window.location.href);
    const currentFilter = url.searchParams.get("username_filters");

    log.debug("Checking server-side filter", {
      ownerUsername,
      currentFilter,
      alreadyFiltered: currentFilter === ownerUsername
    });

    if (currentFilter === ownerUsername) {
      // Already filtered by owner; mark and continue
      document.body.dataset.ownerCommentMode = "true";
      log.info("Already filtered by owner; marking body");
      return true;
    }

    // Preserve current path/post_number; only set the filter username
    url.searchParams.set("username_filters", ownerUsername);

    log.info("Navigating to server-filtered URL", {
      url: url.toString(),
      ownerUsername
    });

    // Force a full navigation so the server builds the filtered TopicView
    window.location.replace(url.toString());

    return false; // We triggered navigation; stop further work in this cycle
  }

  function clearOwnerFilter() {
    log.info("Clearing owner filter");
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
            log.info("User opted out via filtered notice", {
              topicId,
              action: "Setting one-shot suppression flag"
            });
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
  api.onPageChange((url) => {
    log.info("=== Page change detected ===", { url });

    schedule("afterRender", () => {
      log.debug("Running afterRender hook");

      const topicController = api.container.lookup("controller:topic");
      const topic = topicController?.model;

      log.debug("Topic controller resolved", {
        hasController: !!topicController,
        hasTopic: !!topic,
        topicId: topic?.id
      });

      if (!topic) {
        log.debug("Not on a topic page, clearing filter");
        clearOwnerFilter();
        return;
      }

      if (!settings) {
        log.warn("No theme settings found, clearing filter");
        clearOwnerFilter();
        return;
      }

      // Evaluate current filter state and auto-mode
      const currentUrl = new URL(window.location.href);
      const currentFilter = currentUrl.searchParams.get("username_filters");
      const hasFilteredNotice = !!document.querySelector(".posts-filtered-notice");

      log.debug("Current state", {
        currentFilter,
        hasFilteredNotice,
        bodyMarker: document.body.dataset.ownerCommentMode
      });

      // One-shot per-topic opt-out (set when user toggles to unfiltered)
      if (isOptOut(topic.id)) {
        log.info("Opt-out present; skipping auto-filter once for this topic", {
          topicId: topic.id
        });
        clearOptOut(topic.id);
        clearOwnerFilter();
        return;
      }

      // If the page is already filtered (URL param or UI notice), do not re-apply.
      if (currentFilter || hasFilteredNotice) {
        log.info("Already server-filtered; marking mode", {
          source: hasFilteredNotice ? "UI notice" : "URL parameter",
          currentFilter
        });
        document.body.dataset.ownerCommentMode = "true";
        bindOptOutClick(topic.id);
        return;
      }

      // One-shot suppression after user opted out: skip auto-filter for this view only
      if (suppressNextAutoFilter) {
        if (topic.id === suppressedTopicId) {
          log.info("One-shot suppression active; skipping auto-filter", {
            topicId: topic.id
          });
          suppressNextAutoFilter = false;
          suppressedTopicId = null;
          clearOwnerFilter();
          return;
        } else {
          // Topic changed unexpectedly; clear the suppression
          log.debug("Topic changed; clearing suppression flag", {
            expectedTopicId: suppressedTopicId,
            actualTopicId: topic.id
          });
          suppressNextAutoFilter = false;
          suppressedTopicId = null;
        }
      }

      if (settings.auto_mode === false) {
        log.info("Auto-mode disabled via setting; skipping auto-filter");
        clearOwnerFilter();
        return;
      }

      // Check if this topic's category is enabled for owner comments
      if (isCategoryEnabled(topic, settings)) {
        log.info("Category is enabled; ensuring server-side filter");
        const ok = ensureServerSideFilter(topic);
        if (ok) {
          document.body.dataset.ownerCommentMode = "true";
        }
      } else {
        log.debug("Category not enabled, clearing filter");
        clearOwnerFilter();
      }
    });
  });

});
