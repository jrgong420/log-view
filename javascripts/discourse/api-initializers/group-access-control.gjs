import { apiInitializer } from "discourse/lib/api";

/**
 * Group-based access control for theme component.
 *
 * This initializer checks if the current user belongs to the configured
 * allowed groups and adds a body class to enable/disable theme features.
 *
 * Settings used:
 * - group_access_enabled: master switch for group gating
 * - include_staff: allow staff regardless of group membership
 * - allowed_groups: list setting with group IDs (pipe-separated)
 * - behavior_for_anonymous: "deny" or "allow" for logged-out users
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
    // If group access control is disabled, allow everyone
    if (!settings.group_access_enabled) {
      debugLog("Group access control disabled; allowing all users");
      return true;
    }

    const currentUser = api.getCurrentUser();

    // Handle anonymous users
    if (!currentUser) {
      const allowAnon = settings.behavior_for_anonymous === "allow";
      debugLog(
        `Anonymous user; behavior_for_anonymous=${settings.behavior_for_anonymous}; allowed=${allowAnon}`
      );
      return allowAnon;
    }

    // Check staff override
    if (settings.include_staff && currentUser.staff) {
      debugLog("User is staff and include_staff is enabled; allowing access");
      return true;
    }

    // Extract allowed group IDs from the list setting (pipe-separated)
    const allowedGroupsSetting = settings.allowed_groups || "";
    const allowedGroupIds = allowedGroupsSetting
      .split("|")
      .map((id) => parseInt(id.trim(), 10))
      .filter((id) => !isNaN(id));

    debugLog("Allowed group IDs:", allowedGroupIds);

    // If no groups are configured, deny by default (safe default)
    if (allowedGroupIds.length === 0) {
      debugLog("No groups configured; denying access by default");
      return false;
    }

    // Check if user belongs to any of the allowed groups
    const userGroups = currentUser.groups || [];
    const userGroupIds = userGroups.map((g) => g.id);

    debugLog("User group IDs:", userGroupIds);

    const isMember = allowedGroupIds.some((allowedId) =>
      userGroupIds.includes(allowedId)
    );

    debugLog(`User is ${isMember ? "" : "NOT "}a member of allowed groups`);

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

