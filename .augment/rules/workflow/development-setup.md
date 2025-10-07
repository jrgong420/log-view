---
id: discourse-development-setup
title: Development Workflow and Setup
type: guide
severity: recommended
category: workflow
applies_to: [discourse-theme, development, tooling]
tags: [development, workflow, theme-cli, setup]
last_updated: 2025-10-07
sources:
  - https://meta.discourse.org/t/discourse-theme-cli-console-app-to-help-you-build-themes/82950
  - https://meta.discourse.org/t/theme-developer-tutorial-2-creating-a-remote-theme/357797
---

# Development Workflow and Setup

## Intent

Set up an efficient local development environment for Discourse theme development using the Discourse Theme CLI and modern tooling.

## Prerequisites

### Required Software

- **Ruby** ≥ 2.7 (recommended: 3.3.9 via rbenv)
- **Node.js** ≥ 22 (recommended: 22.x via fnm/nvm)
- **pnpm** (via Corepack: `corepack enable`)
- **Git**

### Discourse Instance

- Local development instance (recommended), OR
- Staging/test instance with admin access

**Note**: Live stylesheet reloads are disabled on production instances. Use a development instance for the best experience.

## Do

### ✅ Install Discourse Theme CLI

```bash
gem install discourse_theme
```

### ✅ Create New Theme

```bash
discourse_theme new my-theme-name
cd my-theme-name
```

This creates the standard theme structure:
```
my-theme-name/
├── about.json
├── settings.yml
├── common/
│   └── common.scss
├── desktop/
│   └── desktop.scss
├── mobile/
│   └── mobile.scss
├── javascripts/
│   └── discourse/
│       └── api-initializers/
├── locales/
│   └── en.yml
└── assets/
```

### ✅ Configure Theme CLI

```bash
discourse_theme watch .
```

Follow prompts to:
1. Enter Discourse URL
2. Enter API key (generate in Admin → API)
3. Select theme to sync

Configuration is saved in `.discourse-site.json`.

### ✅ Use Watch Mode for Live Development

```bash
discourse_theme watch .
```

This automatically syncs changes to your Discourse instance when you save files.

### ✅ Use Package Manager (pnpm)

If your theme has a `package.json`:

```bash
# Install dependencies
pnpm install

# Run scripts
pnpm run lint
pnpm run format
```

### ✅ Use Git for Version Control

```bash
git init
git add .
git commit -m "Initial commit"

# Create GitHub repository and push
git remote add origin https://github.com/username/my-theme.git
git push -u origin main
```

### ✅ Install Theme from Git Repository

In Discourse Admin:
1. Go to Customize → Themes
2. Click "Install"
3. Select "From a git repository"
4. Enter repository URL: `https://github.com/username/my-theme.git`
5. Click "Install"

## Don't

### ❌ Don't Develop Directly in Admin Panel

```
// BAD - editing in browser
Admin → Customize → Themes → Edit CSS/JS
```

Use local files with Theme CLI for:
- Version control
- Better editor support
- Easier collaboration
- Automated syncing

### ❌ Don't Commit .discourse-site.json

```bash
# Add to .gitignore
echo ".discourse-site.json" >> .gitignore
```

This file contains your API key and should not be shared.

### ❌ Don't Test on Production First

Always test on a development or staging instance before deploying to production.

## Development Workflow

### 1. Local Development

```bash
# Start watch mode
discourse_theme watch .

# Make changes to files
# Changes auto-sync to Discourse

# View changes in browser
# Refresh to see updates
```

### 2. Testing

```bash
# Test on different devices
# - Desktop browser
# - Mobile browser
# - Different screen sizes

# Test with different settings
# - Logged in / logged out
# - Different user roles
# - Different color schemes
```

### 3. Version Control

```bash
# Commit changes
git add .
git commit -m "Add custom banner component"

# Push to GitHub
git push origin main

# Discourse auto-updates from Git
# (if installed from repository)
```

### 4. Deployment

```bash
# Tag release
git tag v1.0.0
git push origin v1.0.0

# Update theme in production
# Admin → Customize → Themes → Update
```

## Useful Commands

### Theme CLI Commands

```bash
# Create new theme
discourse_theme new <name>

# Watch for changes
discourse_theme watch <path>

# Download theme from Discourse
discourse_theme download <theme-id>

# Upload theme to Discourse
discourse_theme upload <path>

# List themes
discourse_theme list
```

### Package Management

```bash
# Install dependencies
pnpm install

# Add dependency
pnpm add <package>

# Remove dependency
pnpm remove <package>

# Update dependencies
pnpm update
```

## Debugging Tips

### Enable Developer Toolbar

In browser console:
```javascript
enableDevTools()
```

Features:
- 🔌 Plugin outlet inspector
- 📊 Performance metrics
- 🎨 Color scheme switcher

### Check Console for Errors

Open browser DevTools (F12):
- Console tab: JavaScript errors
- Network tab: Failed requests
- Elements tab: Inspect DOM

### Test with Different Settings

```javascript
// In browser console
// Check current user
console.log(Discourse.User.current());

// Check site settings
console.log(Discourse.SiteSettings);

// Check mobile view
console.log(Discourse.Site.currentProp("mobileView"));
```

## Project Structure Best Practices

```
my-theme/
├── .git/
├── .gitignore
├── .discourse-site.json  # (gitignored)
├── README.md
├── LICENSE
├── about.json
├── settings.yml
├── package.json
├── common/
│   ├── common.scss
│   ├── head_tag.html
│   └── header.html
├── desktop/
│   └── desktop.scss
├── mobile/
│   └── mobile.scss
├── javascripts/
│   └── discourse/
│       ├── api-initializers/
│       │   └── init-my-theme.gjs
│       ├── components/
│       │   ├── custom-banner.gjs
│       │   └── custom-button.gjs
│       └── lib/
│           └── utilities.js
├── locales/
│   ├── en.yml
│   ├── fr.yml
│   └── es.yml
├── assets/
│   ├── logo.svg
│   └── banner.jpg
├── screenshots/
│   ├── desktop.png
│   └── mobile.png
└── stylesheets/
    ├── _variables.scss
    └── _mixins.scss
```

## References

- [Discourse Theme CLI](https://meta.discourse.org/t/82950)
- [Theme Developer Tutorial: Remote Themes](https://meta.discourse.org/t/357797)
- [Developer's Guide to Themes](https://meta.discourse.org/t/93648)

