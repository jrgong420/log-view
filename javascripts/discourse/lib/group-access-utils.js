/**
 * Shared utility for checking group-based access control.
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

