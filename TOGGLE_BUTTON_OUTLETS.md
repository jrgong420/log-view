# Toggle Button Outlet Implementation

## Overview
This document describes the implementation of the owner-filtered view toggle button using Discourse plugin outlets for better visibility across desktop and mobile devices.

## Problem
The original toggle button was placed in the `topic-footer-buttons` outlet, which only renders when users scroll close to the last posts in a topic. This caused the button to disappear when viewing earlier posts.

## Solution
We now use two different plugin outlets to ensure the toggle button is always visible:

### Desktop: `timeline-footer-controls-after`
- **Location**: In the topic timeline footer controls area (right side of desktop view)
- **Visibility**: Always visible when the timeline is present (desktop layouts)
- **Core source**: `app/assets/javascripts/discourse/app/components/topic-timeline/container.gjs`
- **GitHub**: https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/topic-timeline/container.gjs

### Mobile: `before-topic-progress`
- **Location**: Immediately before the topic progress wrapper (mobile view)
- **Visibility**: Always visible on mobile devices
- **Core source**: `app/assets/javascripts/discourse/app/templates/topic.gjs`
- **GitHub**: https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/templates/topic.gjs

## Implementation Details

### File Structure
```
javascripts/discourse/
├── components/
│   └── owner-toggle-button.gjs          # Shared toggle button component
└── api-initializers/
    ├── owner-comment-prototype.gjs      # Owner filtering logic
    └── owner-toggle-outlets.gjs         # Registers desktop & mobile outlets
```

### Shared Component: `owner-toggle-button.gjs`
A reusable Glimmer component that:
- Checks if the current view is owner-filtered
- Displays appropriate icon (toggle-on/toggle-off) and label
- Handles toggle action (add/remove username_filters query param)
- Manages opt-out state in sessionStorage
- Uses translations from `locales/en.yml`

### Outlet Initializer: `owner-toggle-outlets.gjs`

Registers two Glimmer components via `api.renderInOutlet`:

- **TimelineOwnerToggle** → `timeline-footer-controls-after`
  - Only renders on desktop (`!site.mobileView`)
  - Respects group access control and category checks via `shouldShowToggleButton`
  - Wraps the shared `OwnerToggleButton` in `.owner-toggle-wrapper--timeline`
- **MobileOwnerToggle** → `before-topic-progress`
  - Only renders on mobile (`site.mobileView`)
  - Shares the same access/category guards
  - Wraps the button in `.owner-toggle-wrapper--mobile`

Both components reuse the shared `OwnerToggleButton` and guard rendering through `static shouldRender`, aligning with the latest guidance to replace legacy connector classes.

### Styling
CSS in `common/common.scss`:
- Desktop: Aligns with timeline controls, subtle styling
- Mobile: Centered, prominent with shadow, ensures label visibility
- Common: Transition effects, filtered state styling

## Conditional Rendering Pattern
```js
static shouldRender(outletArgs, helper) {
  const owner = getOwner(helper);
  const site = owner.lookup("service:site");
  
  // Desktop: only show when NOT mobile
  return !site?.mobileView;
  
  // Mobile: only show when mobile
  // return site?.mobileView;
}
```

## Preserved Functionality
- The original `topic-footer-buttons` placement is preserved for backward compatibility
- All toggle logic remains identical (URL manipulation, sessionStorage opt-out)
- Translation keys unchanged
- Settings (`toggle_view_button_enabled`) still apply

## Testing Checklist
- [ ] Desktop: Toggle button appears in timeline footer controls
- [ ] Desktop: Button remains visible while scrolling through topic
- [ ] Desktop: Button does not appear on mobile view
- [ ] Mobile: Toggle button appears before topic progress wrapper
- [ ] Mobile: Button remains visible while scrolling
- [ ] Mobile: Button does not appear on desktop view
- [ ] Both: Clicking toggle switches between filtered/unfiltered views
- [ ] Both: Icon and label update correctly based on state
- [ ] Both: Opt-out state persists in sessionStorage
- [ ] Footer button still works (if not disabled)

## References
- Plugin Outlet Connectors Documentation: https://meta.discourse.org/t/32727
- Timeline outlets confirmed in core: https://github.com/discourse/discourse
- Discourse Glimmer Component Guide: https://guides.emberjs.com/release/components/

## Future Considerations
- Consider hiding/removing the original footer button placement
- Add theme setting to choose which outlets to use
- Add animation when toggling between states
