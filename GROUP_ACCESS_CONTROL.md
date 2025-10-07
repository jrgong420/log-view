# Group-Based Access Control - Admin Guide

This document provides detailed guidance for Discourse administrators on configuring and using the group-based access control feature in the Log View theme component.

## Overview

The group-based access control feature allows you to restrict the Log View theme component's functionality to specific user groups. This is useful for:

- **Private features**: Limit journal/log view functionality to premium members or specific communities
- **Staged rollouts**: Test new features with a subset of users before enabling for everyone
- **Community segmentation**: Provide different experiences for different user groups
- **Reducing clutter**: Hide features from users who don't need them

## Quick Start

### Step 1: Configure Allowed Groups

1. Go to **Admin** > **Customize** > **Themes**
2. Select the **Log View** theme component
3. Click **Settings**
4. Scroll to **Allowed Groups**
   - Leave empty to enable for all users (unrestricted)
   - Or select one or more groups to restrict access to members
5. Click **Save**

### Step 2: Test

1. Log in as a user who is a member of the selected group(s)
2. Navigate to a topic in a configured category
3. Verify the toggle button appears
4. Log in as a user who is NOT a member of any selected group (or anonymous if groups are selected)
5. Verify the toggle button does NOT appear

## Configuration Options

### Access Rules

Access is determined solely by the "Allowed Groups" setting:

- If no groups are selected: the theme component is enabled for all users (including anonymous)
- If one or more groups are selected: only logged-in users who are members of any selected groups have access

### Allowed Groups

**Purpose**: Select which groups can access the theme component

**Configuration**:
- Type: List with group picker
- Default: Empty (no groups)
- Can select multiple groups using the native Discourse group picker

**How it works**:
- Users must be a member of **at least one** selected group (OR logic)
- Group membership is checked by group ID (not name), so renaming groups is safe
- Changes take effect on next page load/navigation

**Important**: Groups must have their visibility set to "group owners, members and moderators" or more permissive (e.g., "everyone") for the theme component to properly detect user membership. If a group's visibility is set to "group owners and moderators", regular members will not be recognized by the theme component even if they are in the group.

**Example configurations**:

1. **Single group**: Select "Premium Members" → only premium members have access
2. **Multiple groups**: Select "Premium Members" and "Beta Testers" → members of either group have access
3. **No groups selected**: Everyone has access (unrestricted)

### Behavior for Anonymous (Deprecated)

This setting is no longer used to determine access. Access now depends solely on the "Allowed Groups" setting:

- If no groups are selected: anonymous users are allowed (unrestricted)
- If one or more groups are selected: anonymous users are denied (they are not members of any group)

## Common Scenarios

### Scenario 1: Premium Members Only

**Goal**: Only show the log view feature to premium/paid members

**Configuration**:
1. Allowed Groups: Select "Premium Members"

**Result**: Only premium members see the toggle button and filtering features.

### Scenario 2: Beta Testing

**Goal**: Test the feature with a small group before public release

**Configuration**:
1. Allowed Groups: Select "Beta Testers"

**Result**: Only beta testers see the feature. When ready to release to everyone, clear the Allowed Groups selection.

### Scenario 3: Multiple Communities

**Goal**: Enable for multiple distinct communities on the same Discourse instance

**Configuration**:
1. Allowed Groups: Select "Community A", "Community B", "Community C"

**Result**: Members of any of the selected communities see the feature.

### Scenario 4: Public Preview

**Goal**: Show the feature to everyone, including anonymous users

**Configuration**:
1. Allowed Groups: Leave empty (no groups selected)

**Result**: Everyone sees the feature.

## Troubleshooting

### Users can't see the feature

**Check**:
1. Are groups configured in "Allowed Groups"? (If any groups are selected, only members have access.)
2. Is the user a member of at least one allowed group?
3. **Group visibility**: Ensure the group's visibility is set to "group owners, members and moderators" or more permissive. If set to "group owners and moderators", regular members won't be detected.
4. If no groups are selected, all users should have access — ensure settings are saved and the page is refreshed.
5. Check browser console for debug messages (look for `[Group Access Control]`).

### Staff can't see the feature

Ensure staff are members of an allowed group when groups are selected. There is no longer a staff bypass.

### Anonymous users can see the feature (but shouldn't)

If any groups are selected, anonymous users are denied. Clear Allowed Groups to enable access for all users.

### Feature appears briefly then disappears

**Possible causes**:
1. The theme is checking access on page load; this is normal
2. If it flickers on every page change, check browser console for errors
3. Ensure the theme component is properly installed and up to date

### Changes don't take effect

**Solutions**:
1. Save the theme settings
2. Refresh the page (Discourse caches theme settings)
3. Clear browser cache if needed
4. Check that the theme component is enabled for the current theme

## Security Notes

### This is NOT server-side security

**Important**: The group-based access control is implemented entirely on the client side (in the browser). This means:

- ✅ It's great for UI/UX customization
- ✅ It reduces clutter and improves user experience
- ❌ It does NOT protect sensitive data
- ❌ It does NOT enforce security policies

**Why?** A determined user can:
- View the theme's JavaScript source code
- Use browser developer tools to bypass client-side checks
- Access any data that is sent to their browser

### When to use vs. when NOT to use

**✅ Good use cases**:
- Hiding UI elements for non-members
- Customizing user experience by group
- Reducing interface clutter
- Staged feature rollouts
- A/B testing different UX patterns

**❌ Bad use cases**:
- Protecting sensitive data (use server-side permissions instead)
- Enforcing security policies (use Discourse's built-in permissions)
- Preventing access to private content (use category/topic permissions)
- Compliance requirements (use server-side controls)

### If you need real security

If you need to restrict access to data or functionality for security/compliance reasons:

1. Use Discourse's built-in category and topic permissions
2. Create or extend a server-side plugin that enforces permissions server-side
3. Only serialize/send data to users who are authorized to see it

The theme component's group access control should be used as a **UI enhancement**, not a security boundary.

## Advanced: Debugging

### Enable Debug Logging

Debug logging is enabled by default. To view logs:

1. Open browser developer console (F12)
2. Navigate to the Console tab
3. Look for messages prefixed with `[Group Access Control]`

Example log messages:
```
[Group Access Control] Allowed group IDs: []
[Group Access Control] No groups configured; enabling for all users (unrestricted access)
[Group Access Control] Access granted; added body class: theme-component-access-granted

[Group Access Control] Allowed group IDs: [41, 42, 43]
[Group Access Control] Anonymous user and groups are configured; denying access

[Group Access Control] Allowed group IDs: [41, 42, 43]
[Group Access Control] User group IDs: [41, 50]
[Group Access Control] Access decision: granted; user is a member of allowed groups
```

### Disable Debug Logging

To disable debug logging (for production):

1. Edit `javascripts/discourse/api-initializers/group-access-control.gjs`
2. Change `const DEBUG = true;` to `const DEBUG = false;`
3. Save and commit the change

### Inspect Body Class

The theme adds a body class when access is granted:

1. Open browser developer tools (F12)
2. Go to the Elements/Inspector tab
3. Find the `<body>` element
4. Check if it has the class `theme-component-access-granted`
   - Present: User has access
   - Absent: User does NOT have access

### Check shouldRender

The theme uses `shouldRender()` in connector components to prevent rendering for non-members. To verify:

1. Open browser developer tools (F12)
2. Go to the Elements/Inspector tab
3. Search for elements with class `owner-toggle-button`
   - Found: User has access (component rendered)
   - Not found: User does NOT have access (component not rendered)

## Best Practices

1. **Test thoroughly**: Always test with multiple user accounts (member, non-member, staff, anonymous)
2. **Use descriptive group names**: Make it clear what each group is for
3. **Document your configuration**: Keep notes on which groups have access and why
4. **Start restrictive**: It's easier to grant access later than to revoke it
5. **Monitor feedback**: Check with users to ensure the feature is working as expected
7. **Use for UX, not security**: Remember this is client-side gating

## Support

For issues, questions, or feature requests:
- GitHub: https://github.com/jrgong420/log-view
- Discourse Meta: (link to meta topic if available)

