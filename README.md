# Log View

A Discourse theme component that automatically filters topics in configured categories to show only the topic owner's posts, creating a journal or comments view.

## Features

- **Owner-only filtering**: Automatically filters topics to show only posts by the topic owner
- **Category-based configuration**: Enable filtering for specific categories
- **Toggle button**: Users can switch between filtered and unfiltered views
- **Mobile & Desktop support**: Works seamlessly on both mobile and desktop layouts
- **Group-based access control**: Restrict theme component functionality to specific user groups

## Installation

1. Go to your Discourse Admin panel
2. Navigate to **Customize** > **Themes**
3. Click **Install** > **From a Git repository**
4. Enter the repository URL: `https://github.com/jrgong420/log-view.git`
5. Click **Install**

## Configuration

### Basic Settings

#### Owner Comment Categories
Select the categories where topics will automatically filter to show only the topic owner's posts. **The toggle button will only appear in these configured categories.**

#### Auto Mode
When enabled, the owner-only filtered view is automatically applied in enabled categories. Users can still toggle back to the unfiltered view.

#### Toggle View Button
Enable or disable the toggle button that allows users to switch between filtered and unfiltered views. **Note**: The toggle button will only appear in categories configured in "Owner Comment Categories", even when this setting is enabled.

### Group-Based Access Control

The theme component includes optional group-based access control to restrict functionality to specific user groups.

#### Group Access Enabled
**Type**: Boolean
**Default**: `false`

Master switch to enable group-based access control. When disabled, all users can access the theme component features.

#### Include Staff
**Type**: Boolean
**Default**: `true`

When enabled, staff members (admins and moderators) can always access the theme component regardless of group membership. This is useful for testing and administration.

#### Allowed Groups
**Type**: Objects (with groups property)
**Default**: Empty

Select one or more groups that are allowed to access this theme component. Users must be members of at least one selected group to see the component's features.

**How to configure**:
1. Enable "Group Access Enabled"
2. Click "Add Item" under "Allowed Groups"
3. Select one or more groups from the group picker
4. Save your changes

#### Behavior for Anonymous
**Type**: Enum (`deny` or `allow`)
**Default**: `deny`

Choose how to handle anonymous (logged-out) users:
- **deny**: Hide the theme component from logged-out users
- **allow**: Show the theme component to logged-out users

## How Group Access Control Works

### Client-Side Gating
The group access control is implemented entirely on the client side using Discourse's theme component APIs:

1. **Settings Check**: The theme reads the configured allowed groups and categories from theme settings
2. **Category Check**: The toggle button only appears in topics within configured "Owner Comment Categories"
3. **User Check**: On page load and navigation, the theme checks if the current user belongs to any allowed group
4. **Rendering Control**:
   - Plugin outlet connectors use `shouldRender()` to prevent rendering for non-members or in unconfigured categories
   - A body class (`theme-component-access-granted`) is added/removed based on access
   - CSS rules hide features when the body class is absent (fallback)

### Security Considerations

**Important**: This is client-side UI gating, not server-side security.

- ✅ **Use for**: Hiding UI elements, customizing user experience, reducing clutter
- ❌ **Do NOT use for**: Protecting sensitive data, enforcing security policies

**Why?** Theme components run entirely in the browser. A determined user can:
- View the theme's source code
- Bypass client-side checks using browser dev tools
- Access any data that is sent to their browser

**If you need real security**: Create or extend a server-side plugin that enforces permissions server-side and only serializes data for authorized users.

### Edge Cases and Behavior

#### No Groups Configured
If "Group Access Enabled" is `true` but no groups are selected in "Allowed Groups", the theme will **deny access by default** (safe default). Staff will still have access if "Include Staff" is enabled.

#### Group Changes
- The theme checks group membership by group ID (not name), so renaming groups won't break access control
- If a user is removed from all allowed groups, they will lose access on their next page load or navigation
- If a user is added to an allowed group, they will gain access on their next page load or navigation

#### SPA Navigation
The theme re-checks access on every page change (Discourse is a Single Page Application), so access changes take effect immediately without requiring a full page reload.

#### Mobile vs Desktop
The theme works on both mobile and desktop views. The toggle button appears in different locations:
- **Desktop**: In the timeline footer controls
- **Mobile**: Before the topic progress wrapper

#### Theme Preview
In the Discourse theme preview UI, the current user may be null. The theme handles this gracefully by checking the "Behavior for Anonymous" setting.

## Development

### File Structure

```
log-view/
├── about.json                          # Theme metadata
├── settings.yml                        # Theme settings
├── locales/
│   └── en.yml                         # English translations
├── javascripts/
│   └── discourse/
│       ├── api-initializers/
│       │   ├── group-access-control.gjs    # Group access control logic
│       │   ├── log-view.gjs                # Main initializer (placeholder)
│       │   ├── owner-comment-prototype.gjs # Owner filtering logic
│       │   └── owner-toggle-outlets.gjs    # Registers toggle button outlets
│       ├── components/
│       │   └── owner-toggle-button.gjs     # Toggle button component
│       └── lib/
│           └── group-access-utils.js       # Shared access check utility
└── common/
    └── common.scss                    # Shared styles
```

### Testing Checklist

When testing group-based access control:

- [ ] Create a test group and add/remove test users
- [ ] Verify features are visible for group members
- [ ] Verify features are hidden for non-members
- [ ] Test staff override (if enabled)
- [ ] Test anonymous user behavior (both deny and allow)
- [ ] Test SPA navigation (navigate between topics/pages)
- [ ] Verify no restricted DOM elements are rendered for non-members (use browser dev tools)
- [ ] Test on both mobile and desktop views
- [ ] Test with no groups configured (should deny by default)
- [ ] Test with multiple groups configured

### Debug Logging

Both the group access control and owner filtering logic include debug logging. To view logs:

1. Open your browser's developer console (F12)
2. Look for messages prefixed with `[Group Access Control]` or `[Owner Comments]`
3. To disable debug logging, edit the initializer files and set `DEBUG = false`

## License

See [LICENSE](LICENSE) file.

## Support

For issues, questions, or contributions, please visit the [GitHub repository](https://github.com/jrgong420/log-view).
