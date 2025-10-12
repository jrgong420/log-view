# Section-Level Reply Button Implementation

## Overview

Modified the embedded reply button injection to display **one button per embedded post section** instead of one button per individual embedded post. The button is now positioned next to the collapse button at the bottom of the section.

## Changes Made

### 1. JavaScript Changes (`javascripts/discourse/api-initializers/embedded-reply-buttons.gjs`)

#### Added Helper Function
- **`getOwnerPostFromSection(section)`**: Returns the owner post (article.topic-post) that contains the embedded section

#### Modified `injectEmbeddedReplyButtons(section)`
**Before**: Injected a button for each embedded post item within the section
**After**: Injects a single button at the section level

Key changes:
- Checks if section already has a button (idempotent)
- Finds the collapse button using selectors: `.widget-button.collapse-up`, `button.collapse-up`, `.collapse-embedded-posts`
- Creates a single reply button with:
  - Class: `btn btn-small embedded-reply-button`
  - Title: "Reply to owner's post"
  - Aria-label: "Reply to owner's post"
  - Data attribute: `data-owner-post-number` (stores the owner post number)
- Positions button as a sibling **before** the collapse button
- Fallback: Appends to section if collapse button not found
- Marks section with `data-reply-btn-bound="1"` to prevent duplicates
- Returns `{ injected: 1, reason: "success" }` or `{ injected: 0, reason: "already-bound" }`

#### Modified Click Handler
**Before**: Extracted post number from the clicked embedded post item
**After**: Extracts owner post number from button's `data-owner-post-number` attribute

Key changes:
- Simplified logic - no need to traverse DOM to find embedded post
- Replies directly to the owner's post (the post containing the embedded section)
- Maintains same composer opening logic and auto-refresh context storage

#### Updated Observer Functions
All observer functions now:
- Check the return value from `injectEmbeddedReplyButtons()`
- Handle `reason: "success"` and `reason: "already-bound"` appropriately
- Only set up child observers if injection didn't succeed
- Include enhanced logging for debugging

#### Enhanced Logging
Added console logs throughout:
- Section detection
- Button injection success/failure
- Collapse button presence
- Owner post number storage
- Click events
- Page load injection counts

### 2. CSS Changes (`common/common.scss`)

#### Updated `.embedded-reply-button` Styles
- Changed `margin-left: 0.5rem` to `margin-right: 0.5rem` (positioned before collapse button)
- Added `display: inline-flex` for better alignment
- Added `align-items: center` and `vertical-align: middle`

#### Updated Section Layout
- Removed per-item styling (`.embedded-post` rules)
- Added section footer layout rules to ensure buttons are inline:
  ```scss
  section.embedded-posts {
    > footer,
    > .embedded-posts-footer,
    > .embedded-posts__footer {
      display: flex;
      align-items: center;
      gap: 0.5rem;
    }
  }
  ```

## Behavior Changes

### Before
- Multiple "Reply" buttons appeared throughout the embedded section
- Each button was attached to an individual embedded post
- Clicking a button replied to that specific embedded post

### After
- **One** "Reply" button appears per embedded section
- Button is positioned next to the collapse button at the bottom
- Clicking the button replies to the **owner's post** (the post that contains the embedded section)

## Technical Details

### Button Positioning Strategy
1. **Primary**: Insert before collapse button using `insertBefore(btn, collapseButton)`
2. **Fallback**: Append to section if collapse button not found

### Collapse Button Selectors
The code searches for collapse buttons using these selectors:
- `.widget-button.collapse-up`
- `button.collapse-up`
- `.collapse-embedded-posts`

### Owner Post Resolution
1. Find section's closest `article.topic-post` ancestor
2. Extract post number using `extractPostNumberFromElement()`
3. Store on button as `data-owner-post-number`
4. Use this number when opening composer

### Auto-Refresh Integration
The auto-refresh functionality (after posting a reply) remains intact:
- `lastReplyContext` stores `{ topicId, parentPostNumber, ownerPostNumber }`
- After posting, the system finds the owner post and clicks "load more replies"
- This refreshes the embedded section to show the new reply

## Testing Checklist

- [ ] Verify only one button appears per embedded section
- [ ] Verify button is positioned next to collapse button
- [ ] Verify button has correct styling and spacing
- [ ] Verify clicking button opens composer
- [ ] Verify composer is set to reply to owner's post
- [ ] Verify auto-refresh works after posting
- [ ] Verify no duplicate buttons on re-expand
- [ ] Verify works with "Load more replies" pagination
- [ ] Verify works after page navigation
- [ ] Check console logs for proper injection flow

## Console Log Examples

### Successful Injection
```
[Embedded Reply Buttons] Show replies button clicked for post #1
[Embedded Reply Buttons] Embedded section already exists, attempting injection
[Embedded Reply Buttons] Storing owner post number 1 on button
[Embedded Reply Buttons] Injected reply button next to collapse button
```

### Button Click
```
[Embedded Reply Buttons] Section-level reply button clicked
[Embedded Reply Buttons] Replying to owner post #1
[Embedded Reply Buttons] AutoRefresh: stored lastReplyContext
[Embedded Reply Buttons] Composer opened successfully
```

### Page Load
```
[Embedded Reply Buttons] Found 2 embedded section(s), injecting buttons
[Embedded Reply Buttons] Storing owner post number 1 on button
[Embedded Reply Buttons] Injected reply button next to collapse button
[Embedded Reply Buttons] Storing owner post number 5 on button
[Embedded Reply Buttons] Injected reply button next to collapse button
[Embedded Reply Buttons] Injected 2 button(s) on page load
```

## Files Modified

1. `javascripts/discourse/api-initializers/embedded-reply-buttons.gjs`
2. `common/common.scss`

## Backward Compatibility

- No breaking changes to existing functionality
- Auto-refresh feature continues to work
- All observer patterns remain functional
- Click handlers use event delegation (no changes needed)

