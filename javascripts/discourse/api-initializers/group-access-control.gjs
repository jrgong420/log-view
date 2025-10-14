import { apiInitializer } from "discourse/lib/api";
import { createLogger } from "../lib/logger";

/**
 * Group-based access control for theme component.
 *
 * This initializer checks if the current user belongs to the configured
 * allowed groups and adds a body class to enable/disable theme features.
 *
 * Settings used:
 * - allowed_groups: list setting with group IDs (pipe-separated)
 * - debug_logging_enabled: enable verbose console logging
 *
 * Access rules:
 * - If no groups are selected: enable for all users (including anonymous)
 * - If one or more groups are selected: enable only for logged-in users who are members of any selected groups
 */
export default apiInitializer("1.15.0", (api) => {
  const log = createLogger("[Owner View] [Group Access Control]");

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

    log.debug("Allowed groups setting", {
      raw: settings.allowed_groups,
      parsed: allowedGroupIds
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
    const userGroupNames = userGroups.map((g) => g.name || g.full_name || g.slug);

    log.debug("User group membership", {
      userGroupIds,
      userGroupNames,
      allowedGroupIds
    });

    const isMember = allowedGroupIds.some((allowedId) =>
      userGroupIds.includes(allowedId)
    );

    log.info("Access decision", {
      decision: isMember ? "GRANTED" : "DENIED",
      isMember,
      userGroupNames
    });

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
      log.info("Access granted; added body class", { bodyClass });
    } else {
      document.body.classList.remove(bodyClass);
      log.info("Access denied; removed body class", { bodyClass });
    }
  }

  // Run on initial load
  log.info("Initializing group access control");
  updateBodyClass();

  // Re-check on page changes (for SPA navigation)
  api.onPageChange((url) => {
    log.debug("Page change detected; re-checking access", { url });
    updateBodyClass();
  });
});

