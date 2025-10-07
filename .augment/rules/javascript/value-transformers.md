---
id: discourse-value-transformers
title: Using Value and Behavior Transformers
type: rule
severity: recommended
category: javascript
applies_to: [discourse-theme, js, gjs, transformers]
tags: [transformers, value-transformers, behavior-transformers, api]
last_updated: 2025-10-07
sources:
  - https://meta.discourse.org/t/using-transformers-to-customize-client-side-values-and-behavior/349954
  - https://meta.discourse.org/t/upcoming-post-stream-changes-how-to-prepare-themes-and-plugins/372063
---

# Using Value and Behavior Transformers

## Intent

Transformers provide a powerful way to customize Discourse's client-side behavior without overriding entire components. They allow you to modify values, add CSS classes, customize metadata, or alter behavior at specific extension points throughout Discourse.

## When This Applies

- When you need to modify a value that Discourse core produces
- When adding custom CSS classes to posts or other elements
- When customizing post metadata display
- When modifying behavior like infinite scroll or navigation
- When plugin outlets aren't sufficient for your use case

## Types of Transformers

### 1. Value Transformers
Take an output from Discourse core, optionally modify it, and return the transformed value.

### 2. Behavior Transformers
Wrap a piece of logic in Discourse core, optionally calling the original implementation.

## Do

### ✅ Use Value Transformers to Modify Values

```javascript
import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  api.registerValueTransformer("home-logo-href", ({ value, context }) => {
    const site = api.container.lookup("service:site");
    
    // Modify logo link on mobile
    if (site.mobileView) {
      return "/latest";
    }
    
    // Return original value for desktop
    return value;
  });
});
```

### ✅ Add Custom CSS Classes to Posts

```javascript
import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  api.registerValueTransformer("post-class", ({ value, context }) => {
    const { post } = context;
    
    // Add custom class for posts from specific user
    if (post.user_id === 1) {
      return [...value, "admin-post"];
    }
    
    // Add class for wiki posts
    if (post.wiki) {
      return [...value, "wiki-post"];
    }
    
    return value;
  });
});
```

### ✅ Customize Post Metadata Display

```javascript
import { apiInitializer } from "discourse/lib/api";
import Component from "@glimmer/component";

export default apiInitializer((api) => {
  // Define component outside transformer to avoid memory issues
  const CustomMetadata = <template>
    <span class="custom-metadata">
      🔥 Popular
    </span>
  </template>;
  
  api.registerValueTransformer(
    "post-meta-data-infos",
    ({ value: metadata, context: { post, metaDataInfoKeys } }) => {
      // Only add for posts with many likes
      if (post.like_count > 10) {
        metadata.add(
          "custom-popular-indicator",
          CustomMetadata,
          {
            before: metaDataInfoKeys.DATE,
            after: metaDataInfoKeys.REPLY_TO_TAB,
          }
        );
      }
      
      // Note: no return needed, metadata is mutated
    }
  );
});
```

### ✅ Use Behavior Transformers to Modify Logic

```javascript
import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  api.registerBehaviorTransformer(
    "discovery-topic-list-load-more",
    ({ next, context }) => {
      const topicList = context.model;
      
      // Limit infinite loading to 100 topics
      if (topicList.topics.length > 100) {
        alert("Maximum topics loaded");
        return; // Don't call next()
      }
      
      // Call original behavior
      next();
    }
  );
});
```

### ✅ Access Context for Reactive Transformations

Many transformers run in autotracking contexts, so referencing reactive state causes automatic re-evaluation:

```javascript
import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  api.registerValueTransformer("post-class", ({ value, context }) => {
    const { post } = context;
    const currentUser = api.getCurrentUser();
    
    // This will re-evaluate when currentUser changes
    if (currentUser && post.user_id === currentUser.id) {
      return [...value, "my-post"];
    }
    
    return value;
  });
});
```

### ✅ Chain Multiple Transformers

Multiple transformers on the same hook run in registration order:

```javascript
// First transformer
api.registerValueTransformer("post-class", ({ value, context }) => {
  return [...value, "first-class"];
});

// Second transformer receives output of first
api.registerValueTransformer("post-class", ({ value, context }) => {
  // value already includes "first-class"
  return [...value, "second-class"];
});

// Final result: [...originalClasses, "first-class", "second-class"]
```

## Don't

### ❌ Don't Create Components Inside Transformer Callbacks

```javascript
// BAD - creates new component on every call, memory leak
api.registerValueTransformer("post-meta-data-infos", ({ value, context }) => {
  value.add(
    "my-metadata",
    <template><span>Data</span></template> // Created every time!
  );
});
```

```javascript
// GOOD - create component once outside transformer
const MyMetadata = <template><span>Data</span></template>;

api.registerValueTransformer("post-meta-data-infos", ({ value, context }) => {
  value.add("my-metadata", MyMetadata);
});
```

### ❌ Don't Mutate Value Directly (for Value Transformers)

```javascript
// BAD - mutating array directly
api.registerValueTransformer("post-class", ({ value, context }) => {
  value.push("new-class"); // Mutates original!
  return value;
});
```

```javascript
// GOOD - return new array
api.registerValueTransformer("post-class", ({ value, context }) => {
  return [...value, "new-class"];
});
```

### ❌ Don't Forget to Call next() in Behavior Transformers

```javascript
// BAD - original behavior never runs
api.registerBehaviorTransformer("some-behavior", ({ next, context }) => {
  console.log("Doing something");
  // Forgot to call next()!
});
```

```javascript
// GOOD - call next() to run original behavior
api.registerBehaviorTransformer("some-behavior", ({ next, context }) => {
  console.log("Before original behavior");
  next();
  console.log("After original behavior");
});
```

## Common Post Stream Transformers

### post-class
Add custom CSS classes to post elements.

**Context**: `{ post }`

```javascript
api.registerValueTransformer("post-class", ({ value, context }) => {
  const { post } = context;
  if (post.hidden) {
    return [...value, "hidden-post"];
  }
  return value;
});
```

### post-meta-data-infos
Customize post metadata components.

**Context**: `{ post, metaDataInfoKeys }`

```javascript
const CustomInfo = <template><span>Custom</span></template>;

api.registerValueTransformer("post-meta-data-infos", ({ value, context }) => {
  value.add("custom-info", CustomInfo, {
    before: context.metaDataInfoKeys.DATE
  });
});
```

### post-show-topic-map
Control topic map visibility on first post.

**Context**: `{ post, isPM, isRegular, showWithoutReplies }`

```javascript
api.registerValueTransformer("post-show-topic-map", ({ value, context }) => {
  // Always hide topic map
  return false;
});
```

### post-small-action-icon
Customize icons for small action posts.

**Context**: `{ post, actionCode }`

```javascript
api.registerValueTransformer("post-small-action-icon", ({ value, context }) => {
  if (context.actionCode === "custom_action") {
    return "star";
  }
  return value;
});
```

### poster-name-class
Add CSS classes to poster name container.

**Context**: `{ user }`

```javascript
api.registerValueTransformer("poster-name-class", ({ value, context }) => {
  if (context.user.admin) {
    return [...value, "admin-poster"];
  }
  return value;
});
```

## Patterns

### Good: Conditional Metadata Addition

```javascript
import { apiInitializer } from "discourse/lib/api";
import Component from "@glimmer/component";

export default apiInitializer((api) => {
  const VerifiedBadge = <template>
    <span class="verified-badge" title="Verified User">✓</span>
  </template>;
  
  api.registerValueTransformer(
    "post-meta-data-infos",
    ({ value: metadata, context: { post, metaDataInfoKeys } }) => {
      // Only add for verified users
      if (post.user?.custom_fields?.verified) {
        metadata.add("verified-badge", VerifiedBadge, {
          after: metaDataInfoKeys.POSTER_NAME
        });
      }
    }
  );
});
```

### Good: Multiple Class Additions

```javascript
api.registerValueTransformer("post-class", ({ value, context }) => {
  const { post } = context;
  const classes = [...value];
  
  if (post.wiki) classes.push("wiki-post");
  if (post.hidden) classes.push("hidden-post");
  if (post.user_deleted) classes.push("deleted-user-post");
  if (post.reply_count > 10) classes.push("popular-post");
  
  return classes;
});
```

### Good: Behavior Transformer with Conditional Logic

```javascript
api.registerBehaviorTransformer(
  "discovery-topic-list-load-more",
  ({ next, context }) => {
    const topicList = context.model;
    const siteSettings = api.container.lookup("service:site-settings");
    
    // Check custom setting
    if (siteSettings.limit_topic_loading && topicList.topics.length > 50) {
      console.log("Topic loading limit reached");
      return;
    }
    
    // Proceed with normal loading
    next();
  }
);
```

## Finding Available Transformers

Transformers are registered in Discourse core. To find available transformers:

1. Check the [transformer registry](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/transformer/registry.js)
2. Search core codebase for transformer names to see usage context
3. Check migration guides for new transformers (e.g., post-stream changes)

## Diagnostics/Verification

### Logging Transformer Calls

```javascript
api.registerValueTransformer("post-class", ({ value, context }) => {
  console.log("[Transformer] post-class called");
  console.log("[Transformer] Original value:", value);
  console.log("[Transformer] Context:", context);
  
  const newValue = [...value, "custom-class"];
  console.log("[Transformer] New value:", newValue);
  
  return newValue;
});
```

### Testing Transformers

1. ✅ Verify transformer is called (check console logs)
2. ✅ Verify value/behavior is modified as expected
3. ✅ Test with multiple transformers on same hook
4. ✅ Verify no memory leaks (check DevTools memory profiler)
5. ✅ Test reactive updates (if using tracked properties)

## References

- [Using Transformers Guide](https://meta.discourse.org/t/349954)
- [Post Stream Changes](https://meta.discourse.org/t/372063)
- [Transformer Registry](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/transformer/registry.js)

