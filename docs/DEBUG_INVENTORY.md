# Debug Inventory and Triage

**Date**: 2025-10-14  
**Purpose**: Comprehensive catalog of project files, entry points, behaviors, and reproduction scenarios for systematic debugging with console logging.

---

## 1. Project Overview

**Theme Name**: Owner Comments  
**Type**: Discourse Theme Component  
**Version**: 0.1.0  
**Minimum Discourse**: 3.1.0  
**Repository**: https://github.com/jrgong420/log-view

### Core Features
1. **Auto-filter topics** to show only owner's posts in configured categories
2. **Embedded reply buttons** for replying to owner posts within embedded sections
3. **Auto-refresh** embedded posts after reply submission
4. **Hide reply buttons** for non-owner posts (optional)
5. **Toggle button** to switch between filtered/unfiltered views
6. **Group-based access control** to restrict features to specific user groups

---

## 2. File Inventory

### Configuration Files
- `about.json` - Theme metadata
- `settings.yml` - 6 settings (categories, auto_mode, toggle, groups, hide_reply_buttons)
- `locales/en.yml` - English translations
- `locales/de.yml` - German translations

### JavaScript Entry Points (API Initializers)

#### 2.1 `embedded-reply-buttons.gjs` (1442 lines) ⚠️ COMPLEX
**Purpose**: Inject reply buttons into embedded post sections, handle clicks, auto-refresh after reply  
**Key Features**:
- Section-level reply button injection
- MutationObserver for dynamic sections
- Standard reply button interception (in filtered view)
- Collapsed section expansion orchestration
- Auto-scroll to newly created posts
- Hide duplicate posts in main stream

**Module-Level State**:
- `globalClickHandlerBound`, `showRepliesClickHandlerBound`, `composerEventsBound` (idempotency flags)
- `activeObservers` (Map) - tracks MutationObservers per post
- `lastReplyContext` - fallback for parent post number
- `lastCreatedPost` - for auto-scroll targeting
- `suppressStandardReplyScroll`, `suppressedReplyPostNumber` - one-shot suppression
- `replyToCollapsedSection`, `replyOwnerPostNumberForExpand`, `expandOrchestratorActive` - expansion state

**Current Logging**:
- `DEBUG = false` (hardcoded)
- `LOG_PREFIX = "[Owner View] [Embedded Reply Buttons]"`
- Helpers: `logDebug`, `logInfo`, `logWarn`, `logError`

**Event Handlers**:
- Global delegated click for `.embedded-reply-button` (capture phase)
- Global delegated click for `.show-replies` and `.load-more-replies` (capture phase)
- Global delegated click for `.post-action-menu__reply` (standard reply interception, capture phase)
- `api.onPageChange` - inject buttons into already-expanded sections
- `appEvents.on("post:created")` - capture new post details
- `appEvents.on("composer:saved")` - trigger auto-refresh

**Risk Areas**:
- Complex state management across multiple flows
- MutationObserver lifecycle (cleanup on navigation)
- Redirect loop potential (URL manipulation in auto-filter)
- Race conditions (DOM readiness, data availability)

---

#### 2.2 `owner-comment-prototype.gjs` (245 lines)
**Purpose**: Auto-apply username_filters parameter in configured categories  
**Key Features**:
- Server-side filter enforcement via URL parameter
- One-shot suppression for user opt-out
- Session-scoped opt-out storage

**Module-Level State**:
- `suppressNextAutoFilter`, `suppressedTopicId` - one-shot suppression
- `optOutDelegationBound` - idempotency flag

**Current Logging**:
- `DEBUG = false` (hardcoded)
- Prefix: `"[Owner View] [Owner Comments]"`

**Event Handlers**:
- Global delegated click for `.posts-filtered-notice button` (capture phase)
- `api.onPageChange` - apply/clear filter based on category

**Risk Areas**:
- Redirect loop if guards fail (URL navigation)
- State reset timing (suppression flags)

---

#### 2.3 `hide-reply-buttons.gjs` (212 lines)
**Purpose**: Hide reply buttons on non-owner posts in configured categories  
**Key Features**:
- Post classification (owner vs non-owner)
- MutationObserver for newly rendered posts
- CSS class-based hiding

**Module-Level State**:
- `streamObserver` - single MutationObserver for post stream

**Current Logging**:
- `DEBUG = false` (hardcoded)
- Prefix: `"[Owner View] [Hide Reply Buttons]"`

**Event Handlers**:
- `api.onPageChange` - classify posts and observe stream

**Risk Areas**:
- Observer cleanup on navigation
- Post data availability timing

---

#### 2.4 `group-access-control.gjs` (103 lines)
**Purpose**: Apply body class based on group membership  
**Key Features**:
- Parse allowed_groups setting
- Add/remove `theme-component-access-granted` class

**Current Logging**:
- `DEBUG = false` (hardcoded)
- Prefix: `"[Owner View] [Group Access Control]"`

**Event Handlers**:
- Initial load + `api.onPageChange`

**Risk Areas**:
- Minimal (simple class toggle)

---

#### 2.5 `owner-toggle-outlets.gjs` (74 lines)
**Purpose**: Render toggle button in timeline and mobile outlets  
**Key Features**:
- Conditional rendering via `shouldRender`
- Desktop vs mobile outlet selection

**Current Logging**:
- None (delegates to component and utils)

**Risk Areas**:
- Minimal (rendering only)

---

#### 2.6 `log-view.gjs` (6 lines)
**Purpose**: Empty placeholder  
**Status**: Unused

---

### Components

#### 2.7 `owner-toggle-button.gjs` (87 lines)
**Purpose**: Toggle button component for filtered/unfiltered view  
**Key Features**:
- Detect current filter state from URL
- Navigate to filtered/unfiltered URL
- Set session opt-out flag

**Current Logging**:
- None

**Risk Areas**:
- URL navigation (potential redirect loop if guards fail)

---

### Utilities

#### 2.8 `lib/group-access-utils.js` (191 lines)
**Purpose**: Shared utilities for group access and category checks  
**Key Features**:
- `parseCategoryIds` - parse pipe-separated category IDs
- `isUserAllowedAccess` - check group membership
- `shouldShowToggleButton` - gate toggle button rendering

**Current Logging**:
- `DEBUG = true` ⚠️ (always on!)
- Prefix: `"[Group Access Control]"`
- Also uses `console.log("[Toggle Button]")` directly

**Risk Areas**:
- Verbose logging always enabled

---

## 3. Expected Behaviors

### 3.1 Auto-Filter Flow (owner-comment-prototype.gjs)
1. User navigates to topic in configured category
2. Check if already filtered (URL param or UI notice)
3. If not filtered and auto_mode enabled and not opted out:
   - Add `username_filters=<owner>` to URL
   - Navigate via `window.location.replace`
   - Set `document.body.dataset.ownerCommentMode = "true"`
4. If user clicks "show all" in filtered notice:
   - Set one-shot suppression flag
   - Navigate to unfiltered URL

**Expected Console Output** (when DEBUG=true):
```
[Owner View] [Owner Comments] === Page change detected ===
[Owner View] [Owner Comments] Running afterRender hook
[Owner View] [Owner Comments] Topic model: {...}
[Owner View] [Owner Comments] Theme settings: {...}
[Owner View] [Owner Comments] Navigating to server-filtered URL: ...
```

---

### 3.2 Embedded Reply Button Flow (embedded-reply-buttons.gjs)
1. User clicks "show replies" on owner post
2. MutationObserver detects `section.embedded-posts` added
3. Inject reply button next to collapse button
4. User clicks embedded reply button
5. Composer opens with `replyToPostNumber` set to owner post
6. User submits reply
7. `composer:saved` event fires
8. Auto-refresh logic:
   - Find owner post element containing embedded section
   - If collapsed: expand → load all → scroll to new post
   - If expanded: scroll to new post
9. Hide duplicate in main stream (if in owner mode)

**Expected Console Output** (when DEBUG=true):
```
[Owner View] [Embedded Reply Buttons] Show replies button clicked for post #1
[Owner View] [Embedded Reply Buttons] Embedded section detected, attempting injection
[Owner View] [Embedded Reply Buttons] Button injected successfully
[Owner View] [Embedded Reply Buttons] Section-level reply button clicked
[Owner View] [Embedded Reply Buttons] Opening reply to owner post #1
[Owner View] [Embedded Reply Buttons] Composer opened successfully
[Owner View] [Embedded Reply Buttons] AutoRefresh: composer:saved fired {...}
[Owner View] [Embedded Reply Buttons] AutoRefresh: target parent post #1 (source: ...)
[Owner View] [Embedded Reply Buttons] AutoScroll: scrolling to post #123
```

---

### 3.3 Standard Reply Interception Flow (embedded-reply-buttons.gjs)
1. User in filtered view clicks standard reply button on owner post
2. Intercept click in capture phase
3. Prevent default behavior
4. Detect if embedded section is collapsed
5. Set suppression flag
6. Open composer (same as embedded button)
7. On save: expand if needed, scroll to new post

**Expected Console Output** (when DEBUG=true):
```
[Owner View] [Embedded Reply Buttons] Standard reply intercepted for owner post #1
[Owner View] [Embedded Reply Buttons] Detected collapsed embedded section for post #1
[Owner View] [Embedded Reply Buttons] Set suppression flag for post #1
[Owner View] [Embedded Reply Buttons] Standard reply suppression active - preventing default scroll
```

---

## 4. Reproduction Scenarios

### Scenario A: Embedded Reply (Expanded Section)
**Setup**: Topic in configured category, owner post with replies already expanded  
**Steps**:
1. Navigate to topic
2. Verify embedded section visible
3. Click embedded reply button
4. Type message, submit
5. Observe auto-scroll to new post

**Expected**: New post appears in embedded section, scrolls into view, no duplicate in main stream  
**Verify**: Console logs show injection → click → composer → save → scroll

---

### Scenario B: Embedded Reply (Collapsed Section)
**Setup**: Topic in configured category, owner post with collapsed replies  
**Steps**:
1. Navigate to topic
2. Click standard reply button on owner post
3. Type message, submit
4. Observe expansion → loading → scroll

**Expected**: Section expands, all replies load, new post scrolls into view  
**Verify**: Console logs show interception → expansion → load-all → scroll

---

### Scenario C: Navigation Between Topics
**Setup**: Multiple topics in configured category  
**Steps**:
1. Navigate to topic A
2. Verify filter applied
3. Click link to topic B (same category)
4. Verify filter applied to topic B
5. Navigate back to topic A

**Expected**: No redirect loops, filter applies once per navigation  
**Verify**: Console logs show single navigation per topic, guards prevent re-application

---

### Scenario D: Toggle Button
**Setup**: Topic in configured category, filtered view  
**Steps**:
1. Verify toggle shows "Growreport" (filtered)
2. Click toggle
3. Verify navigation to unfiltered view
4. Verify toggle shows "Thema" (unfiltered)
5. Click toggle again
6. Verify navigation to filtered view

**Expected**: Smooth toggle, no redirect loops, opt-out flag prevents auto-filter after manual toggle  
**Verify**: Session storage shows opt-out flag, console logs show suppression

---

### Scenario E: Mobile View
**Setup**: Mobile viewport, topic in configured category  
**Steps**:
1. Resize to mobile
2. Verify toggle button in mobile outlet
3. Repeat Scenario D

**Expected**: Same behavior as desktop  
**Verify**: Outlet rendering logs

---

### Scenario F: Group Access Control
**Setup**: User not in allowed groups  
**Steps**:
1. Navigate to topic in configured category
2. Verify no filter applied
3. Verify no toggle button

**Expected**: Features disabled for unauthorized users  
**Verify**: Body class absent, console logs show access denied

---

## 5. Known Risk Areas

### 5.1 Redirect Loops
**Files**: `owner-comment-prototype.gjs`, `owner-toggle-button.gjs`  
**Cause**: URL navigation without checking current state  
**Guards Needed**:
- Check URL param before navigating
- Check UI indicator (`.posts-filtered-notice`)
- Check data availability (topic, owner username)
- One-shot suppression flags

---

### 5.2 Duplicate Event Listeners
**Files**: `embedded-reply-buttons.gjs`, `owner-comment-prototype.gjs`  
**Cause**: Binding listeners inside `onPageChange` without idempotency  
**Guards Needed**:
- Module-level `bound` flags
- Use capture phase delegation
- Bind once at module load, not per page change

---

### 5.3 MutationObserver Leaks
**Files**: `embedded-reply-buttons.gjs`, `hide-reply-buttons.gjs`  
**Cause**: Not disconnecting observers on navigation  
**Guards Needed**:
- Track observers in Map/Set
- Disconnect all on `onPageChange`
- Clear tracking structures

---

### 5.4 State Scope Confusion
**Files**: `embedded-reply-buttons.gjs`  
**Cause**: Module-level state persisting across navigations  
**Guards Needed**:
- Reset view-scoped state on `onPageChange`
- Use session storage only for cross-navigation persistence
- Document state lifetime clearly

---

### 5.5 Data Availability Timing
**Files**: All initializers  
**Cause**: Accessing topic/user data before Ember models load  
**Guards Needed**:
- Use `schedule("afterRender")` for DOM queries
- Check for null/undefined before accessing nested properties
- Fallback chains for critical data

---

## 6. Next Steps

1. **Phase 2**: Design logging strategy (settings toggle, helper API, rate-limiting)
2. **Phase 3**: Implement core logging infrastructure (settings.yml, logger utility, localization)
3. **Phase 4-7**: Instrument each initializer systematically
4. **Phase 8**: Add diagnostic safety checks (loop detection, duplicate listener warnings)
5. **Phase 9**: Execute reproduction scenarios with logging enabled
6. **Phase 10**: Document findings, clean up, finalize

---

**End of Inventory**

