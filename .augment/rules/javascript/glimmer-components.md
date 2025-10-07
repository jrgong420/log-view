---
id: discourse-glimmer-components
title: Modern Glimmer Component Patterns
type: rule
severity: required
category: javascript
applies_to: [discourse-theme, gjs, glimmer, components]
tags: [glimmer, components, gjs, template-tag, modern]
last_updated: 2025-10-07
sources:
  - https://meta.discourse.org/t/theme-developer-tutorial-5-building-and-using-components/357800
  - https://guides.emberjs.com/release/components/
  - https://meta.discourse.org/t/upcoming-post-stream-changes-how-to-prepare-themes-and-plugins/372063
---

# Modern Glimmer Component Patterns

## Intent

Glimmer components are the modern way to build UI in Discourse. They use the `.gjs` file format (template tag format) which combines JavaScript and templates in a single file. This is the **required approach** for all new development as of 2025.

## When This Applies

- When creating any new UI component
- When migrating from widget-based components (widgets EOL Q4 2025)
- When building plugin outlet connectors
- When creating reusable UI elements

## Component Types

### 1. Template-Only Components
Simple components with no JavaScript logic.

### 2. Class-Based Components
Components with state, computed properties, and methods.

## Do

### ✅ Use Template-Only Components for Simple UI

```javascript
// javascripts/discourse/components/simple-banner.gjs
const SimpleBanner = <template>
  <div class="simple-banner">
    <h3>Welcome to our community!</h3>
    <p>Please read the guidelines before posting.</p>
  </div>
</template>;

export default SimpleBanner;
```

### ✅ Use Class-Based Components for Interactive UI

```javascript
// javascripts/discourse/components/toggle-panel.gjs
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";

export default class TogglePanel extends Component {
  @tracked isExpanded = false;
  
  @action
  toggle() {
    this.isExpanded = !this.isExpanded;
  }
  
  <template>
    <div class="toggle-panel">
      <button {{on "click" this.toggle}}>
        {{if this.isExpanded "Collapse" "Expand"}}
      </button>
      
      {{#if this.isExpanded}}
        <div class="panel-content">
          {{yield}}
        </div>
      {{/if}}
    </div>
  </template>
}
```

### ✅ Use @tracked for Reactive State

```javascript
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";

export default class Counter extends Component {
  @tracked count = 0;
  
  @action
  increment() {
    this.count++;
  }
  
  @action
  decrement() {
    this.count--;
  }
  
  <template>
    <div class="counter">
      <button {{on "click" this.decrement}}>-</button>
      <span>{{this.count}}</span>
      <button {{on "click" this.increment}}>+</button>
    </div>
  </template>
}
```

### ✅ Inject Services with @service

```javascript
import Component from "@glimmer/component";
import { service } from "@ember/service";

export default class UserGreeting extends Component {
  @service currentUser;
  @service siteSettings;
  
  get greeting() {
    if (this.currentUser) {
      return `Hello, ${this.currentUser.username}!`;
    }
    return "Welcome, guest!";
  }
  
  <template>
    <div class="greeting">
      {{this.greeting}}
      {{#if this.siteSettings.show_welcome_message}}
        <p>Thanks for visiting!</p>
      {{/if}}
    </div>
  </template>
}
```

### ✅ Use Getters for Computed Properties

```javascript
import Component from "@glimmer/component";

export default class PostSummary extends Component {
  get isLongPost() {
    return this.args.post.raw.length > 1000;
  }
  
  get likeRatio() {
    const { like_count, reads } = this.args.post;
    if (reads === 0) return 0;
    return (like_count / reads * 100).toFixed(1);
  }
  
  <template>
    <div class="post-summary">
      <h4>{{@post.title}}</h4>
      {{#if this.isLongPost}}
        <span class="badge">Long Read</span>
      {{/if}}
      <p>Like ratio: {{this.likeRatio}}%</p>
    </div>
  </template>
}
```

### ✅ Access Arguments with @argName

```javascript
import Component from "@glimmer/component";

export default class TopicCard extends Component {
  <template>
    <div class="topic-card">
      <h3>{{@topic.title}}</h3>
      <p>By @{{@topic.user.username}}</p>
      <p>{{@topic.posts_count}} posts</p>
      
      {{#if @showCategory}}
        <span class="category">{{@topic.category.name}}</span>
      {{/if}}
    </div>
  </template>
}
```

### ✅ Use {{on}} Modifier for Event Handling

```javascript
import Component from "@glimmer/component";
import { action } from "@ember/object";

export default class ClickableCard extends Component {
  @action
  handleClick(event) {
    console.log("Card clicked:", event.target);
    this.args.onClick?.(this.args.item);
  }
  
  @action
  handleMouseEnter() {
    console.log("Mouse entered");
  }
  
  <template>
    <div
      class="clickable-card"
      {{on "click" this.handleClick}}
      {{on "mouseenter" this.handleMouseEnter}}
    >
      {{yield}}
    </div>
  </template>
}
```

### ✅ Clean Up in willDestroy

```javascript
import Component from "@glimmer/component";
import { action } from "@ember/object";

export default class TimerComponent extends Component {
  timerId = null;
  
  constructor() {
    super(...arguments);
    this.timerId = setInterval(() => {
      console.log("Tick");
    }, 1000);
  }
  
  willDestroy() {
    super.willDestroy(...arguments);
    if (this.timerId) {
      clearInterval(this.timerId);
      this.timerId = null;
    }
  }
  
  <template>
    <div>Timer running...</div>
  </template>
}
```

### ✅ Use {{yield}} for Content Projection

```javascript
import Component from "@glimmer/component";

export default class Card extends Component {
  <template>
    <div class="card {{@variant}}">
      <div class="card-header">
        {{yield to="header"}}
      </div>
      <div class="card-body">
        {{yield}}
      </div>
      <div class="card-footer">
        {{yield to="footer"}}
      </div>
    </div>
  </template>
}

// Usage:
// <Card @variant="primary">
//   <:header>Title</:header>
//   Main content
//   <:footer>Footer</:footer>
// </Card>
```

## Don't

### ❌ Don't Use Widgets (Deprecated Q4 2025)

```javascript
// DEPRECATED - widgets are being removed
import { createWidget } from "discourse/widgets/widget";

export default createWidget("my-widget", {
  // This will stop working in Q4 2025
});
```

Use Glimmer components instead.

### ❌ Don't Mutate Arguments

```javascript
// BAD - arguments are read-only
export default class MyComponent extends Component {
  constructor() {
    super(...arguments);
    this.args.value = "new value"; // Error!
  }
}
```

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

### ❌ Don't Use this.set() or this.get()

```javascript
// BAD - old Ember Classic pattern
export default class MyComponent extends Component {
  init() {
    super.init(...arguments);
    this.set("count", 0);
  }
  
  increment() {
    this.set("count", this.get("count") + 1);
  }
}
```

```javascript
// GOOD - use @tracked
export default class MyComponent extends Component {
  @tracked count = 0;
  
  @action
  increment() {
    this.count++;
  }
}
```

### ❌ Don't Forget @action Decorator

```javascript
// BAD - method loses 'this' context
export default class MyComponent extends Component {
  handleClick() {
    console.log(this.args.value); // 'this' is undefined!
  }
  
  <template>
    <button {{on "click" this.handleClick}}>Click</button>
  </template>
}
```

```javascript
// GOOD - use @action decorator
export default class MyComponent extends Component {
  @action
  handleClick() {
    console.log(this.args.value); // 'this' works correctly
  }
  
  <template>
    <button {{on "click" this.handleClick}}>Click</button>
  </template>
}
```

### ❌ Don't Use jQuery

```javascript
// BAD - jQuery is being phased out
export default class MyComponent extends Component {
  @action
  handleClick() {
    $(".my-element").addClass("active");
  }
}
```

```javascript
// GOOD - use native DOM APIs or Ember modifiers
export default class MyComponent extends Component {
  @action
  handleClick(event) {
    event.target.classList.add("active");
  }
}
```

## Patterns

### Good: Form Component with Validation

```javascript
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";

export default class ContactForm extends Component {
  @tracked name = "";
  @tracked email = "";
  @tracked message = "";
  @tracked errors = {};
  
  get isValid() {
    return this.name && this.email && this.message && Object.keys(this.errors).length === 0;
  }
  
  @action
  validateEmail() {
    if (!this.email.includes("@")) {
      this.errors = { ...this.errors, email: "Invalid email" };
    } else {
      const { email, ...rest } = this.errors;
      this.errors = rest;
    }
  }
  
  @action
  async submit(event) {
    event.preventDefault();
    
    if (!this.isValid) return;
    
    await this.args.onSubmit({
      name: this.name,
      email: this.email,
      message: this.message
    });
    
    // Reset form
    this.name = "";
    this.email = "";
    this.message = "";
  }
  
  <template>
    <form {{on "submit" this.submit}}>
      <input
        type="text"
        value={{this.name}}
        {{on "input" (fn (mut this.name) value="target.value")}}
        placeholder="Name"
      />
      
      <input
        type="email"
        value={{this.email}}
        {{on "input" (fn (mut this.email) value="target.value")}}
        {{on "blur" this.validateEmail}}
        placeholder="Email"
      />
      {{#if this.errors.email}}
        <span class="error">{{this.errors.email}}</span>
      {{/if}}
      
      <textarea
        value={{this.message}}
        {{on "input" (fn (mut this.message) value="target.value")}}
        placeholder="Message"
      />
      
      <button type="submit" disabled={{not this.isValid}}>
        Submit
      </button>
    </form>
  </template>
}
```

### Good: List Component with Filtering

```javascript
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";

export default class FilterableList extends Component {
  @tracked searchTerm = "";
  
  get filteredItems() {
    if (!this.searchTerm) {
      return this.args.items;
    }
    
    const term = this.searchTerm.toLowerCase();
    return this.args.items.filter(item =>
      item.title.toLowerCase().includes(term)
    );
  }
  
  @action
  updateSearch(event) {
    this.searchTerm = event.target.value;
  }
  
  <template>
    <div class="filterable-list">
      <input
        type="search"
        value={{this.searchTerm}}
        {{on "input" this.updateSearch}}
        placeholder="Search..."
      />
      
      <ul>
        {{#each this.filteredItems as |item|}}
          <li>{{item.title}}</li>
        {{else}}
          <li class="empty">No items found</li>
        {{/each}}
      </ul>
    </div>
  </template>
}
```

### Good: Component with Service Integration

```javascript
import Component from "@glimmer/component";
import { service } from "@ember/service";
import { action } from "@ember/object";

export default class BookmarkButton extends Component {
  @service currentUser;
  @service router;
  
  get isBookmarked() {
    return this.args.topic.bookmarked;
  }
  
  @action
  async toggleBookmark() {
    if (!this.currentUser) {
      this.router.transitionTo("login");
      return;
    }
    
    await this.args.onToggleBookmark(this.args.topic);
  }
  
  <template>
    <button
      class="bookmark-button {{if this.isBookmarked 'active'}}"
      {{on "click" this.toggleBookmark}}
      title={{if this.isBookmarked "Remove bookmark" "Add bookmark"}}
    >
      {{if this.isBookmarked "★" "☆"}}
    </button>
  </template>
}
```

## Diagnostics/Verification

### Debugging Component State

```javascript
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";

export default class DebugComponent extends Component {
  @tracked count = 0;
  
  constructor() {
    super(...arguments);
    console.log("[Component] Constructed with args:", this.args);
  }
  
  willDestroy() {
    console.log("[Component] Destroying");
    super.willDestroy(...arguments);
  }
  
  <template>
    {{log "Rendering with count:" this.count}}
    <div>Count: {{this.count}}</div>
  </template>
}
```

### Testing Components

1. ✅ Verify component renders correctly
2. ✅ Test reactive updates (change @tracked properties)
3. ✅ Test event handlers
4. ✅ Verify cleanup in willDestroy
5. ✅ Test with different argument combinations
6. ✅ Check for memory leaks (DevTools memory profiler)

## References

- [Theme Developer Tutorial: Components](https://meta.discourse.org/t/357800)
- [Glimmer Component Guide](https://guides.emberjs.com/release/components/)
- [Ember Tracked Properties](https://guides.emberjs.com/release/in-depth-topics/autotracking-in-depth/)
- [Post Stream Migration Guide](https://meta.discourse.org/t/372063)

