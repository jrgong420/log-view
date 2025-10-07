---
id: discourse-localization
title: Localization and Translations
type: rule
severity: recommended
category: configuration
applies_to: [discourse-theme, i18n, localization]
tags: [i18n, localization, translations, themePrefix]
last_updated: 2025-10-07
sources:
  - https://meta.discourse.org/t/adding-localizable-strings-to-themes-and-theme-components/109867
  - https://meta.discourse.org/t/theme-developer-quick-reference-guide/110448
---

# Localization and Translations

## Intent

Provide multilingual support for themes by defining translatable strings in locale files. This allows themes to display text in the user's preferred language and makes themes more accessible to international communities.

## When This Applies

- When displaying user-facing text in themes
- When creating buttons, labels, or messages
- When providing setting descriptions
- When supporting multiple languages

## Do

### ✅ Define Translations in locales/en.yml

```yaml
# locales/en.yml
en:
  js:
    my_theme:
      welcome_message: "Welcome to our community!"
      button_label: "Click Here"
      post_count:
        one: "%{count} post"
        other: "%{count} posts"
  
  theme_metadata:
    description: "A custom theme for our community"
    settings:
      feature_enabled: "Enable the custom feature"
      banner_text: "Customize the welcome banner text"
```

### ✅ Use themePrefix() Helper in JavaScript

```javascript
import { apiInitializer } from "discourse/lib/api";
import { i18n } from "discourse-i18n";

export default apiInitializer((api) => {
  const welcomeMessage = i18n(themePrefix("js.my_theme.welcome_message"));
  console.log(welcomeMessage); // "Welcome to our community!"
  
  const postCount = i18n(themePrefix("js.my_theme.post_count"), { count: 5 });
  console.log(postCount); // "5 posts"
});
```

### ✅ Use in Templates

```javascript
import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";

export default class WelcomeBanner extends Component {
  <template>
    <div class="welcome-banner">
      <h3>{{i18n (themePrefix "js.my_theme.welcome_message")}}</h3>
      <button>
        {{i18n (themePrefix "js.my_theme.button_label")}}
      </button>
    </div>
  </template>
}
```

### ✅ Use with DButton Component

```javascript
import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";
import DButton from "discourse/components/d-button";

export default class ActionButton extends Component {
  get translatedLabel() {
    return i18n(themePrefix("js.my_theme.button_label"));
  }
  
  <template>
    {{! Option 1: Pre-translated label }}
    <DButton
      @translatedLabel={{this.translatedLabel}}
      @action={{@onClick}}
    />
    
    {{! Option 2: Let DButton translate }}
    <DButton
      @label={{themePrefix "js.my_theme.button_label"}}
      @action={{@onClick}}
    />
  </template>
}
```

### ✅ Support Multiple Languages

```yaml
# locales/en.yml
en:
  js:
    my_theme:
      greeting: "Hello"

# locales/fr.yml
fr:
  js:
    my_theme:
      greeting: "Bonjour"

# locales/es.yml
es:
  js:
    my_theme:
      greeting: "Hola"
```

### ✅ Use Interpolation

```yaml
# locales/en.yml
en:
  js:
    my_theme:
      user_greeting: "Welcome, %{username}!"
      items_count: "Showing %{current} of %{total} items"
```

```javascript
const greeting = i18n(themePrefix("js.my_theme.user_greeting"), {
  username: currentUser.username
});

const itemsInfo = i18n(themePrefix("js.my_theme.items_count"), {
  current: 10,
  total: 50
});
```

### ✅ Use Pluralization

```yaml
# locales/en.yml
en:
  js:
    my_theme:
      likes:
        zero: "No likes"
        one: "1 like"
        other: "%{count} likes"
```

```javascript
const likesText = i18n(themePrefix("js.my_theme.likes"), { count: 0 }); // "No likes"
const likesText = i18n(themePrefix("js.my_theme.likes"), { count: 1 }); // "1 like"
const likesText = i18n(themePrefix("js.my_theme.likes"), { count: 5 }); // "5 likes"
```

## Don't

### ❌ Don't Hardcode User-Facing Text

```javascript
// BAD - not translatable
<template>
  <button>Click Here</button>
</template>
```

```javascript
// GOOD - translatable
<template>
  <button>{{i18n (themePrefix "js.my_theme.button_label")}}</button>
</template>
```

### ❌ Don't Include theme_translations Prefix Manually

```javascript
// BAD - themePrefix adds this automatically
const text = i18n("theme_translations.123.js.my_theme.greeting");
```

```javascript
// GOOD - themePrefix handles the prefix
const text = i18n(themePrefix("js.my_theme.greeting"));
```

### ❌ Don't Forget Pluralization Forms

```yaml
# BAD - missing plural forms
en:
  js:
    my_theme:
      items: "%{count} items"

# GOOD - includes all forms
en:
  js:
    my_theme:
      items:
        zero: "No items"
        one: "1 item"
        other: "%{count} items"
```

## Patterns

### Good: Complete Localization Setup

```yaml
# locales/en.yml
en:
  js:
    custom_feature:
      title: "Custom Feature"
      description: "This is a custom feature"
      actions:
        enable: "Enable"
        disable: "Disable"
        save: "Save Changes"
      messages:
        success: "Changes saved successfully!"
        error: "An error occurred: %{message}"
      status:
        enabled: "Enabled"
        disabled: "Disabled"
  
  theme_metadata:
    description: "Adds custom features to your Discourse"
    settings:
      show_feature: "Display the custom feature"
      feature_title: "Customize the feature title"
```

```javascript
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { i18n } from "discourse-i18n";
import DButton from "discourse/components/d-button";

export default class CustomFeature extends Component {
  @tracked isEnabled = false;
  
  get statusText() {
    const key = this.isEnabled ? "enabled" : "disabled";
    return i18n(themePrefix(`js.custom_feature.status.${key}`));
  }
  
  @action
  async toggle() {
    try {
      this.isEnabled = !this.isEnabled;
      const message = i18n(themePrefix("js.custom_feature.messages.success"));
      alert(message);
    } catch (error) {
      const message = i18n(themePrefix("js.custom_feature.messages.error"), {
        message: error.message
      });
      alert(message);
    }
  }
  
  <template>
    <div class="custom-feature">
      <h3>{{i18n (themePrefix "js.custom_feature.title")}}</h3>
      <p>{{i18n (themePrefix "js.custom_feature.description")}}</p>
      <p>Status: {{this.statusText}}</p>
      
      <DButton
        @label={{themePrefix (if this.isEnabled "js.custom_feature.actions.disable" "js.custom_feature.actions.enable")}}
        @action={{this.toggle}}
      />
    </div>
  </template>
}
```

### Good: Multi-Language Support

```yaml
# locales/en.yml
en:
  js:
    my_theme:
      welcome: "Welcome!"
      goodbye: "Goodbye!"

# locales/fr.yml
fr:
  js:
    my_theme:
      welcome: "Bienvenue!"
      goodbye: "Au revoir!"

# locales/de.yml
de:
  js:
    my_theme:
      welcome: "Willkommen!"
      goodbye: "Auf Wiedersehen!"
```

## Diagnostics/Verification

### Testing Translations

1. ✅ Change site language in user preferences
2. ✅ Verify all text updates to new language
3. ✅ Test pluralization with different counts
4. ✅ Test interpolation with different values
5. ✅ Check for missing translation warnings in console

### Debugging Translations

```javascript
// Log translation key and result
const key = themePrefix("js.my_theme.greeting");
const translation = i18n(key);
console.log(`Key: ${key}`);
console.log(`Translation: ${translation}`);

// Check if translation exists
if (translation === key) {
  console.warn("Translation missing for:", key);
}
```

## References

- [Adding Localizable Strings](https://meta.discourse.org/t/109867)
- [Theme Developer Quick Reference](https://meta.discourse.org/t/110448)
- [I18n in Discourse](https://meta.discourse.org/t/how-to-add-a-new-language/14970)

