import { getOwner } from "@ember/owner";

/**
 * Shared utility for checking group-based access control and category settings.
 * Used by connectors to gate rendering via shouldRender.
 */
const DEBUG = true; // Set to false to disable debug logging
function debugLog(...args) {
  if (DEBUG) {
    // eslint-disable-next-line no-console
    console.log("[Group Access Control]", ...args);
  }
}


/**
 * Check if the current user is allowed to access the theme component.
 * @param {Object} helper - The helper object from shouldRender
 * @returns {boolean} true if user is allowed, false otherwise
 */
export function isUserAllowedAccess(helper, fallbackContext = null) {
  const container = resolveOwner(helper) || resolveOwner(fallbackContext);
  const currentUser = container?.lookup?.("service:current-user")?.user;

  // Get theme settings from the global settings object
  // Note: In connectors, settings is available globally (not window.settings)
  const themeSettings = typeof settings !== "undefined" ? settings : {};

  // Extract allowed group IDs from the list setting (pipe-separated)
  const allowedGroupsSetting = themeSettings.allowed_groups || "";
  const allowedGroupIds = allowedGroupsSetting
    .split("|")
    .map((id) => parseInt(id.trim(), 10))
    .filter((id) => !isNaN(id));

  debugLog("Allowed group IDs:", allowedGroupIds);

  // If no groups are configured, enable for all users (unrestricted)
  if (allowedGroupIds.length === 0) {
    debugLog("No groups configured; enabling for all users (unrestricted access)");
    return true;
  }

  // Groups are configured: anonymous users are not members of any group
  if (!currentUser) {
    debugLog("Anonymous user and groups are configured; denying access");
    return false;
  }

  // Check if user belongs to any of the allowed groups
  const userGroups = currentUser.groups || [];
  const userGroupIds = userGroups.map((g) => g.id);

  debugLog("User group IDs:", userGroupIds);

  const isMember = allowedGroupIds.some((allowedId) => userGroupIds.includes(allowedId));
  debugLog(
    `Access decision: ${isMember ? "granted" : "denied"}; user is ${
      isMember ? "" : "NOT "
    }a member of allowed groups`
  );

  return isMember;
}

function resolveOwner(context) {
  if (!context) {
    return null;
  }

  if (typeof context.lookup === "function") {
    return context;
  }

  if (typeof context.owner?.lookup === "function") {
    return context.owner;
  }

  try {
    const owner = getOwner(context);
    if (typeof owner?.lookup === "function") {
      return owner;
    }
  } catch {
    // getOwner throws when context has no owner metadata; ignore.
  }

  return null;
}

/**
 * Check if the toggle button should be shown based on settings and category.
 * @param {Object} outletArgs - The outlet arguments containing the topic model
 * @returns {boolean} true if toggle button should be shown, false otherwise
 */
export function shouldShowToggleButton(outletArgs) {

  const themeSettings = typeof settings !== "undefined" ? settings : {};

  // eslint-disable-next-line no-console
  console.log(
    "[Toggle Button] Settings object:",
    themeSettings,
    "toggle_view_button_enabled:",
    themeSettings.toggle_view_button_enabled
  );

  // Check if toggle button is enabled in settings
  if (!themeSettings.toggle_view_button_enabled) {
    // eslint-disable-next-line no-console
    console.log(
      "[Toggle Button] Toggle button disabled in settings:",
      themeSettings.toggle_view_button_enabled
    );
    return false;
  }

  // Get the topic from outlet args
  const topic = outletArgs?.model;
  if (!topic) {
    // eslint-disable-next-line no-console
    console.log("[Toggle Button] No topic found in outlet args");
    return false;
  }

  // Check if category is configured for owner comments
  const categoryEnabled = isCategoryEnabled(topic, themeSettings);
  // eslint-disable-next-line no-console
  console.log(
    "[Toggle Button] Category check result:",
    categoryEnabled,
    "for topic category:",
    topic.category_id,
    "enabled categories:",
    themeSettings.owner_comment_categories
  );
  return categoryEnabled;
}

/**
 * Check if a topic's category is enabled for owner comments.
 * @param {Object} topic - The topic model
 * @param {Object} settings - The theme settings object
 * @returns {boolean} true if category is enabled, false otherwise
 */
function isCategoryEnabled(topic, settings) {
  if (!settings.owner_comment_categories) {
    return false;
  }

  // When list_type is 'category', Discourse provides category IDs as a pipe-separated string
  const categorySetting = settings.owner_comment_categories;

  // Parse the category IDs from the setting
  const enabledCategoryIds = categorySetting
    .split("|")
    .map((c) => parseInt(c.trim(), 10))
    .filter((c) => !isNaN(c));

  if (enabledCategoryIds.length === 0) {
    return false;
  }

  const topicCategoryId = topic.category_id;
  return enabledCategoryIds.includes(topicCategoryId);
}
