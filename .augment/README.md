# Discourse Theme Development Rules

This directory contains coding rules and best practices for Discourse theme component development, validated against 2025 Discourse standards.

## 🚀 Quick Start

1. **New to Discourse themes?** Start here:
   - Read [overview.md](overview.md) for platform updates and index
   - Follow [rules/javascript/glimmer-components.md](rules/javascript/glimmer-components.md)
   - Review [rules/javascript/plugin-outlets.md](rules/javascript/plugin-outlets.md)

2. **Updating existing themes?** Check:
   - [rules/workflow/version-compatibility.md](rules/workflow/version-compatibility.md) - 2025 deprecations
   - [deprecated/widget-system.md](deprecated/widget-system.md) - Widget migration guide

3. **Debugging issues?** See:
   - [rules/core/spa-event-binding.md](rules/core/spa-event-binding.md) - Event handling
   - [rules/core/redirect-loop-avoidance.md](rules/core/redirect-loop-avoidance.md) - Navigation issues

## 📁 Directory Structure

```
.augment/
├── overview.md                    # 📖 Start here - Index and platform updates
├── rules/
│   ├── core/                     # 🎯 Core SPA patterns
│   │   ├── spa-event-binding.md
│   │   ├── redirect-loop-avoidance.md
│   │   └── state-scope.md
│   ├── javascript/               # 💻 Modern JavaScript
│   │   ├── plugin-outlets.md
│   │   ├── value-transformers.md
│   │   ├── glimmer-components.md
│   │   └── api-initializers.md
│   ├── styling/                  # 🎨 SCSS & CSS
│   │   └── scss-guidelines.md
│   ├── configuration/            # ⚙️ Theme config
│   │   ├── settings.md
│   │   ├── about-json.md
│   │   └── localization.md
│   └── workflow/                 # 🔧 Development
│       ├── development-setup.md
│       └── version-compatibility.md
└── deprecated/                   # ⚠️ Do not use
    └── widget-system.md
```

## 🚨 Critical 2025 Updates

### Removed/Deprecated Features

- ❌ **Inline script tags** (Removed Sept 2025) → Use `.gjs` files
- ❌ **Template overrides** (Removed June 2025) → Use wrapper outlets
- ❌ **Widget system** (EOL Q4 2025) → Use Glimmer components
- ❌ `includePostAttributes` → Use `addTrackedPostProperties`

### Modern Patterns (2025)

- ✅ **Glimmer components** with `.gjs` template-tag format
- ✅ **Plugin outlets** with top-level args (`@topic` not `@outletArgs.topic`)
- ✅ **Value transformers** for customizing behavior
- ✅ **Router service** events for navigation

## 📚 Rule Categories

### Core Patterns
Essential patterns for Discourse SPA architecture:
- **SPA Event Binding** - Event delegation and lifecycle
- **Redirect Loop Avoidance** - Navigation guards
- **State Scope** - State management patterns

### JavaScript
Modern JavaScript and component patterns:
- **Plugin Outlets** - Inserting UI into Discourse
- **Value Transformers** - Customizing values and behavior
- **Glimmer Components** - Modern component architecture
- **API Initializers** - Theme initialization

### Styling
SCSS and CSS best practices:
- **SCSS Guidelines** - Variables, theming, responsive design

### Configuration
Theme settings and metadata:
- **Settings** - Configurable theme options
- **About.json** - Theme metadata
- **Localization** - Multi-language support

### Workflow
Development processes:
- **Development Setup** - Local development with Theme CLI
- **Version Compatibility** - Deprecations and migrations

## 🎯 Common Tasks

### Adding a Custom Component
1. Create component: `javascripts/discourse/components/my-component.gjs`
2. Use Glimmer component pattern (see [glimmer-components.md](rules/javascript/glimmer-components.md))
3. Render in outlet (see [plugin-outlets.md](rules/javascript/plugin-outlets.md))

### Customizing Post Display
1. Use value transformers (see [value-transformers.md](rules/javascript/value-transformers.md))
2. Or use plugin outlets (see [plugin-outlets.md](rules/javascript/plugin-outlets.md))
3. **Don't** use widget decorations (deprecated)

### Adding Theme Settings
1. Define in `settings.yml` (see [settings.md](rules/configuration/settings.md))
2. Access in JS: `settings.settingName`
3. Access in SCSS: `$setting-name`

### Handling Page Changes
1. Use router service events (see [spa-event-binding.md](rules/core/spa-event-binding.md))
2. Or use `api.onPageChange()` with guards
3. Avoid redirect loops (see [redirect-loop-avoidance.md](rules/core/redirect-loop-avoidance.md))

## 🔍 Finding Information

### By Topic
- **Events**: [spa-event-binding.md](rules/core/spa-event-binding.md)
- **Navigation**: [redirect-loop-avoidance.md](rules/core/redirect-loop-avoidance.md)
- **State**: [state-scope.md](rules/core/state-scope.md)
- **Components**: [glimmer-components.md](rules/javascript/glimmer-components.md)
- **Outlets**: [plugin-outlets.md](rules/javascript/plugin-outlets.md)
- **Styling**: [scss-guidelines.md](rules/styling/scss-guidelines.md)

### By File Type
- **JavaScript**: See `rules/javascript/`
- **SCSS**: See `rules/styling/`
- **YAML**: See `rules/configuration/`

## ✅ Rule Format

Each rule follows this structure:
1. **Intent** - What and why
2. **When This Applies** - Specific scenarios
3. **Do** - Recommended practices with examples
4. **Don't** - Anti-patterns to avoid
5. **Patterns** - Good/bad comparisons
6. **Diagnostics/Verification** - Testing approaches
7. **References** - Official documentation links

## 📖 External Resources

- [Discourse Meta](https://meta.discourse.org) - Official documentation
- [Theme Developer Tutorial](https://meta.discourse.org/t/357796) - Official tutorial series
- [Plugin API](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/plugin-api.gjs) - API source
- [Dev News](https://meta.discourse.org/tag/dev-news) - Platform updates

## 🔄 Keeping Updated

1. Monitor [version-compatibility.md](rules/workflow/version-compatibility.md)
2. Subscribe to [Discourse dev-news](https://meta.discourse.org/tag/dev-news)
3. Test with deprecation flags enabled
4. Review this directory after Discourse updates

## 📝 Contributing

When adding new rules:
1. Use the standard rule format
2. Add YAML frontmatter with metadata
3. Include code examples (Do/Don't)
4. Link to official documentation
5. Update [overview.md](overview.md) index

---

**Last Updated**: 2025-10-07  
**Discourse Version**: 3.5+ (2025 standards)  
**Total Rules**: 15 files covering all major topics

