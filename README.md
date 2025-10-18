# Owner Comments (Discourse Theme Component)

Short, focused "owner-only" view for topics in selected categories. This component filters a topic to show only the topic owner's posts (journal/log view), optionally hides reply buttons for non-owners, and adds embedded reply buttons so users can reply to posts inside the owner's embedded replies without leaving the filtered view.

## What it does
- Owner-only filtering for configured categories (journal/log style)
- Toggle to switch between filtered and full views
- Optional UI-only hiding of reply buttons when viewer is not the topic owner
- Embedded reply buttons in filtered view for replying to posts inside `section.embedded-posts`
- Optional group-based access gating for the component's UI
- Works on desktop and mobile; SPA-aware

## Compatibility
- Discourse minimum version: 3.1.0 (from about.json)
- Discourse maximum version: not set
- Tested with latest stable Discourse at time of writing; please report regressions

## Installation
1. In Discourse Admin, go to Customize -> Themes
2. Install -> From a Git repository
3. Repository URL: `https://github.com/jrgong420/log-view.git`
4. Install and add the component to your active theme

## Configuration (Settings)
- Owner Comment Categories: categories where owner-only filtering applies (the toggle only appears here)
- Auto Mode: automatically enable the filtered view in those categories
- Toggle View Button Enabled: show the toggle to switch views
- Hide Reply Buttons for Non-Owners: UI-only; hides post-level and top-level reply buttons when viewer is not the topic owner in configured categories. Independent of Allowed Groups.
- Allowed Groups: optionally limit the component's UI to members of selected groups (empty = everyone, including anonymous)
- Debug Logging Enabled: show detailed console logs for troubleshooting

## How to use
- Configure "Owner Comment Categories" in admin -> customize -> theme settings
- (Optional) Enable Auto Mode so topics open in owner-only view by default
- Use the toggle to switch filtered/full view in eligible topics
- In filtered view, use the embedded reply button inside the owner's embedded replies to reply in context; the page stays in filtered view

## Limitations (important)
- Reply-button hiding is UI-only and does not hard-block replies via keyboard shortcuts (Shift+R), API, or browser console. Use category permissions for real enforcement.
- Allowed Groups affects the component's UI visibility, not Discourse data access.
- The "Hide Reply Buttons for Non-Owners" feature does NOT check group membership. It only checks: (1) the setting is enabled, (2) topic is in a configured category, and (3) whether the viewer is the topic owner.

## Known pitfalls and tips
- Group visibility: if a group's visibility is "group owners and moderators", regular members may not be detectable; use "group owners, members and moderators" or more permissive.
- Toggle appears only in configured categories by design.
- SPA navigation: Discourse is a single-page app; the component listens to page changes. If something looks stale, hard-refresh your browser.
- Theme/plugin conflicts: other customizations to composer, topic footer, or embedded posts may interfere. Look for these CSS/DOM hooks:
  - Body classes: `owner-comments-enabled`, `hide-reply-buttons-non-owners`
  - Post classes: `owner-post`, `non-owner-post`
- Mobile vs desktop: the toggle is rendered in different outlets; check both views during QA.

## Debugging
- Enable "Debug Logging Enabled" in theme settings
- Open your browser console and filter by prefixes like:
  - `[Owner View] [Hide Reply Buttons]`
  - `[Owner View] [Embedded Reply Buttons]`
  - `[Owner View]` (broad)
- For step-by-step guidance on reply-button hiding, see: docs/REPLY_BUTTON_HIDING_DEBUG_GUIDE.md
- For QA tips and recent fixes, see:
  - docs/MANUAL_QA_GUIDE.md
  - docs/BUG_FIX_GROUP_ACCESS_AND_REPLY_BUTTONS.md
  - docs/FIX_CATEGORY_SCOPING_SUMMARY.md

## License and Support
- License: see LICENSE
- Issues and contributions: https://github.com/jrgong420/log-view

