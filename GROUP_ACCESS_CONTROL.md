# Group-Based Access Control - Admin Guide

This document provides detailed guidance for Discourse administrators on configuring and using the group-based access control feature in the Log View theme component.

## Overview

The group-based access control feature allows you to restrict the Log View theme component's functionality to specific user groups. This is useful for:

- **Private features**: Limit journal/log view functionality to premium members or specific communities
- **Staged rollouts**: Test new features with a subset of users before enabling for everyone
- **Community segmentation**: Provide different experiences for different user groups
- **Reducing clutter**: Hide features from users who don't need them

## Quick Start

### Step 1: Enable Group Access Control

1. Go to **Admin** > **Customize** > **Themes**
2. Select the **Log View** theme component
3. Click **Settings**
4. Find **Group Access Enabled** and toggle it to **ON**

### Step 2: Configure Allowed Groups

1. Scroll to **Allowed Groups** setting
2. Use the group picker to select one or more groups
3. Click **Save**

### Step 3: Test

1. Log in as a user who is a member of the selected group(s)
2. Navigate to a topic in a configured category
3. Verify the toggle button appears
4. Log in as a user who is NOT a member of any selected group
5. Verify the toggle button does NOT appear

## Configuration Options

### Group Access Enabled

**Purpose**: Master switch for group-based access control

**Options**:
- `false` (default): All users can access the theme component
- `true`: Only users in allowed groups (and optionally staff) can access

**When to use**:
- Enable when you want to restrict access to specific groups
- Disable for public/community-wide features

### Include Staff

**Purpose**: Allow staff members to bypass group restrictions

**Options**:
- `true` (default): Staff (admins and moderators) always have access
- `false`: Staff must be in an allowed group to have access

**When to use**:
- Keep enabled (default) for easier administration and testing
- Disable if you want strict group-only access (rare)

**Note**: "Staff" includes both administrators and moderators. If you need finer control, use the allowed groups setting instead.

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

**Example configurations**:

1. **Single group**: Select "Premium Members" → only premium members have access
2. **Multiple groups**: Select "Premium Members" and "Beta Testers" → members of either group have access
3. **No groups**: If enabled but no groups selected → only staff have access (if include_staff is true), otherwise nobody

### Behavior for Anonymous

**Purpose**: Control access for logged-out users

**Options**:
- `deny` (default): Hide theme component from anonymous users
- `allow`: Show theme component to anonymous users

**When to use**:
- `deny`: For member-only features, private communities
- `allow`: For public features, when you want to showcase functionality to visitors

**Note**: This setting only applies when group access control is enabled. If group access control is disabled, anonymous users always see the theme component.

## Common Scenarios

### Scenario 1: Premium Members Only

**Goal**: Only show the log view feature to premium/paid members

**Configuration**:
1. Group Access Enabled: `true`
2. Include Staff: `true` (so admins can test)
3. Allowed Groups: Select "Premium Members"
4. Behavior for Anonymous: `deny`

**Result**: Only premium members and staff see the toggle button and filtering features.

### Scenario 2: Beta Testing

**Goal**: Test the feature with a small group before public release

**Configuration**:
1. Group Access Enabled: `true`
2. Include Staff: `true`
3. Allowed Groups: Select "Beta Testers"
4. Behavior for Anonymous: `deny`

**Result**: Only beta testers and staff see the feature. Once testing is complete, disable group access control to release to everyone.

### Scenario 3: Multiple Communities

**Goal**: Enable for multiple distinct communities on the same Discourse instance

**Configuration**:
1. Group Access Enabled: `true`
2. Include Staff: `true`
3. Allowed Groups: Select "Community A", "Community B", "Community C"
4. Behavior for Anonymous: `deny`

**Result**: Members of any of the three communities see the feature.

### Scenario 4: Public Preview

**Goal**: Show the feature to everyone, including anonymous users

**Configuration**:
1. Group Access Enabled: `false`

**Result**: Everyone sees the feature. (No need to configure other group settings.)

Alternatively, if you want to use group settings for other purposes:
1. Group Access Enabled: `true`
2. Allowed Groups: Select all relevant groups
3. Behavior for Anonymous: `allow`

## Troubleshooting

### Users can't see the feature

**Check**:
1. Is "Group Access Enabled" turned on?
2. Are groups configured in "Allowed Groups"?
3. Is the user a member of at least one allowed group?
4. If the user is not in a group, is "Include Staff" enabled and are they staff?
5. Check browser console for debug messages (look for `[Group Access Control]`)

### Staff can't see the feature

**Check**:
1. Is "Include Staff" enabled?
2. If "Include Staff" is disabled, are staff members in an allowed group?

### Anonymous users can see the feature (but shouldn't)

**Check**:
1. Is "Behavior for Anonymous" set to `deny`?
2. Is "Group Access Enabled" turned on?

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
[Group Access Control] Group access control disabled; allowing all users
[Group Access Control] Anonymous user; behavior_for_anonymous=deny; allowed=false
[Group Access Control] User is staff and include_staff is enabled; allowing access
[Group Access Control] Allowed group IDs: [41, 42, 43]
[Group Access Control] User group IDs: [41, 50]
[Group Access Control] User is a member of allowed groups
[Group Access Control] Access granted; added body class: theme-component-access-granted
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
6. **Keep staff access enabled**: Makes administration and troubleshooting easier
7. **Use for UX, not security**: Remember this is client-side gating

## Support

For issues, questions, or feature requests:
- GitHub: https://github.com/jrgong420/log-view
- Discourse Meta: (link to meta topic if available)

