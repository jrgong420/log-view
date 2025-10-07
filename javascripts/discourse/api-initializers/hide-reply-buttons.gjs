import { schedule } from "@ember/runloop";
import { apiInitializer } from "discourse/lib/api";
import { parseCategoryIds } from "../lib/group-access-utils";

/**
 * Hide Reply Buttons for Non-Owners
 *
 * When enabled, hides top-level reply buttons (timeline and topic footer) from
 * non-owner users in categories configured for owner comments. Post-level reply
 * buttons remain visible and are styled as primary actions.
 *
 * This is a UI-only restriction and does not prevent replies via keyboard
 * shortcuts (Shift+R) or API calls.
 */

const DEBUG = true; // Set to false to disable debug logging

function debugLog(...args) {
  if (DEBUG) {
    // eslint-disable-next-line no-console
    console.log("[Hide Reply Buttons]", ...args);
  }
}

export default apiInitializer("1.15.0", (api) => {
  api.onPageChange((url) => {
    schedule("afterRender", () => {
      debugLog("Page changed to:", url);
      debugLog("Body class before evaluation:", document.body.classList.contains("hide-reply-buttons-non-owners"));

      // Guard 1: Check if setting is enabled
      if (!settings.hide_reply_buttons_for_non_owners) {
        document.body.classList.remove("hide-reply-buttons-non-owners");
        debugLog("Setting disabled; removing body class");
        return;
      }

      debugLog("Setting enabled; evaluating conditions");

      // Guard 2: Get topic data
      const topic = api.container.lookup("controller:topic")?.model;
      if (!topic) {
        debugLog("No topic found; removing body class");
        document.body.classList.remove("hide-reply-buttons-non-owners");
        return;
      }

      debugLog("Topic found:", { id: topic.id, category_id: topic.category_id });

      // Guard 3: Check if category is configured for owner comments
      const categoryId = topic.category_id;
      const enabledCategories = parseCategoryIds(settings.owner_comment_categories);

      debugLog("Category check:", {
        topicCategory: categoryId,
        enabledCategories,
      });

      if (!enabledCategories.includes(categoryId)) {
        debugLog("Category not configured; removing body class");
        document.body.classList.remove("hide-reply-buttons-non-owners");
        return;
      }

      debugLog("Category is configured; checking ownership");

      // Guard 4: Get current user and topic owner
      const currentUser = api.getCurrentUser();
      const topicOwnerId = topic.details?.created_by?.id;

      debugLog("User and owner IDs:", {
        currentUserId: currentUser?.id,
        topicOwnerId,
      });

      // Guard 5: Handle anonymous users or missing owner data
      if (!topicOwnerId) {
        debugLog("No topic owner data; removing body class");
        document.body.classList.remove("hide-reply-buttons-non-owners");
        return;
      }

      if (!currentUser) {
        debugLog("Anonymous user; hiding reply buttons");
        document.body.classList.add("hide-reply-buttons-non-owners");
        return;
      }

      // Decision: Compare user ID with topic owner ID
      const isOwner = currentUser.id === topicOwnerId;

      debugLog("Ownership decision:", {
        isOwner,
        action: isOwner ? "SHOW buttons (remove class)" : "HIDE buttons (add class)",
      });

      if (isOwner) {
        document.body.classList.remove("hide-reply-buttons-non-owners");
        debugLog("Body class removed (owner)");
      } else {
        document.body.classList.add("hide-reply-buttons-non-owners");
        debugLog("Body class added (non-owner)");
      }

      debugLog("Body class after evaluation:", document.body.classList.contains("hide-reply-buttons-non-owners"));
    });
  });
});

