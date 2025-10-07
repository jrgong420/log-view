---
id: discourse-redirect-loop-avoidance
title: Redirect Loop Avoidance in Discourse Themes
type: rule
severity: required
category: navigation
applies_to: [discourse-theme, js, gjs, navigation]
tags: [redirect, navigation, url-params, idempotency]
last_updated: 2025-10-07
sources:
  - Internal project experience
---

# Redirect Loop Avoidance in Discourse Themes

## Intent

Prevent infinite redirect loops when programmatically changing URL parameters or navigating in Discourse themes. This is critical when implementing features like automatic filtering, URL parameter manipulation, or conditional redirects.

## When This Applies

- When programmatically adding/modifying URL parameters (e.g., `username_filters`, `tags`, `category`)
- When implementing automatic redirects based on topic/category settings
- When using `window.location.replace()` or router navigation in `api.onPageChange`
- When responding to UI state changes that trigger navigation

## Do

### ✅ Check Current State Before Navigating

Always verify the target state isn't already applied:

```javascript
import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  api.onPageChange((url, title) => {
    const currentUrl = new URL(window.location.href);
    const currentFilter = currentUrl.searchParams.get("username_filters");
    
    // Early return if already filtered
    if (currentFilter) {
      console.log("Already filtered, skipping navigation");
      return;
    }
    
    // Safe to navigate now
    currentUrl.searchParams.set("username_filters", "someuser");
    window.location.replace(currentUrl.toString());
  });
});
```

### ✅ Use Multiple Guard Conditions

Check both URL parameters AND UI indicators:

```javascript
import { apiInitializer } from "discourse/lib/api";
import { schedule } from "@ember/runloop";

export default apiInitializer((api) => {
  api.onPageChange((url, title) => {
    schedule("afterRender", () => {
      const currentUrl = new URL(window.location.href);
      const currentFilter = currentUrl.searchParams.get("username_filters");
      const hasFilteredNotice = !!document.querySelector(".posts-filtered-notice");
      
      // Guard: already in filtered state
      if (currentFilter || hasFilteredNotice) {
        console.log("Filter already applied (URL or UI indicator present)");
        return;
      }
      
      // Safe to apply filter
      currentUrl.searchParams.set("username_filters", ownerUsername);
      window.location.replace(currentUrl.toString());
    });
  });
});
```

### ✅ Defer Until Required Data is Available

Don't navigate if you don't have the data you need:

```javascript
import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  api.onPageChange((url, title) => {
    const topic = api.container.lookup("controller:topic")?.model;
    
    // Guard: required data not ready
    if (!topic || !topic.user) {
      console.log("Topic data not ready, skipping this cycle");
      return;
    }
    
    const ownerUsername = topic.user.username;
    if (!ownerUsername) {
      console.log("Owner username not available");
      return;
    }
    
    // Now safe to use the data
    const currentUrl = new URL(window.location.href);
    if (!currentUrl.searchParams.get("username_filters")) {
      currentUrl.searchParams.set("username_filters", ownerUsername);
      window.location.replace(currentUrl.toString());
    }
  });
});
```

### ✅ Use Router Service for SPA-Friendly Navigation (Modern)

Prefer Ember router over `window.location` when possible:

```javascript
import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  const router = api.container.lookup("service:router");
  
  api.onPageChange(() => {
    const currentRoute = router.currentRoute;
    const currentParams = currentRoute.queryParams;
    
    // Guard: already has the parameter
    if (currentParams.username_filters) {
      return;
    }
    
    // Use router for SPA navigation
    router.transitionTo({
      queryParams: { username_filters: "someuser" }
    });
  });
});
```

### ✅ Use Real Values, Not Tokens

Avoid special tokens that might cause server-side inconsistencies:

```javascript
// GOOD - use actual username
currentUrl.searchParams.set("username_filters", topic.user.username);

// BAD - special token might cause issues
currentUrl.searchParams.set("username_filters", "owner");
```

## Don't

### ❌ Don't Navigate Without Checking Current State

```javascript
// BAD - will loop infinitely
api.onPageChange(() => {
  const url = new URL(window.location.href);
  url.searchParams.set("username_filters", "someuser");
  window.location.replace(url.toString()); // Triggers onPageChange again!
});
```

### ❌ Don't Rely on Single Guard Condition

```javascript
// RISKY - UI might not be ready yet
api.onPageChange(() => {
  const hasNotice = !!document.querySelector(".posts-filtered-notice");
  if (hasNotice) return;
  
  // Might navigate before notice appears, causing loop
  applyFilter();
});
```

### ❌ Don't Force Navigation During Click Handlers

```javascript
// BAD - conflicts with Discourse's own navigation
document.addEventListener("click", (e) => {
  if (e.target.matches(".show-all-posts")) {
    // Discourse already handles this, don't force another navigation
    window.location.replace(newUrl); // Can cause double navigation
  }
});
```

## Patterns

### Good: Comprehensive Guard Pattern

```javascript
import { apiInitializer } from "discourse/lib/api";
import { schedule } from "@ember/runloop";

export default apiInitializer((api) => {
  api.onPageChange((url, title) => {
    schedule("afterRender", () => {
      // Get current state
      const currentUrl = new URL(window.location.href);
      const currentFilter = currentUrl.searchParams.get("username_filters");
      const hasFilteredNotice = !!document.querySelector(".posts-filtered-notice");
      
      // Get required data
      const topic = api.container.lookup("controller:topic")?.model;
      const ownerUsername = topic?.user?.username;
      
      // Guard 1: Already filtered
      if (currentFilter || hasFilteredNotice) {
        console.log(`[Filter] Already applied: ${currentFilter || "UI indicator present"}`);
        return;
      }
      
      // Guard 2: Data not ready
      if (!ownerUsername) {
        console.log("[Filter] Owner username not available yet");
        return;
      }
      
      // Guard 3: Not applicable (e.g., wrong category)
      const categoryId = topic?.category_id;
      if (categoryId !== 42) {
        console.log(`[Filter] Not applicable for category ${categoryId}`);
        return;
      }
      
      // All guards passed, safe to navigate
      console.log(`[Filter] Applying filter for user: ${ownerUsername}`);
      currentUrl.searchParams.set("username_filters", ownerUsername);
      window.location.replace(currentUrl.toString());
    });
  });
});
```

### Good: One-Shot Suppression Flag

For preventing double-navigation after user actions:

```javascript
import { apiInitializer } from "discourse/lib/api";

let suppressNextNavigation = false;
let suppressedTopicId = null;

export default apiInitializer((api) => {
  // User clicked "show all" button
  document.addEventListener("click", (e) => {
    if (e.target.closest(".show-all-posts")) {
      const topic = api.container.lookup("controller:topic")?.model;
      suppressNextNavigation = true;
      suppressedTopicId = topic?.id;
      console.log(`[Suppress] Suppressing next navigation for topic ${suppressedTopicId}`);
    }
  }, true);
  
  api.onPageChange(() => {
    const topic = api.container.lookup("controller:topic")?.model;
    
    if (suppressNextNavigation && topic?.id === suppressedTopicId) {
      console.log(`[Suppress] Skipping navigation for topic ${topic.id}`);
      suppressNextNavigation = false;
      suppressedTopicId = null;
      return;
    }
    
    // Reset flag if different topic
    if (suppressNextNavigation && topic?.id !== suppressedTopicId) {
      suppressNextNavigation = false;
      suppressedTopicId = null;
    }
    
    // Normal navigation logic here
  });
});
```

### Bad: No Guards

```javascript
// BAD - infinite loop guaranteed
api.onPageChange(() => {
  const url = new URL(window.location.href);
  url.searchParams.set("filter", "active");
  window.location.replace(url.toString());
});
```

## Diagnostics/Verification

### Logging Navigation Attempts

```javascript
let navigationAttempts = 0;

api.onPageChange((url, title) => {
  navigationAttempts++;
  
  console.log(`[Navigation] Attempt #${navigationAttempts}`);
  console.log(`[Navigation] URL: ${url}`);
  console.log(`[Navigation] Current params:`, new URL(window.location.href).searchParams.toString());
  
  if (navigationAttempts > 5) {
    console.error("[Navigation] Possible redirect loop detected!");
    return; // Emergency brake
  }
  
  // Your navigation logic with guards
});
```

### Testing Checklist

1. ✅ Navigate to target page - verify filter applies once
2. ✅ Refresh page - verify no additional navigation
3. ✅ Click "show all" button - verify suppression works
4. ✅ Navigate away and back - verify filter reapplies correctly
5. ✅ Check browser console for loop warnings
6. ✅ Monitor network tab for repeated requests

### Debugging Tips

```javascript
// Add temporary diagnostics
const debugState = {
  urlParam: new URL(window.location.href).searchParams.get("username_filters"),
  uiIndicator: !!document.querySelector(".posts-filtered-notice"),
  topicId: api.container.lookup("controller:topic")?.model?.id,
  ownerUsername: api.container.lookup("controller:topic")?.model?.user?.username
};

console.table(debugState);
```

## References

- [Ember Router Service](https://api.emberjs.com/ember/5.12/classes/RouterService)
- [URL API (MDN)](https://developer.mozilla.org/en-US/docs/Web/API/URL)
- [Discourse Plugin API](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/plugin-api.gjs)

