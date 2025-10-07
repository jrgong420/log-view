---
id: discourse-scss-guidelines
title: SCSS Styling Guidelines for Discourse Themes
type: rule
severity: recommended
category: styling
applies_to: [discourse-theme, scss, css]
tags: [scss, styling, css, variables]
last_updated: 2025-10-07
sources:
  - https://meta.discourse.org/t/theme-developer-tutorial-3-css-in-themes/357798
  - https://github.com/discourse/discourse/blob/master/app/assets/stylesheets/color_definitions.scss
---

# SCSS Styling Guidelines for Discourse Themes

## Intent

Provide consistent, maintainable styling for Discourse themes using SCSS. Leverage Discourse's built-in variables and color system for themes that adapt to different color schemes and maintain visual consistency with core Discourse.

## When This Applies

- When adding custom styles to a theme
- When styling custom components
- When overriding or extending core Discourse styles
- When creating responsive layouts

## File Structure

```
common/
  common.scss          # Styles for all devices
  head_tag.html        # <head> content
  header.html          # After <body> opening
  after_header.html    # After site header
  body_tag.html        # Before </body>
  footer.html          # In footer

desktop/
  desktop.scss         # Desktop-only styles

mobile/
  mobile.scss          # Mobile-only styles

stylesheets/
  custom-component.scss  # Importable partials
```

## Do

### ✅ Use Discourse Core Variables

```scss
// common/common.scss
.custom-banner {
  background-color: var(--primary-very-low);
  color: var(--primary);
  border: 1px solid var(--primary-low);
  padding: 1em;
  
  a {
    color: var(--tertiary);
    
    &:hover {
      color: var(--tertiary-hover);
    }
  }
}
```

### ✅ Access Theme Settings in SCSS

Settings from `settings.yml` are available as SCSS variables:

```yaml
# settings.yml
banner_background:
  type: string
  default: "#f0f0f0"
  
banner_padding:
  type: integer
  default: 20
```

```scss
// common/common.scss
.custom-banner {
  background-color: $banner-background;
  padding: #{$banner-padding}px;
}
```

### ✅ Use Device-Specific Styles

```scss
// desktop/desktop.scss
.custom-sidebar {
  width: 300px;
  float: right;
}

// mobile/mobile.scss
.custom-sidebar {
  width: 100%;
  margin-top: 1em;
}
```

### ✅ Scope Styles to Avoid Conflicts

```scss
// Prefix with unique class
.my-theme-custom-banner {
  // Styles here won't conflict with other themes
}

// Or use nested selectors
.custom-feature {
  .banner {
    // Scoped to .custom-feature context
  }
}
```

### ✅ Use Color Transformations

```scss
@import "color_definitions";

.custom-element {
  background-color: dark-light-choose($primary-low, $secondary-high);
  color: dark-light-diff($primary, $secondary, 50%, -50%);
}
```

### ✅ Import Partial Stylesheets

```scss
// stylesheets/_variables.scss
$custom-spacing: 1.5em;
$custom-radius: 4px;

// common/common.scss
@import "variables";

.custom-card {
  padding: $custom-spacing;
  border-radius: $custom-radius;
}
```

## Don't

### ❌ Don't Use Hardcoded Colors

```scss
// BAD - doesn't adapt to color schemes
.banner {
  background-color: #ffffff;
  color: #000000;
}
```

```scss
// GOOD - uses Discourse variables
.banner {
  background-color: var(--secondary);
  color: var(--primary);
}
```

### ❌ Don't Use !important Excessively

```scss
// BAD - makes styles hard to override
.custom-element {
  color: red !important;
  font-size: 16px !important;
}
```

```scss
// GOOD - use specificity instead
.custom-feature .custom-element {
  color: var(--danger);
  font-size: 1rem;
}
```

### ❌ Don't Override Core Styles Broadly

```scss
// BAD - affects all buttons site-wide
button {
  border-radius: 0;
}
```

```scss
// GOOD - scope to your feature
.custom-feature button {
  border-radius: 0;
}
```

## Common Discourse CSS Variables

### Colors
- `--primary` - Primary text color
- `--secondary` - Background color
- `--tertiary` - Link color
- `--quaternary` - Navigation background
- `--header_background` - Header background
- `--header_primary` - Header text
- `--highlight` - Highlight color
- `--danger` - Error/danger color
- `--success` - Success color
- `--love` - Like color

### Shades
- `--primary-low` - Lighter primary
- `--primary-medium` - Medium primary
- `--primary-high` - Darker primary
- `--primary-very-high` - Very dark primary

### Functional
- `--d-border-radius` - Standard border radius
- `--d-button-border-radius` - Button border radius
- `--d-nav-pill-border-radius` - Nav pill radius

## Patterns

### Good: Responsive Component

```scss
.custom-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: 1em;
  padding: 1em;
  
  @media (max-width: 768px) {
    grid-template-columns: 1fr;
  }
}
```

### Good: Theme-Aware Styling

```scss
.custom-card {
  background-color: var(--secondary);
  border: 1px solid var(--primary-low);
  border-radius: var(--d-border-radius);
  padding: 1.5em;
  
  &:hover {
    background-color: var(--primary-very-low);
    border-color: var(--primary-medium);
  }
  
  .card-title {
    color: var(--primary);
    font-size: 1.25em;
    margin-bottom: 0.5em;
  }
  
  .card-link {
    color: var(--tertiary);
    
    &:hover {
      color: var(--tertiary-hover);
    }
  }
}
```

### Good: Using Settings

```scss
// settings.yml: enable_shadows (bool), shadow_intensity (integer)

.custom-element {
  @if $enable-shadows {
    box-shadow: 0 2px #{$shadow-intensity}px rgba(0, 0, 0, 0.1);
  }
}
```

## References

- [Theme Developer Tutorial: CSS](https://meta.discourse.org/t/357798)
- [Color Definitions](https://github.com/discourse/discourse/blob/master/app/assets/stylesheets/color_definitions.scss)
- [Color Transformations](https://github.com/discourse/discourse/blob/master/app/assets/stylesheets/common/foundation/color_transformations.scss)

