# Embedded Reply Button Positioning Fix

## Problem

The section-level reply button was not properly positioned next to the collapse button. The issue was that:

1. The collapse button might be a direct child of `section.embedded-posts` or wrapped in a container
2. Simply inserting the reply button as a sibling didn't ensure proper horizontal alignment
3. No flex container was guaranteed to exist for proper layout

## Solution

### 1. Smart Container Detection and Creation

The injection logic now:

1. **Detects the collapse button's parent**
2. **Checks if it's the section itself or a container**
3. **Creates a wrapper if needed** to ensure both buttons are in a flex container

### 2. Three Scenarios Handled

#### Scenario A: Collapse button is direct child of section
```javascript
if (buttonContainer === section) {
  // Create wrapper div
  const wrapper = document.createElement("div");
  wrapper.className = "embedded-posts-controls";
  
  // Insert wrapper before collapse button
  section.insertBefore(wrapper, collapseButton);
  
  // Move collapse button into wrapper
  wrapper.appendChild(collapseButton);
  
  // Insert reply button before collapse button
  wrapper.insertBefore(btn, collapseButton);
}
```

**Result:**
```html
<section class="embedded-posts">
  <!-- embedded posts -->
  <div class="embedded-posts-controls">
    <button class="embedded-reply-button">Reply</button>
    <button class="collapse-up">↑</button>
  </div>
</section>
```

#### Scenario B: Collapse button is already in a container
```javascript
else {
  // Insert button into existing container
  buttonContainer.insertBefore(btn, collapseButton);
  
  // Add our class for consistent styling
  if (!buttonContainer.classList.contains("embedded-posts-controls")) {
    buttonContainer.classList.add("embedded-posts-controls");
  }
}
```

**Result:**
```html
<section class="embedded-posts">
  <!-- embedded posts -->
  <div class="some-existing-container embedded-posts-controls">
    <button class="embedded-reply-button">Reply</button>
    <button class="collapse-up">↑</button>
  </div>
</section>
```

#### Scenario C: No collapse button found (fallback)
```javascript
else {
  // Create container with just reply button
  const wrapper = document.createElement("div");
  wrapper.className = "embedded-posts-controls";
  wrapper.appendChild(btn);
  section.appendChild(wrapper);
}
```

**Result:**
```html
<section class="embedded-posts">
  <!-- embedded posts -->
  <div class="embedded-posts-controls">
    <button class="embedded-reply-button">Reply</button>
  </div>
</section>
```

## CSS Changes

### New Container Class: `.embedded-posts-controls`

```scss
.embedded-posts-controls {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  margin-top: 1rem;
  padding: 0.5rem;
}
```

**Key properties:**
- `display: flex` - Enables flexbox layout
- `align-items: center` - Vertically centers buttons
- `justify-content: center` - Horizontally centers the button group
- `gap: 0.5rem` - Consistent spacing between buttons
- `margin-top: 1rem` - Separates from embedded posts above
- `padding: 0.5rem` - Adds breathing room

### Updated Button Styles

```scss
.embedded-reply-button {
  padding: 0.25rem 0.75rem;
  font-size: var(--font-down-1);
  background-color: var(--tertiary);
  color: var(--secondary);
  border: 1px solid var(--tertiary);
  border-radius: 4px;
  cursor: pointer;
  transition: all 0.2s ease;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  white-space: nowrap;  // Prevents text wrapping
}
```

**Removed:** `margin-right: 0.5rem` (now handled by flex gap)
**Added:** `white-space: nowrap` (prevents "Reply" from wrapping)

### Section Layout

```scss
section.embedded-posts {
  > .embedded-posts-controls {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.5rem;
  }
}
```

Ensures the controls container is always properly styled, even if created dynamically.

## Visual Result

### Before Fix
```
┌─────────────────────────────────────┐
│ section.embedded-posts              │
│                                     │
│ [Embedded Post 1]                   │
│ [Embedded Post 2]                   │
│ [Embedded Post 3]                   │
│                                     │
│ [Reply]                             │  ← Misaligned
│        [Collapse ▲]                 │  ← Separate
└─────────────────────────────────────┘
```

### After Fix
```
┌─────────────────────────────────────┐
│ section.embedded-posts              │
│                                     │
│ [Embedded Post 1]                   │
│ [Embedded Post 2]                   │
│ [Embedded Post 3]                   │
│                                     │
│    [Reply] [Collapse ▲]             │  ← Properly aligned
│    └─ Flex Container ─┘             │
└─────────────────────────────────────┘
```

## Benefits

1. **Guaranteed Alignment** - Flex container ensures buttons are always horizontally aligned
2. **Centered Layout** - Buttons are centered in the section for visual balance
3. **Consistent Spacing** - Gap property ensures uniform spacing
4. **Flexible** - Works whether collapse button is wrapped or not
5. **Clean DOM** - Creates minimal wrapper only when needed

## Testing

To verify the fix works:

1. ✅ Expand embedded posts section
2. ✅ Verify Reply button appears to the left of Collapse button
3. ✅ Verify both buttons are horizontally aligned
4. ✅ Verify both buttons are centered in the section
5. ✅ Verify consistent spacing between buttons
6. ✅ Check console logs for proper container creation
7. ✅ Test on different screen sizes

## Console Logs

### When creating new container:
```
[Embedded Reply Buttons] Created button container and injected reply button
```

### When using existing container:
```
[Embedded Reply Buttons] Injected reply button into existing container
```

### When collapse button not found:
```
[Embedded Reply Buttons] Created button container at end of section (collapse button not found)
```

## Files Modified

1. `javascripts/discourse/api-initializers/embedded-reply-buttons.gjs` (lines 143-184)
2. `common/common.scss` (lines 128-197)

