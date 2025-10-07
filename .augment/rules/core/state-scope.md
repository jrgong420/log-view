---
id: discourse-state-scope
title: State Scope Guidelines for Discourse Theme Components
type: rule
severity: recommended
category: state-management
applies_to: [discourse-theme, js, gjs, state]
tags: [state, scope, session, view-only, glimmer, tracked]
last_updated: 2025-10-07
sources:
  - Internal project experience
  - https://guides.emberjs.com/release/components/
---

# State Scope Guidelines for Discourse Theme Components

## Intent

Choose the correct scope for state management to avoid bugs like unintended persistence, redirect loops, or stale data. Discourse theme components can manage state at different levels: component-scoped, module-scoped, session-scoped, or persisted.

## When This Applies

- When implementing toggles, flags, or temporary UI state
- When suppressing one-time actions after user interactions
- When storing user preferences or settings
- When managing component-specific reactive state
- When coordinating state across multiple components

## State Scopes

### 1. Component-Scoped (Recommended for UI State)

**Lifetime**: Exists only while the component instance exists  
**Implementation**: `@tracked` properties in Glimmer components  
**Use for**: Component-specific UI state, form inputs, local toggles

### 2. Module-Scoped (View-Only)

**Lifetime**: Current route/view; manually reset on page changes  
**Implementation**: Module-level variables  
**Use for**: One-shot suppression flags, temporary guards, cross-component coordination

### 3. Session-Scoped

**Lifetime**: Browser tab/window session via `sessionStorage`  
**Implementation**: `sessionStorage` API  
**Use for**: Per-session preferences that should persist across navigation but not browser restarts

### 4. Persisted

**Lifetime**: Across sessions via `localStorage` or server settings  
**Implementation**: `localStorage` API or Discourse user settings  
**Use for**: Long-term user preferences (prefer server-side settings when possible)

## Do

### ✅ Use @tracked for Component State (Modern)

```javascript
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";

export default class ToggleComponent extends Component {
  @tracked isExpanded = false;
  
  @action
  toggle() {
    this.isExpanded = !this.isExpanded;
  }
  
  <template>
    <button {{on "click" this.toggle}}>
      {{if this.isExpanded "Collapse" "Expand"}}
    </button>
    
    {{#if this.isExpanded}}
      <div class="content">
        {{yield}}
      </div>
    {{/if}}
  </template>
}
```

### ✅ Use Module-Level Flags for One-Shot Suppression

```javascript
import { apiInitializer } from "discourse/lib/api";

// Module-scoped state
let suppressNextAction = false;
let suppressedTopicId = null;

export default apiInitializer((api) => {
  // User action sets the flag
  document.addEventListener("click", (e) => {
    if (e.target.closest(".dismiss-notice")) {
      const topic = api.container.lookup("controller:topic")?.model;
      suppressNextAction = true;
      suppressedTopicId = topic?.id;
    }
  }, true);
  
  // onPageChange consumes and clears the flag
  api.onPageChange(() => {
    const topic = api.container.lookup("controller:topic")?.model;
    
    if (suppressNextAction) {
      if (topic?.id === suppressedTopicId) {
        // Consume the flag
        suppressNextAction = false;
        suppressedTopicId = null;
        console.log("Suppressed action for this topic");
        return;
      } else {
        // Different topic, clear the flag
        suppressNextAction = false;
        suppressedTopicId = null;
      }
    }
    
    // Normal logic here
  });
});
```

### ✅ Use Ember Services for Shared State

```javascript
// In a service file (if creating a plugin)
import Service from "@ember/service";
import { tracked } from "@glimmer/tracking";

export default class MyFeatureService extends Service {
  @tracked isEnabled = false;
  @tracked currentFilter = null;
  
  enable() {
    this.isEnabled = true;
  }
  
  disable() {
    this.isEnabled = false;
  }
}

// In a component
import Component from "@glimmer/component";
import { service } from "@ember/service";

export default class MyComponent extends Component {
  @service myFeature;
  
  <template>
    {{#if this.myFeature.isEnabled}}
      <div>Feature is enabled</div>
    {{/if}}
  </template>
}
```

### ✅ Use sessionStorage for Per-Session Preferences

```javascript
import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  const STORAGE_KEY = "theme_feature_dismissed";
  
  api.onPageChange(() => {
    // Check session storage
    const dismissed = sessionStorage.getItem(STORAGE_KEY);
    
    if (dismissed) {
      console.log("Feature was dismissed this session");
      return;
    }
    
    // Show feature, allow user to dismiss
    document.addEventListener("click", (e) => {
      if (e.target.closest(".dismiss-feature")) {
        sessionStorage.setItem(STORAGE_KEY, "true");
        console.log("Feature dismissed for this session");
      }
    }, { once: true });
  });
});
```

### ✅ Reset View-Only State Deterministically

```javascript
let viewState = {
  actionSuppressed: false,
  targetTopicId: null,
  timestamp: null
};

function resetViewState() {
  viewState.actionSuppressed = false;
  viewState.targetTopicId = null;
  viewState.timestamp = null;
}

api.onPageChange(() => {
  // Consume and clear pattern
  if (viewState.actionSuppressed) {
    const topic = api.container.lookup("controller:topic")?.model;
    
    if (topic?.id === viewState.targetTopicId) {
      console.log("Consuming suppression flag");
      resetViewState();
      return;
    }
  }
  
  // Always reset on new page
  resetViewState();
});
```

## Don't

### ❌ Don't Store View-Only State in sessionStorage/localStorage

```javascript
// BAD - view-only state shouldn't persist
api.onPageChange(() => {
  if (sessionStorage.getItem("suppress_action")) {
    sessionStorage.removeItem("suppress_action");
    return;
  }
  
  // This persists across navigations unnecessarily
});
```

Use module-level variables instead:

```javascript
// GOOD - view-only state
let suppressAction = false;

api.onPageChange(() => {
  if (suppressAction) {
    suppressAction = false;
    return;
  }
});
```

### ❌ Don't Rely on Model Fields That May Not Be Ready

```javascript
// BAD - model might not be loaded yet
api.onPageChange(() => {
  const topic = api.container.lookup("controller:topic")?.model;
  
  if (topic.customField === "value") {
    // customField might be undefined during initial render
    doSomething();
  }
});
```

Combine with URL/UI guards:

```javascript
// GOOD - multiple guard conditions
api.onPageChange(() => {
  const url = new URL(window.location.href);
  const hasParam = url.searchParams.get("custom");
  const hasUI = !!document.querySelector(".custom-indicator");
  
  if (hasParam || hasUI) {
    // More reliable than model field alone
    return;
  }
});
```

### ❌ Don't Mutate Component Args

```javascript
// BAD - args are read-only
export default class MyComponent extends Component {
  constructor() {
    super(...arguments);
    this.args.value = "new value"; // Error!
  }
}
```

Use tracked properties instead:

```javascript
// GOOD - use tracked properties
export default class MyComponent extends Component {
  @tracked localValue = this.args.value;
  
  @action
  updateValue(newValue) {
    this.localValue = newValue;
    this.args.onChange?.(newValue); // Notify parent
  }
}
```

### ❌ Don't Create Memory Leaks with Untracked State

```javascript
// BAD - state persists even after component is destroyed
const componentStates = new Map();

export default class MyComponent extends Component {
  constructor() {
    super(...arguments);
    componentStates.set(this, { data: [] });
  }
  
  // Missing cleanup!
}
```

Clean up in willDestroy:

```javascript
// GOOD - clean up on destroy
const componentStates = new WeakMap(); // Or clean up manually

export default class MyComponent extends Component {
  constructor() {
    super(...arguments);
    componentStates.set(this, { data: [] });
  }
  
  willDestroy() {
    super.willDestroy(...arguments);
    componentStates.delete(this);
  }
}
```

## Patterns

### Good: One-Shot Suppression (View-Scoped)

```javascript
import { apiInitializer } from "discourse/lib/api";

let suppressNextAction = false;
let suppressedTopicId = null;

export default apiInitializer((api) => {
  // User action
  document.addEventListener("click", (e) => {
    if (e.target.closest(".trigger-suppression")) {
      const topic = api.container.lookup("controller:topic")?.model;
      suppressNextAction = true;
      suppressedTopicId = topic?.id;
    }
  }, true);
  
  // Consume in onPageChange
  api.onPageChange(() => {
    const topic = api.container.lookup("controller:topic")?.model;
    
    if (suppressNextAction) {
      if (topic?.id === suppressedTopicId) {
        // Consume and clear
        suppressNextAction = false;
        suppressedTopicId = null;
        return; // Skip action
      } else {
        // Different topic, clear anyway
        suppressNextAction = false;
        suppressedTopicId = null;
      }
    }
    
    // Normal action
    performAction();
  });
});
```

### Good: Component State with Tracked Properties

```javascript
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";

export default class FilterPanel extends Component {
  @tracked selectedFilter = "all";
  @tracked isExpanded = false;
  
  @action
  setFilter(filter) {
    this.selectedFilter = filter;
    this.args.onFilterChange?.(filter);
  }
  
  @action
  toggleExpanded() {
    this.isExpanded = !this.isExpanded;
  }
  
  <template>
    <div class="filter-panel">
      <button {{on "click" this.toggleExpanded}}>
        {{if this.isExpanded "Hide" "Show"}} Filters
      </button>
      
      {{#if this.isExpanded}}
        <select {{on "change" (fn this.setFilter)}}>
          <option value="all" selected={{eq this.selectedFilter "all"}}>All</option>
          <option value="active" selected={{eq this.selectedFilter "active"}}>Active</option>
        </select>
      {{/if}}
    </div>
  </template>
}
```

### Good: Session Preference

```javascript
import { apiInitializer } from "discourse/lib/api";

const PREF_KEY = "theme_compact_view";

export default apiInitializer((api) => {
  // Read preference
  const isCompact = sessionStorage.getItem(PREF_KEY) === "true";
  
  if (isCompact) {
    document.body.classList.add("compact-view");
  }
  
  // Allow toggling
  document.addEventListener("click", (e) => {
    if (e.target.closest(".toggle-compact")) {
      const newValue = !document.body.classList.contains("compact-view");
      sessionStorage.setItem(PREF_KEY, String(newValue));
      document.body.classList.toggle("compact-view", newValue);
    }
  }, true);
});
```

## Diagnostics/Verification

### Logging State Changes

```javascript
let state = { flag: false, id: null };

function setState(newState) {
  console.log("[State] Before:", state);
  state = { ...state, ...newState };
  console.log("[State] After:", state);
}

// Use setState instead of direct mutation
setState({ flag: true, id: 123 });
```

### Testing State Lifecycle

1. ✅ Navigate to page - verify state initializes correctly
2. ✅ Trigger action - verify state updates
3. ✅ Navigate away - verify state clears (for view-scoped)
4. ✅ Navigate back - verify state reinitializes
5. ✅ Refresh page - verify session/persisted state survives (if applicable)
6. ✅ Close tab - verify session state clears

## References

- [Glimmer Component Guide](https://guides.emberjs.com/release/components/)
- [Ember Tracked Properties](https://guides.emberjs.com/release/in-depth-topics/autotracking-in-depth/)
- [Ember Services](https://guides.emberjs.com/release/services/)
- [Web Storage API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Storage_API)

