import { getOwner } from "@ember/owner";
import { createLogger } from "./logger";

/**
 * Shared utility for checking group-based access control and category settings.
 * Used by connectors to gate rendering via shouldRender.
 *
 * Settings used:
 * - allowed_groups: list of group IDs (pipe-separated)
 * - owner_comment_categories: list of category IDs (pipe-separated)
 * - toggle_view_button_enabled: enable toggle button
 * - debug_logging_enabled: enable verbose console logging
 */
const log = createLogger("[Owner View] [Group Access Utils]");

/**
 * Parse category IDs from pipe-separated setting string.
 * @param {string} categorySetting - Pipe-separated category IDs
 * @returns {number[]} Array of category IDs
 */
export function parseCategoryIds(categorySetting) {
  if (!categorySetting) {
    return [];
  }

  return categorySetting
    .split("|")
    .map((id) => parseInt(id.trim(), 10))
    .filter((id) => !isNaN(id));
}


/**
 * Check if the current user is allowed to access the theme component.
 * @param {Object} helper - The helper object from shouldRender
 * @returns {boolean} true if user is allowed, false otherwise
 */
export function isUserAllowedAccess(helper, fallbackContext = null) {
  const container = resolveOwner(helper) || resolveOwner(fallbackContext);
  const cuService = container?.lookup?.("service:current-user");
  // Robust resolution: in Discourse, current-user may be the user object itself
  // or expose the user via .user / .currentUser / .current
  const currentUser = cuService && (cuService.user || cuService.currentUser || cuService.current || cuService);

  log.debug("Resolved currentUser", {
    userId: currentUser?.id,
    username: currentUser?.username
  });

  // Get theme settings from the global settings object
  // Note: In connectors, settings is available globally (not window.settings)
  const themeSettings = typeof settings !== "undefined" ? settings : {};

  // Extract allowed group IDs from the list setting (pipe-separated)
  const allowedGroupsSetting = themeSettings.allowed_groups || "";
  const allowedGroupIds = allowedGroupsSetting
    .split("|")
    .map((id) => parseInt(id.trim(), 10))
    .filter((id) => !isNaN(id));

  log.debug("Allowed groups", {
    allowedGroupIds,
    userGroups: currentUser?.groups
  });

  // If no groups are configured, enable for all users (unrestricted)
  if (allowedGroupIds.length === 0) {
    log.info("No groups configured; enabling for all users (unrestricted access)");
    return true;
  }

  // Groups are configured: anonymous users are not members of any group
  if (!currentUser) {
    log.info("Anonymous user and groups are configured; denying access");
    return false;
  }

  // Check if user belongs to any of the allowed groups
  const userGroups = currentUser.groups || [];
  const userGroupIds = userGroups.map((g) => g.id);

  // Normalize both arrays to numbers for comparison
  const normalizedAllowedIds = allowedGroupIds.map(id => Number(id));
  const normalizedUserGroupIds = userGroupIds.map(id => Number(id));

  // DETAILED DEBUG: Log each comparison
  log.debug("Detailed group comparison", {
    allowedGroupsSetting: themeSettings.allowed_groups,
    parsedAllowedIds: allowedGroupIds,
    normalizedAllowedIds,
    rawUserGroupIds: userGroupIds,
    normalizedUserGroupIds,
    userGroupsObjects: userGroups.map(g => ({ id: g.id, name: g.name, type: typeof g.id }))
  });

  const isMember = normalizedAllowedIds.some((allowedId) => {
    const found = normalizedUserGroupIds.includes(allowedId);
    log.debug(`Checking if user is in group ${allowedId}: ${found}`);
    return found;
  });

  log.info("Access decision", {
    decision: isMember ? "GRANTED" : "DENIED",
    isMember,
    allowedGroupIds: normalizedAllowedIds,
    userGroupIds: normalizedUserGroupIds,
    rawAllowedGroupIds: allowedGroupIds,
    rawUserGroupIds: userGroupIds
  });

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

  log.debug("Checking toggle button visibility", {
    toggleEnabled: themeSettings.toggle_view_button_enabled,
    hasOutletArgs: !!outletArgs
  });

  // Check if toggle button is enabled in settings
  if (!themeSettings.toggle_view_button_enabled) {
    log.debug("Toggle button disabled in settings");
    return false;
  }

  // Get the topic from outlet args
  const topic = outletArgs?.model;
  if (!topic) {
    log.debug("No topic found in outlet args");
    return false;
  }

  // Check if category is configured for owner comments
  const categoryEnabled = isCategoryEnabled(topic, themeSettings);

  log.info("Toggle button visibility decision", {
    shouldShow: categoryEnabled,
    topicCategoryId: topic.category_id,
    enabledCategories: themeSettings.owner_comment_categories
  });

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
