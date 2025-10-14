# Log View

A Discourse theme component that automatically filters topics in configured categories to show only the topic owner's posts, creating a journal or comments view.

## Features

- **Owner-only filtering**: Automatically filters topics to show only posts by the topic owner
- **Category-based configuration**: Enable filtering for specific categories
- **Toggle button**: Users can switch between filtered and unfiltered views
- **Mobile & Desktop support**: Works seamlessly on both mobile and desktop layouts
- **Group-based access control**: Restrict theme component functionality to specific user groups
- **Reply button hiding**: Hide top-level reply buttons from non-owners in configured categories (UI-only restriction)
- **Embedded reply buttons**: Reply to embedded posts directly from filtered view without losing context

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

#### Hide Reply Buttons for Non-Owners
**Type**: Boolean
**Default**: false

When enabled, hides reply buttons on posts authored by non-owners in categories configured for owner comments. This applies in **both filtered and regular topic views**.

**Behavior**:
- Posts authored by the topic owner: reply buttons remain visible
- Posts authored by other users: reply buttons are hidden
- Applies only in categories configured in "Owner Comment Categories"
- Does not check the "Allowed Groups" setting (applies regardless of group membership)

**Important limitations**:
- This is a **UI-only restriction** and does not prevent replies via:
  - Keyboard shortcuts (Shift+R)
  - API calls
  - Browser console manipulation
- For true access control, use Discourse's built-in category permissions

**Use case**: In journal-style topics, encourage users to reply to the topic owner's posts while reducing clutter from reply buttons on other users' posts.

#### Embedded Reply Buttons
**Type**: Boolean (automatically enabled)
**Default**: true

When in filtered view (owner comment mode), reply buttons are automatically added to embedded posts (posts from other users shown in `section.embedded-posts`). These buttons allow users to reply to embedded posts without leaving the filtered view.

**Features**:
- Reply buttons appear on all embedded posts in filtered view
- Clicking a button opens the Discourse composer with correct reply context
- User remains on the filtered view page (no navigation)
- Filtered view is maintained after posting the reply
- Comprehensive console logging for debugging

**Technical details**:
- Uses Discourse Plugin API v1.14.0+
- Event delegation for SPA compatibility
- Opens composer via `service:composer` with `skipJumpOnSave: true`
- See `docs/EMBEDDED_REPLY_BUTTONS_IMPLEMENTATION.md` for full technical documentation
- See `docs/EMBEDDED_REPLY_BUTTONS_TESTING.md` for testing procedures

### Group-Based Access Control

The theme component includes optional group-based access control to restrict functionality to specific user groups.


#### Allowed Groups
**Type**: Objects (group picker)
**Default**: Empty

How it works:
- If no groups are selected: everyone (including anonymous) can access the theme component
- If one or more groups are selected: only logged-in users who are members of any selected groups can access

**How to configure**:
1. Click "Add Item" under "Allowed Groups"
2. Select one or more groups from the group picker (or leave empty for unrestricted access)
3. Save your changes

**Important**: Groups must have their visibility set to "group owners, members and moderators" or more permissive for the theme to detect user membership. If a group's visibility is "group owners and moderators", regular members will not be recognized.

#### Behavior for Anonymous (Deprecated)
This setting is no longer used to determine access. Access now depends solely on the "Allowed Groups" setting.
- If no groups are selected: anonymous users are allowed (unrestricted)
- If one or more groups are selected: anonymous users are denied

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
If no groups are selected in "Allowed Groups", the theme will enable access for everyone (including anonymous).

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
│       │   ├── embedded-reply-buttons.gjs  # Embedded reply buttons feature
│       │   ├── group-access-control.gjs    # Group access control logic
│       │   ├── hide-reply-buttons.gjs      # Reply button hiding logic
│       │   ├── log-view.gjs                # Main initializer (placeholder)
│       │   ├── owner-comment-prototype.gjs # Owner filtering logic
│       │   └── owner-toggle-outlets.gjs    # Registers toggle button outlets
│       ├── components/
│       │   └── owner-toggle-button.gjs     # Toggle button component
│       └── lib/
│           └── group-access-utils.js       # Shared utilities (access check, category parsing)
├── common/
│   └── common.scss                    # Shared styles
└── docs/
    ├── EMBEDDED_REPLY_BUTTONS_IMPLEMENTATION.md  # Technical documentation
    └── EMBEDDED_REPLY_BUTTONS_TESTING.md         # Testing guide
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

The theme includes a configurable logging system with different verbosity levels:

**Default Mode (Production):**
- Shows only important events, warnings, and errors (~35 messages per interaction)
- Suitable for production use and general debugging

**Debug Mode (Development):**
- Shows verbose debugging information (~150 messages per interaction)
- Useful for detailed troubleshooting and development

**To enable debug mode:**
1. Edit `javascripts/discourse/api-initializers/embedded-reply-buttons.gjs`
2. Change `const DEBUG = false;` to `const DEBUG = true;`
3. Save and refresh

**Viewing logs:**
1. Open your browser's developer console (F12)
2. Look for messages prefixed with:
   - `[Embedded Reply Buttons]` - Embedded reply button injection and composer opening
   - `[Group Access Control]` - Group membership checks
   - `[Owner Comments]` - Owner filtering logic
   - `[Hide Reply Buttons]` - Reply button hiding decisions

**Tip**: Filter console output by feature name (e.g., `[Embedded Reply Buttons]`) to focus on specific functionality.

For detailed information about the logging system, see [docs/LOGGING_GUIDE.md](docs/LOGGING_GUIDE.md).

## License

See [LICENSE](LICENSE) file.

## Support

For issues, questions, or contributions, please visit the [GitHub repository](https://github.com/jrgong420/log-view).
