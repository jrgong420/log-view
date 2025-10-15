import { apiInitializer } from "discourse/lib/api";
import { schedule } from "@ember/runloop";
import { i18n } from "discourse-i18n";

/**
 * Owner Reply Filter Router Logic (Experimental Prototype)
 *
 * Handles URL query parameter (owner_reply_filter) and UI state management.
 *
 * RESPONSIBILITIES:
 * 1. Check if filter should be active based on URL param and settings
 * 2. Add/remove body class 'owner-reply-filter-active' to trigger CSS hiding
 * 3. Inject filter notice and toggle button (once per topic, idempotent)
 * 4. Handle toggle clicks with redirect-loop guards
 * 5. Skip when username_filters is present (avoid double-filtering)
 *
 * LIMITATIONS:
 * - Timeline and anchors may misalign (client-side only)
 * - For production, use server-side plugin
 */

export default apiInitializer("1.34.0", (api) => {
  const currentUser = api.getCurrentUser();

  // Early exit if feature is disabled (theme setting)
  if (!settings.enable_owner_reply_filter) {
    return;
  }

  const debugLog = (...args) => {
    if (settings.debug_owner_reply_filter) {
      console.log("[OwnerReplyFilterRouter]", ...args);
    }
  };

  debugLog("Initializing router logic");

  // Module-scoped state for one-shot suppression
  let suppressNextNavigation = false;
  let suppressedTopicId = null;

  // Module-scoped set to suppress auto-activated filter per topic (no navigation)
  const suppressedTopics = new Set();

  // Module-scoped DOM observer for marking posts (fallback when transformers don't run)
  let postObserver = null;
  let observedTopicId = null;

  function getTopicOwnerUsername() {
    const topic = api.container.lookup("controller:topic")?.model;
    return topic?.user?.username;
  }

  function markPostElement(postEl, ownerUsername) {
    try {
      if (!postEl || !ownerUsername) return;

      // Author username (for safety if not in owner-only view)
      const author = postEl.querySelector(".names .username a")?.textContent?.trim();
      if (!author || author !== ownerUsername) {
        return; // Not owner's post
      }

      // Is this a reply? (reply-to tab present)
      const replyTo = postEl.querySelector(".post-infos .reply-to-tab span");
      if (!replyTo) {
        return; // Top-level post, keep visible
      }

      const repliedUsername = replyTo.textContent?.trim();
      if (!repliedUsername) {
        return;
      }

      // Self-reply check
      if (repliedUsername === ownerUsername) {
        return; // self-reply, keep visible
      }

      // Mark as hidden-owner-reply on wrapper and article
      postEl.classList.add("hidden-owner-reply");
      const article = postEl.querySelector("article");
      if (article) article.classList.add("hidden-owner-reply");

      if (settings.debug_owner_reply_filter) {
        console.log("[OwnerReplyFilterRouter] Marked hidden-owner-reply:", {
          postNumber: postEl.getAttribute("data-post-number"),
          author,
          repliedUsername,
        });
      }
    } catch (e) {
      if (settings.debug_owner_reply_filter) {
        console.warn("[OwnerReplyFilterRouter] markPostElement error", e);
      }
    }
  }

  function initialScanPosts(ownerUsername) {
    const posts = document.querySelectorAll(".topic-post");
    posts.forEach((el) => markPostElement(el, ownerUsername));
  }

  function startPostObserver(topic) {
    const ownerUsername = getTopicOwnerUsername();
    if (!ownerUsername) {
      debugLog("Owner username not available; skipping post observer for now");
      return;
    }

    // Avoid duplicate observers per topic
    if (postObserver && observedTopicId === topic?.id) {
      return;
    }

    stopPostObserver();
    observedTopicId = topic?.id;

    // Initial pass
    initialScanPosts(ownerUsername);

    const container = document.querySelector(".post-stream") || document;
    postObserver = new MutationObserver((mutations) => {
      for (const m of mutations) {
        m.addedNodes?.forEach((node) => {
          if (!(node instanceof HTMLElement)) return;
          if (node.matches?.(".topic-post")) {
            markPostElement(node, ownerUsername);
          } else {
            node.querySelectorAll?.(".topic-post").forEach((el) => markPostElement(el, ownerUsername));
          }
        });
      }
    });

    postObserver.observe(container, { childList: true, subtree: true });
    debugLog("MutationObserver set up for post stream");
  }

  function stopPostObserver() {
    if (postObserver) {
      postObserver.disconnect();
      postObserver = null;
      observedTopicId = null;
      debugLog("MutationObserver disconnected");
    }
  }

  /**
   * Check if current topic is in allowed categories
   * Uses the same 'owner_comment_categories' setting as the main owner filter
   */
  function isAllowedCategory(topic) {
    if (!topic) return false;

    const allowedCategoriesStr = settings.owner_comment_categories || "";
    if (!allowedCategoriesStr.trim()) {
      // Empty = allow all categories
      return true;
    }

    const allowedCategoryIds = allowedCategoriesStr
      .split("|")
      .map(id => parseInt(id.trim(), 10))
      .filter(id => !isNaN(id));

    return allowedCategoryIds.includes(topic.category_id);
  }

  /**
   * Check if filter should be active
   */
  function shouldActivateFilter(url, topic) {
    const urlObj = new URL(url, window.location.origin);
    const hasFilterParam = urlObj.searchParams.get("owner_reply_filter") === "true";
    const hasUsernameFilters = !!urlObj.searchParams.get("username_filters");

    // Activation sources:
    // 1) Explicit param owner_reply_filter=true
    // 2) Owner-only view (username_filters present) AND auto-activate setting enabled
    const autoActivate = settings.auto_owner_reply_filter_in_owner_view === true || settings.auto_owner_reply_filter_in_owner_view === "true";
    const activationRequested = hasFilterParam || (hasUsernameFilters && autoActivate);

    if (!activationRequested) {
      return false;
    }

    // Check category allowlist
    if (!isAllowedCategory(topic)) {
      debugLog("Skipping: category not allowed");
      return false;
    }

    return true;
  }

  /**
   * Add body class to activate CSS hiding
   */
  function activateFilter() {
    document.body.classList.add("owner-reply-filter-active");
    debugLog("Filter activated (body class added)");
  }

  /**
   * Remove body class to deactivate CSS hiding
   */
  function deactivateFilter() {
    document.body.classList.remove("owner-reply-filter-active");
    debugLog("Filter deactivated (body class removed)");
  }

  /**
   * Inject filter notice and toggle button (idempotent)
   */
  function injectNotice() {
    // Only show if setting enabled
    if (!settings.show_owner_reply_filter_notice) {
      return;
    }

    // Check if already injected
    if (document.querySelector(".owner-reply-filter-notice")) {
      debugLog("Notice already exists, skipping injection");
      return;
    }

    const container = document.querySelector(".topic-body");
    if (!container) {
      debugLog("Topic body container not found");
      return;
    }

    const notice = document.createElement("div");
    notice.className = "owner-reply-filter-notice";
    notice.innerHTML = `
      <div class="notice-content">
        <div class="notice-title">${i18n(themePrefix("js.owner_reply_filter.notice_title"))}</div>
        <div class="notice-text">${i18n(themePrefix("js.owner_reply_filter.notice_text"))}</div>
      </div>
      <div class="notice-actions">
        <button class="btn btn-default owner-reply-filter-toggle">
          ${i18n(themePrefix("js.owner_reply_filter.show_all_button"))}
        </button>
      </div>
    `;

    container.insertBefore(notice, container.firstChild);
    debugLog("Notice injected");
  }

  /**
   * Remove filter notice
   */
  function removeNotice() {
    const notice = document.querySelector(".owner-reply-filter-notice");
    if (notice) {
      notice.remove();
      debugLog("Notice removed");
    }
  }

  /**
   * Handle toggle button click (with redirect-loop guards)
   */
  function handleToggleClick(e) {
    const target = e.target?.closest?.(".owner-reply-filter-toggle");
    if (!target) return;

    e.preventDefault();
    e.stopPropagation();

    const topic = api.container.lookup("controller:topic")?.model;
    if (!topic) {
      debugLog("Toggle clicked but no topic model available");
      return;
    }

    const currentUrl = new URL(window.location.href);
    const hasOwnerParam = currentUrl.searchParams.get("owner_reply_filter") === "true";
    const hasUsernameFilters = !!currentUrl.searchParams.get("username_filters");
    const autoActivate = settings.auto_owner_reply_filter_in_owner_view === true || settings.auto_owner_reply_filter_in_owner_view === "true";

    if (hasOwnerParam) {
      // Existing behavior: remove param and navigate
      suppressNextNavigation = true;
      suppressedTopicId = topic.id;
      debugLog(`Toggle clicked: removing owner_reply_filter param, suppressing next nav for topic ${topic.id}`);
      currentUrl.searchParams.delete("owner_reply_filter");
      debugLog("Navigating to:", currentUrl.toString());
      window.location.replace(currentUrl.toString());
      return;
    }

    if (hasUsernameFilters && autoActivate) {
      // Auto-activated case: suppress for this topic without navigation
      suppressedTopics.add(topic.id);
      debugLog(`Toggle clicked: suppressing auto-activated filter for topic ${topic.id}`);
      deactivateFilter();
      removeNotice();
      stopPostObserver();
      return;
    }

    // Fallback: just deactivate locally (no param to remove)
    debugLog("Toggle clicked: deactivating locally (no owner_reply_filter param and no auto-activation)");
    deactivateFilter();
    removeNotice();
    stopPostObserver();
  }

  /**
   * Bind toggle click handler (once, using event delegation)
   */
  let toggleHandlerBound = false;

  function bindToggleHandler() {
    if (toggleHandlerBound) return;

    document.addEventListener("click", handleToggleClick, true);
    toggleHandlerBound = true;
    debugLog("Toggle handler bound (event delegation)");
  }

  /**
   * Main page change handler
   */
  api.onPageChange((url, title) => {
    schedule("afterRender", () => {
      const topic = api.container.lookup("controller:topic")?.model;

      // Guard 1: Check suppression flag
      if (suppressNextNavigation && topic?.id === suppressedTopicId) {
        debugLog(`Suppressing navigation for topic ${topic.id}`);
        suppressNextNavigation = false;
        suppressedTopicId = null;
        deactivateFilter();
        removeNotice();
        stopPostObserver();
        return;
      }

      // Clear suppression if different topic
      if (suppressNextNavigation && topic?.id !== suppressedTopicId) {
        debugLog("Different topic, clearing suppression flag");
        suppressNextNavigation = false;
        suppressedTopicId = null;
      }

      // Guard 2: Check if we're on a topic page
      if (!topic) {
        debugLog("Not on a topic page");
        deactivateFilter();
        stopPostObserver();
        return;
      }

      // Guard 3: Check per-topic suppression (user turned it off in this view)
      if (suppressedTopics.has(topic.id)) {
        debugLog(`Filter suppressed for topic ${topic.id} by user`);
        deactivateFilter();
        removeNotice();
        stopPostObserver();
        return;
      }

      // Guard 4: Check if filter should be active (param or auto in owner-only view)
      const shouldActivate = shouldActivateFilter(url, topic);

      if (shouldActivate) {
        debugLog("Activating filter");
        activateFilter();
        injectNotice();
        bindToggleHandler();
        startPostObserver(topic);
      } else {
        debugLog("Filter not active");
        deactivateFilter();
        removeNotice();
        stopPostObserver();
      }
    });
  });

  debugLog("Router logic initialized");
});

