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

  function getRequestedPostNumberFromPath(pathname) {
    // Discourse topic URL path: /t/<slug>/<topicId>[/<postNumber>]
    const parts = pathname.split("/").filter(Boolean);
    const maybeNumber = parts[parts.length - 1];
    const num = parseInt(maybeNumber, 10);
    return Number.isFinite(num) ? num : null;
  }

  function nearestOwnerPostNumber(topic, requested) {
    const owner = topic?.details?.created_by?.username;
    const posts = topic?.postStream?.posts || [];
    let before = null;
    let after = null;

    for (const p of posts) {
      if (p?.username !== owner) {
        continue;
      }
      const n = p?.post_number;
      if (!Number.isFinite(n)) {
        continue;
      }
      if (n <= requested) {
        if (before === null || n > before) {
          before = n;
        }
      } else {
        if (after === null || n < after) {
          after = n;
        }
      }
    }

    // Prefer earlier (to avoid spoilers); otherwise pick next; otherwise null
    return before ?? after ?? null;
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

    // Decide landing post number
    const requested = getRequestedPostNumberFromPath(url.pathname);
    let targetPostNumber = requested;

    // If requested post isn't by owner, try to find a nearby owner post from loaded posts
    if (requested) {
      const posts = topic?.postStream?.posts || [];
      const requestedPost = posts.find((p) => p?.post_number === requested);
      if (!requestedPost || requestedPost?.username !== ownerUsername) {
        const nearest = nearestOwnerPostNumber(topic, requested);
        if (nearest) {
          targetPostNumber = nearest;
        } else {
          // Fallback: drop explicit post number to land at start of filtered stream
          targetPostNumber = null;
        }
      }
    }

    // Build filtered URL
    const baseParts = url.pathname.split("/").filter(Boolean);
    // Ensure we have at least ["t", slug, topicId]
    const topicId = String(topic.id);
    const slugIndex = baseParts.findIndex((p) => p === "t");
    let basePath;
    if (slugIndex >= 0 && baseParts.length >= slugIndex + 3) {
      basePath = `/${baseParts.slice(0, slugIndex + 3).join("/")}`;
    } else {
      // Fallback to canonical
      basePath = `/t/${topic.slug}/${topicId}`;
    }

    const newPath = targetPostNumber
      ? `${basePath}/${targetPostNumber}`
      : basePath;

    const newUrl = new URL(url.origin + newPath + url.hash);
    newUrl.searchParams.set("username_filters", ownerUsername);

    debugLog("Navigating to server-filtered URL:", newUrl.toString());

    // Use SPA route if available, otherwise hard replace
    try {
      DiscourseURL.routeTo(newUrl.toString());
    } catch (e) {
      // eslint-disable-next-line no-console
      console.warn("[Owner Comments] SPA routeTo failed, falling back to hard replace", e);
      window.location.replace(newUrl.toString());
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

