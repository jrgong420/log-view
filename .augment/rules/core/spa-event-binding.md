---
id: discourse-spa-event-binding
title: SPA Event Binding in Discourse Themes
type: rule
severity: recommended
category: javascript
applies_to: [discourse-theme, js, gjs, event-handling]
tags: [spa, events, delegation, router, lifecycle]
last_updated: 2025-10-07
sources:
  - https://meta.discourse.org/t/trigger-javascript-on-clicking-any-page-link-but-before-the-page-content-loads/167970
  - https://api.emberjs.com/ember/5.12/classes/RouterService/events
---

# SPA Event Binding in Discourse Themes

## Intent

Prevent stale event listeners and missed events in Discourse's single-page application (SPA) architecture. Discourse uses Ember.js routing, which means page content changes without full page reloads. Event handlers must be managed carefully to avoid memory leaks, duplicate listeners, and broken functionality.

## When This Applies

- When binding event listeners to DOM elements that may be re-rendered
- When responding to route/page changes in the SPA
- When working with legacy widget-based UI (being phased out Q4 2025)
- When targeting dynamically rendered content (post streams, topic lists, etc.)

## Do

### ✅ Use Event Delegation for Dynamic Content

Bind once at a stable ancestor and use event delegation:

```javascript
import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  let bound = false;
  
  if (!bound) {
    document.addEventListener(
      "click",
      (e) => {
        const target = e.target?.closest?.(".my-widget button, .my-widget a");
        if (!target) return;
        
        // Handle the event
        console.log("Button clicked:", target);
      },
      true // Use capture phase
    );
    bound = true;
  }
});
```

### ✅ Use Router Service for Route Changes (Modern)

The modern approach for responding to route changes:

```javascript
import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  const router = api.container.lookup("service:router");
  
  // Before route changes
  router.on("routeWillChange", (transition) => {
    console.log("Route will change to:", transition.to.name);
  });
  
  // After route changes
  router.on("routeDidChange", (transition) => {
    console.log("Route changed to:", transition.to.name);
  });
});
```

### ✅ Use api.onPageChange for Page-Level Logic (Still Valid)

For simpler cases where you need to run code after page content loads:

```javascript
import { apiInitializer } from "discourse/lib/api";
import { schedule } from "@ember/runloop";

export default apiInitializer((api) => {
  api.onPageChange((url, title) => {
    schedule("afterRender", () => {
      // DOM is ready, safe to query elements
      const container = document.querySelector(".topic-body");
      if (container) {
        // Do something with the container
      }
    });
  });
});
```

### ✅ Use Glimmer Component Lifecycle Hooks

For component-specific event handling:

```javascript
import Component from "@glimmer/component";
import { action } from "@ember/object";

export default class MyComponent extends Component {
  @action
  handleClick(event) {
    console.log("Clicked:", event.target);
  }
  
  willDestroy() {
    super.willDestroy(...arguments);
    // Clean up any manual event listeners here
  }
  
  <template>
    <button {{on "click" this.handleClick}}>
      Click Me
    </button>
  </template>
}
```

### ✅ Keep Listener Registration Idempotent

If you must bind repeatedly, ensure it's safe:

```javascript
let globalListenerBound = false;

function setupGlobalListener() {
  if (globalListenerBound) return;
  
  document.addEventListener("click", handleGlobalClick, true);
  globalListenerBound = true;
}
```

## Don't

### ❌ Don't Bind Directly to Transient Elements

This breaks when Ember re-renders the content:

```javascript
// BAD - element may be replaced on re-render
api.onPageChange(() => {
  const btn = document.querySelector(".my-widget button");
  btn?.addEventListener("click", handler, { once: true });
});
```

### ❌ Don't Use Container "Bound Guards" for Replaced Children

This doesn't work when children are replaced:

```javascript
// BAD - children get replaced, but container stays
const container = document.querySelector(".my-widget");
if (!container.dataset.bound) {
  container.dataset.bound = "1";
  const btn = container.querySelector("button");
  btn?.addEventListener("click", handler); // Will break on re-render
}
```

### ❌ Don't Use Widget Decorations (Deprecated Q4 2025)

```javascript
// DEPRECATED - widgets are being removed
api.decorateWidget("post-contents:after-cooked", (helper) => {
  // This will stop working in Q4 2025
});
```

Use plugin outlets and Glimmer components instead.

### ❌ Don't Use jQuery and $(document).ready

```javascript
// BAD - jQuery is being phased out
$(document).ready(() => {
  $(".my-element").on("click", handler);
});
```

Use native DOM APIs and proper lifecycle hooks instead.

## Patterns

### Good: Event Delegation with Route Awareness

```javascript
import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  const router = api.container.lookup("service:router");
  let delegationBound = false;
  
  if (!delegationBound) {
    document.addEventListener("click", (e) => {
      const target = e.target?.closest?.(".custom-action-button");
      if (!target) return;
      
      const currentRoute = router.currentRouteName;
      console.log(`Action triggered on route: ${currentRoute}`);
      
      // Handle the action
      target.classList.add("clicked");
    }, true);
    
    delegationBound = true;
  }
});
```

### Good: Combining Router Events with Scheduled Work

```javascript
import { apiInitializer } from "discourse/lib/api";
import { schedule } from "@ember/runloop";

export default apiInitializer((api) => {
  const router = api.container.lookup("service:router");
  
  router.on("routeDidChange", () => {
    schedule("afterRender", () => {
      // DOM is stable, safe to manipulate
      const elements = document.querySelectorAll(".needs-enhancement");
      elements.forEach(el => {
        if (!el.dataset.enhanced) {
          enhanceElement(el);
          el.dataset.enhanced = "true";
        }
      });
    });
  });
});
```

### Bad: Direct Binding on Every Page Change

```javascript
// BAD - creates new listeners on every navigation
api.onPageChange(() => {
  document.querySelectorAll(".my-button").forEach(btn => {
    btn.addEventListener("click", handler); // Memory leak!
  });
});
```

## Diagnostics/Verification

### Logging for Debugging

Add strategic logging to verify event binding:

```javascript
import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  const router = api.container.lookup("service:router");
  
  let clickCount = 0;
  
  document.addEventListener("click", (e) => {
    const target = e.target?.closest?.(".my-button");
    if (!target) return;
    
    clickCount++;
    const route = router.currentRouteName;
    const topicId = router.currentRoute?.attributes?.id;
    
    console.log(`[Event Binding] Click #${clickCount} on route: ${route}, topic: ${topicId}`);
  }, true);
  
  console.log("[Event Binding] Global delegation listener registered");
});
```

### Testing Across Route Changes

1. Navigate to different pages (topics, categories, user profiles)
2. Check browser console for duplicate log messages (indicates duplicate listeners)
3. Use browser DevTools → Performance → Memory to check for memory leaks
4. Verify events still fire after navigating away and back

### Checking for Stale Listeners

```javascript
// Add this temporarily to detect issues
let bindCount = 0;

api.onPageChange(() => {
  bindCount++;
  console.warn(`onPageChange called ${bindCount} times`);
  
  if (bindCount > 10) {
    console.error("Possible listener leak detected!");
  }
});
```

## References

- [Trigger JavaScript on Page Link Clicks](https://meta.discourse.org/t/167970) - Router service events
- [Ember Router Service API](https://api.emberjs.com/ember/5.12/classes/RouterService/events)
- [Glimmer Component Lifecycle](https://guides.emberjs.com/release/components/)
- [Upcoming EOL for Widget System](https://meta.discourse.org/t/375332)

