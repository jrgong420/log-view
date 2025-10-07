import { apiInitializer } from "discourse/lib/api";

/**
 * Group-based access control for theme component.
 *
 * This initializer checks if the current user belongs to the configured
 * allowed groups and adds a body class to enable/disable theme features.
 *
 * Settings used:
 * - allowed_groups: list setting with group IDs (pipe-separated)
 *
 * Access rules:
 * - If no groups are selected: enable for all users (including anonymous)
 * - If one or more groups are selected: enable only for logged-in users who are members of any selected groups
 */
export default apiInitializer("1.15.0", (api) => {
  const DEBUG = true; // Set to false to disable debug logging

  function debugLog(...args) {
    if (DEBUG) {
      // eslint-disable-next-line no-console
      console.log("[Group Access Control]", ...args);
    }
  }

  /**
   * Check if the current user is allowed to access the theme component.
   * @returns {boolean} true if user is allowed, false otherwise
   */
  function isUserAllowed() {
    const currentUser = api.getCurrentUser();

    // Extract allowed group IDs from the list setting (pipe-separated)
    const allowedGroupsSetting = settings.allowed_groups || "";
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

    const isMember = allowedGroupIds.some((allowedId) =>
      userGroupIds.includes(allowedId)
    );

    debugLog(
      `Access decision: ${isMember ? "granted" : "denied"}; user is ${
        isMember ? "" : "NOT "
      }a member of allowed groups`
    );

    return isMember;
  }

  /**
   * Apply or remove the body class based on user access.
   */
  function updateBodyClass() {
    const allowed = isUserAllowed();
    const bodyClass = "theme-component-access-granted";

    if (allowed) {
      document.body.classList.add(bodyClass);
      debugLog("Access granted; added body class:", bodyClass);
    } else {
      document.body.classList.remove(bodyClass);
      debugLog("Access denied; removed body class:", bodyClass);
    }
  }

  // Run on initial load
  updateBodyClass();

  // Re-check on page changes (for SPA navigation)
  api.onPageChange(() => {
    debugLog("Page change detected; re-checking access");
    updateBodyClass();
  });
});

