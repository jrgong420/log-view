/**
 * Shared utility for checking group-based access control and category settings.
 * Used by connectors to gate rendering via shouldRender.
 */

/**
 * Check if the current user is allowed to access the theme component.
 * @param {Object} helper - The helper object from shouldRender
 * @returns {boolean} true if user is allowed, false otherwise
 */
export function isUserAllowedAccess(helper) {
  const owner = helper.owner || helper;
  const currentUser = owner.lookup("service:current-user")?.user;

  // Get theme settings from the global settings object
  // Note: In connectors, we need to access settings differently
  // The settings object is available globally in theme components
  const themeSettings = window.settings || {};

  // If group access control is disabled, allow everyone
  if (!themeSettings.group_access_enabled) {
    return true;
  }

  // Handle anonymous users
  if (!currentUser) {
    return themeSettings.behavior_for_anonymous === "allow";
  }

  // Check staff override
  if (themeSettings.include_staff && currentUser.staff) {
    return true;
  }

  // Extract allowed group IDs from the objects setting
  const allowedGroupIds = (themeSettings.allowed_groups || [])
    .flatMap((rule) => rule.groups || [])
    .filter(Boolean);

  // If no groups are configured, deny by default (safe default)
  if (allowedGroupIds.length === 0) {
    return false;
  }

  // Check if user belongs to any of the allowed groups
  const userGroups = currentUser.groups || [];
  const userGroupIds = userGroups.map((g) => g.id);

  return allowedGroupIds.some((allowedId) => userGroupIds.includes(allowedId));
}

/**
 * Check if the toggle button should be shown based on settings and category.
 * @param {Object} outletArgs - The outlet arguments containing the topic model
 * @returns {boolean} true if toggle button should be shown, false otherwise
 */
export function shouldShowToggleButton(outletArgs) {
  const themeSettings = window.settings || {};

  // Check if toggle button is enabled in settings
  if (!themeSettings.toggle_view_button_enabled) {
    return false;
  }

  // Get the topic from outlet args
  const topic = outletArgs?.model;
  if (!topic) {
    return false;
  }

  // Check if category is configured for owner comments
  return isCategoryEnabled(topic, themeSettings);
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

