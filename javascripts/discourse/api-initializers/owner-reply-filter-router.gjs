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
  const settings = api.container.lookup("service:site-settings");
  const currentUser = api.getCurrentUser();
  
  // Early exit if feature is disabled
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
    // Must have the query param
    const urlObj = new URL(url, window.location.origin);
    const hasFilterParam = urlObj.searchParams.get("owner_reply_filter") === "true";
    
    if (!hasFilterParam) {
      return false;
    }

    // Skip if username_filters is present (avoid double-filtering)
    if (urlObj.searchParams.get("username_filters")) {
      debugLog("Skipping: username_filters is present");
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

    const router = api.container.lookup("service:router");
    const topic = api.container.lookup("controller:topic")?.model;
    
    if (!topic) {
      debugLog("Toggle clicked but no topic model available");
      return;
    }

    // Set suppression flag
    suppressNextNavigation = true;
    suppressedTopicId = topic.id;
    debugLog(`Toggle clicked, suppressing next navigation for topic ${topic.id}`);

    // Remove filter param and navigate
    const currentUrl = new URL(window.location.href);
    currentUrl.searchParams.delete("owner_reply_filter");
    
    debugLog("Navigating to:", currentUrl.toString());
    window.location.replace(currentUrl.toString());
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
        return;
      }

      // Guard 3: Check if filter should be active
      const shouldActivate = shouldActivateFilter(url, topic);
      
      if (shouldActivate) {
        debugLog("Activating filter");
        activateFilter();
        injectNotice();
        bindToggleHandler();
      } else {
        debugLog("Filter not active");
        deactivateFilter();
        removeNotice();
      }
    });
  });

  debugLog("Router logic initialized");
});

