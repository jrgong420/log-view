# Allowed Groups Rework – Analysis and Implementation Plan

## Summary
The current theme component implements group-based access gating using multiple settings: `group_access_enabled` (master toggle), `include_staff` (staff bypass), `allowed_groups` (group list), and `behavior_for_anonymous`.

Per the new requirements:
- Remove deprecated settings: `include_staff` and `group_access_enabled` (and all associated logic)
- Change Allowed Groups behavior:
  - If no groups are selected: enable for all users (including anonymous)
  - If one or more groups are selected: enable only for users who are members of any selected groups
- Improve logging around access checks (granted/denied, groups considered, user groups)

## Findings (Current State)
- settings.yml:
  - `group_access_enabled` (bool, default false)
  - `include_staff` (bool, default true)
  - `allowed_groups` (list_type: group, pipe-separated IDs)
  - `behavior_for_anonymous` (enum deny|allow)
- Client JS (gating):
  - `javascripts/discourse/api-initializers/group-access-control.gjs`
    - Applies `theme-component-access-granted` body class based on `isUserAllowed()`
    - Uses `group_access_enabled`, `include_staff`, `allowed_groups`, and `behavior_for_anonymous`
    - Has a `DEBUG` flag with console logging
  - `javascripts/discourse/lib/group-access-utils.js`
    - `isUserAllowedAccess()` shared by connectors
    - Similar logic and no structured logging (only returns booleans)
- Docs:
  - `GROUP_ACCESS_CONTROL.md` and `README.md` reference the soon-to-be-deprecated settings

## Design Decisions
- Remove `group_access_enabled` and `include_staff` from settings.yml and code paths.
- Define gating exclusively by `allowed_groups`:
  - If `allowed_groups` is empty: allow everyone (unrestricted, including anonymous)
  - If `allowed_groups` is non-empty: allow only logged-in users who are members of any selected group; anonymous users are denied (since they are not in any group)
- Keep `behavior_for_anonymous` setting in settings.yml for backward compatibility, but it will no longer affect gating. We will annotate it as deprecated/no-op in docs to avoid breaking admin UIs unexpectedly; behavior is now fully defined by `allowed_groups` emptiness.
- Logging improvements:
  - Standardize log prefix to `[Group Access Control]`
  - Log: allowed group IDs, current user group IDs, whether anonymous, and the final decision (granted/denied) with reason
  - Preserve the existing `DEBUG` guard to keep logs off in production by default if needed (we can default to true during development and recommend false in docs)

## Implementation Steps
1. settings.yml
   - Remove keys: `group_access_enabled`, `include_staff`
   - Keep `allowed_groups` unchanged (type: list, list_type: group)
   - Keep `behavior_for_anonymous` present for compatibility, but add a note in the description: "Deprecated: no longer used; access now depends solely on Allowed groups (empty = everyone)."

2. Client JS
   - Update `javascripts/discourse/api-initializers/group-access-control.gjs`:
     - Simplify `isUserAllowed()` to:
       - Parse `allowed_groups`
       - If empty => allow and log reason
       - If user is not logged in => deny and log reason
       - Else check membership by group ID (OR logic). Allow if member; deny otherwise
     - Remove all branches referencing `group_access_enabled`, `include_staff`, and `behavior_for_anonymous`
     - Keep/improve logging: decision and inputs
   - Update `javascripts/discourse/lib/group-access-utils.js` similarly for `isUserAllowedAccess()` and add logs (guarded by the same `DEBUG` pattern or via a small internal `debugLog` helper).

3. Documentation
   - Update `GROUP_ACCESS_CONTROL.md`:
     - Remove sections describing `Group Access Enabled` and `Include Staff`
     - Document new gating rules and examples
     - Add a deprecation note for `behavior_for_anonymous` (no-op now)
     - Update troubleshooting guidance reflecting the new logic
   - Update `README.md` settings section accordingly

4. Backward Compatibility & Migration Notes
   - Instances that previously relied on `group_access_enabled=false` will experience the same effect by leaving `allowed_groups` empty (component enabled for everyone)
   - Instances that relied on staff bypass (`include_staff`) should add staff to an allowed group to maintain access when restricting
   - Instances that allowed anonymous users while groups were selected via `behavior_for_anonymous=allow` will now deny anonymous (by design per new requirements). Call out explicitly in docs as a behavior change
   - Keeping `behavior_for_anonymous` setting in UI but marking it deprecated avoids breaking admin forms; it will be ignored by logic

5. Test Plan
   - Matrix
     - allowed_groups = empty
       - anonymous: allowed
       - logged-in (any): allowed
     - allowed_groups = [G]
       - anonymous: denied
       - logged-in, member of G: allowed
       - logged-in, not member of G: denied
   - Verify body class `theme-component-access-granted` presence/absence matches decisions
   - Verify connectors using `isUserAllowedAccess()` render appropriately
   - Verify logs (when DEBUG enabled) show inputs and decision

6. Rollout
   - Ship with updated docs
   - Recommend site owners review whether staff should be added to an allowed group if they need access when restricting

## Risks
- Behavior change for communities that previously set `behavior_for_anonymous=allow` while restricting by group. Mitigation: document clearly and provide workaround (do not select groups if the feature should be public).

## Files to Change
- settings.yml
- javascripts/discourse/api-initializers/group-access-control.gjs
- javascripts/discourse/lib/group-access-utils.js
- README.md
- GROUP_ACCESS_CONTROL.md

