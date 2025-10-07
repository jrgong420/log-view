# Hide Reply Buttons for Non-Owners

## Overview

This feature provides a UI-only mechanism to hide top-level reply buttons from non-owner users in categories configured for owner comments. It's designed to reduce visual clutter and gently encourage users to use post-level replies in journal-style topics.

## Feature Scope

### What It Does

- **Hides top-level reply buttons** for non-owners:
  - Timeline footer reply button (desktop)
  - Topic footer reply button (bottom of topic)

- **Styles post-level reply buttons** as primary actions:
  - Post-level reply buttons remain visible
  - Styled with primary action colors (using Discourse CSS variables)
  - Background: `var(--tertiary)`
  - Text: `var(--secondary)`
  - Border: `transparent`
  - Hover: `var(--tertiary-hover)` with brightness filter
  - Active: `var(--tertiary-high)` with darker brightness
  - Focus: Outline with `var(--tertiary-low)`

- **Applies only in configured categories**:
  - Only works in categories defined in "Owner Comment Categories" setting
  - Topic owner always sees all reply buttons (normal behavior)

### What It Does NOT Do

- **Does NOT prevent replies via**:
  - Keyboard shortcuts (Shift+R)
  - API calls
  - Browser console manipulation
  - Direct URL navigation to `/new-topic` or `/reply`

- **Does NOT provide server-side security**:
  - This is a client-side UI restriction only
  - Use Discourse's built-in category permissions for true access control

## Independence from Access Control

This feature is **completely independent** of the "Allowed Groups" access control feature:

- **Allowed Groups**: Controls who can see the theme component's features (toggle button, auto-filtering)
- **Hide Reply Buttons**: Controls reply button visibility based on topic ownership

Both features can be used together or separately:
- If both are enabled, a user must be in an allowed group AND be the topic owner to see reply buttons
- If only "Hide Reply Buttons" is enabled, all users see the theme features, but non-owners don't see top-level reply buttons
- If only "Allowed Groups" is enabled, group members see all features including reply buttons

## Configuration

### Setting

**Name**: `hide_reply_buttons_for_non_owners`
**Type**: Boolean
**Default**: `false`

### How to Enable

1. Navigate to **Admin** → **Customize** → **Themes** → **Log View**
2. Click **Settings**
3. Find "Hide reply buttons for non-owners"
4. Toggle to **enabled**
5. Click **Save**

### Prerequisites

- "Owner Comment Categories" must be configured
- The feature only applies in those configured categories

## Technical Implementation

### Architecture

The feature uses a body class approach for clean separation of concerns:

1. **JavaScript** (`hide-reply-buttons.gjs`):
   - Runs on every page change (`api.onPageChange`)
   - Evaluates conditions (setting enabled, category match, ownership)
   - Adds/removes `hide-reply-buttons-non-owners` body class

2. **CSS** (`common/common.scss`):
   - Scoped under `body.hide-reply-buttons-non-owners`
   - Hides top-level reply buttons with `display: none !important`
   - Styles post-level buttons with primary action colors

### Decision Logic

```
1. Is setting enabled?
   NO → Remove body class, exit
   YES → Continue

2. Is there a topic?
   NO → Remove body class, exit
   YES → Continue

3. Is topic in configured category?
   NO → Remove body class, exit
   YES → Continue

4. Is there topic owner data?
   NO → Remove body class, exit
   YES → Continue

5. Is user anonymous?
   YES → Add body class (hide buttons)
   NO → Continue

6. Is current user the topic owner?
   YES → Remove body class (show buttons)
   NO → Add body class (hide buttons)
```

### CSS Selectors

**Hidden elements** (top-level reply buttons):
```scss
.timeline-footer-controls .create
.timeline-footer-controls .reply-to-post
.topic-footer-main-buttons .create
.topic-footer-main-buttons .reply-to-post
```

**Styled elements** (post-level reply buttons):
```scss
/* More specific selectors to override core Discourse styles */
nav.post-controls .actions button.create
nav.post-controls .actions button.reply
nav.post-controls .actions button.reply-to-post
.topic-body .actions button.create
.topic-body .actions button.reply
.topic-body .actions button.reply-to-post
```

**Styling details**:
- Base: `background-color: var(--tertiary)`, `color: var(--secondary)`
- Hover: `background-color: var(--tertiary-hover)`, `filter: brightness(0.9)`
- Active: `background-color: var(--tertiary-high)`, `filter: brightness(0.85)`
- Focus: `outline: 2px solid var(--tertiary-low)`
- All with `!important` to override core styles

### Debug Logging

The feature includes comprehensive debug logging. To view:

1. Open browser console (F12)
2. Look for messages prefixed with `[Hide Reply Buttons]`
3. Logs include:
   - Setting state
   - Topic and category IDs
   - User and owner IDs
   - Ownership decision
   - Body class action

To disable logging, edit `hide-reply-buttons.gjs` and set `DEBUG = false`.

## Use Cases

### Ideal Use Cases

✅ **Journal-style topics**: Where the topic owner posts updates and others comment
✅ **Grow logs**: Where growers post progress and others provide feedback
✅ **Project logs**: Where project owners post updates and team members comment
✅ **Reducing clutter**: Simplifying the UI for non-owners while keeping flexibility

### Not Recommended For

❌ **Security**: Use Discourse category permissions instead
❌ **Strict enforcement**: Users can still reply via keyboard shortcuts
❌ **All categories**: Only works in configured "Owner Comment Categories"

## Troubleshooting

### Reply buttons still visible for non-owners

**Check**:
1. Is the setting enabled?
2. Is the topic in a configured "Owner Comment Categories"?
3. Is the current user actually a non-owner? (Check user ID vs topic owner ID in console logs)
4. Are you testing in the theme preview? (Preview may not have full topic data)

**Debug**:
- Open browser console
- Look for `[Hide Reply Buttons]` logs
- Verify the decision logic output

### Post-level buttons not styled correctly

**Check**:
1. Is the body class `hide-reply-buttons-non-owners` present? (Inspect `<body>` element)
2. Are there conflicting CSS rules from other themes/components?
3. Are Discourse CSS variables available? (Check computed styles)

**Debug**:
- Inspect the reply button element
- Check computed styles in browser dev tools
- Look for CSS rule conflicts

### Feature not working after navigation

**Check**:
- The feature uses `api.onPageChange()` which should handle SPA navigation
- Check console for errors
- Verify the initializer is loaded (look for initial debug logs)

**Debug**:
- Navigate between topics
- Watch console for `[Hide Reply Buttons]` logs on each navigation
- Verify body class changes appropriately

## Limitations (By Design)

1. **UI-only restriction**: Does not prevent replies via keyboard shortcuts, API, or console
2. **Category-scoped**: Only works in configured "Owner Comment Categories"
3. **Client-side only**: Can be bypassed by determined users
4. **No keyboard suppression**: Shift+R still opens composer (theme components cannot suppress core shortcuts)
5. **Post-level buttons visible**: By design, to allow contextual replies

## Future Enhancements (Potential)

- [ ] Add visual tooltip explaining why buttons are hidden
- [ ] Add admin setting to customize post-level button styling
- [ ] Add option to hide post-level buttons as well (if requested)
- [ ] Add option to show a "Request to Reply" button for non-owners

## Related Documentation

- [README.md](../README.md) - Main theme documentation
- [GROUP_ACCESS_CONTROL.md](GROUP_ACCESS_CONTROL.md) - Group-based access control
- [TOGGLE_BUTTON_OUTLETS.md](TOGGLE_BUTTON_OUTLETS.md) - Toggle button implementation
- [Implementation Plan](HIDE_REPLY_BUTTONS_IMPLEMENTATION_PLAN.md) - Detailed implementation plan
- [Implementation Summary](IMPLEMENTATION_SUMMARY.md) - Quick reference checklist

