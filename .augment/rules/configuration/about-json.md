---
id: discourse-about-json
title: Theme Metadata (about.json)
type: rule
severity: required
category: configuration
applies_to: [discourse-theme, metadata, json]
tags: [about.json, metadata, configuration, component]
last_updated: 2025-10-07
sources:
  - https://meta.discourse.org/t/adding-metadata-and-screenshots-to-a-theme/119205
  - https://meta.discourse.org/t/structure-of-themes-and-theme-components/60848
---

# Theme Metadata (about.json)

## Intent

Define theme metadata, assets, and configuration in `about.json`. This file is required for all themes and theme components, providing essential information about the theme to Discourse.

## When This Applies

- When creating a new theme or theme component
- When adding assets (images, fonts) to a theme
- When specifying version compatibility
- When documenting theme authorship and licensing

## Required Fields

```json
{
  "name": "My Theme Component",
  "component": true,
  "authors": "Your Name"
}
```

## Do

### ✅ Include All Recommended Metadata

```json
{
  "name": "My Awesome Theme",
  "component": true,
  "authors": "John Doe",
  "about_url": "https://github.com/username/my-theme",
  "license_url": "https://github.com/username/my-theme/blob/main/LICENSE",
  "theme_version": "1.2.0",
  "minimum_discourse_version": "3.2.0",
  "maximum_discourse_version": null
}
```

### ✅ Declare Assets

```json
{
  "name": "My Theme",
  "component": true,
  "authors": "John Doe",
  "assets": {
    "hero-image": "assets/hero.png",
    "custom-font": "assets/fonts/custom.woff2",
    "icon": "assets/icon.svg"
  }
}
```

Access in SCSS:
```scss
.hero {
  background-image: url($hero-image);
}

@font-face {
  font-family: "CustomFont";
  src: url($custom-font);
}
```

### ✅ Add Screenshots

```json
{
  "name": "My Theme",
  "component": true,
  "authors": "John Doe",
  "screenshots": [
    "screenshots/light-mode.png",
    "screenshots/dark-mode.png"
  ]
}
```

Requirements:
- Maximum 2 screenshots
- Max file size: 1MB each
- Max dimensions: 3840×2160
- Formats: JPEG, GIF, PNG

### ✅ Use Themeable Site Settings (New Feature)

```json
{
  "name": "My Theme",
  "component": true,
  "authors": "John Doe",
  "theme_site_settings": {
    "enable_welcome_banner": false,
    "show_topic_thumbnails": true
  }
}
```

Access in JavaScript:
```javascript
const siteSettings = api.container.lookup("service:site-settings");
console.log(siteSettings.enable_welcome_banner);
```

### ✅ Specify Version Compatibility

```json
{
  "name": "My Theme",
  "component": true,
  "authors": "John Doe",
  "minimum_discourse_version": "3.2.0",
  "theme_version": "2.1.0"
}
```

## Don't

### ❌ Don't Forget Required Fields

```json
// BAD - missing required fields
{
  "name": "My Theme"
}
```

```json
// GOOD - all required fields
{
  "name": "My Theme",
  "component": true,
  "authors": "John Doe"
}
```

### ❌ Don't Use Invalid JSON

```json
// BAD - trailing comma
{
  "name": "My Theme",
  "component": true,
}
```

```json
// GOOD - valid JSON
{
  "name": "My Theme",
  "component": true
}
```

## Complete Example

```json
{
  "name": "Custom Community Theme",
  "component": true,
  "authors": "Jane Smith",
  "about_url": "https://github.com/janesmith/custom-theme",
  "license_url": "https://github.com/janesmith/custom-theme/blob/main/LICENSE",
  "theme_version": "1.5.2",
  "minimum_discourse_version": "3.2.0",
  "maximum_discourse_version": null,
  "assets": {
    "logo": "assets/logo.svg",
    "banner": "assets/banner.jpg",
    "custom-font": "assets/fonts/roboto.woff2"
  },
  "screenshots": [
    "screenshots/desktop-view.png",
    "screenshots/mobile-view.png"
  ],
  "theme_site_settings": {
    "show_welcome_banner": true,
    "enable_custom_navigation": false
  },
  "color_schemes": {
    "Custom Dark": {
      "primary": "dddddd",
      "secondary": "222222",
      "tertiary": "3498db",
      "quaternary": "34495e",
      "header_background": "1a1a1a",
      "header_primary": "ffffff",
      "highlight": "e67e22",
      "danger": "e74c3c",
      "success": "27ae60",
      "love": "e91e63"
    }
  }
}
```

## References

- [Adding Metadata to a Theme](https://meta.discourse.org/t/119205)
- [Structure of Themes](https://meta.discourse.org/t/60848)
- [Themeable Site Settings](https://meta.discourse.org/t/374376)

