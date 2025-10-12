# Reply Button Positioning - Visual Guide

## Final Layout

```
┌───────────────────────────────────────────────────────────────┐
│ article.topic-post (Owner's Post)                             │
│                                                               │
│ "This is the owner's post content..."                        │
│                                                               │
│ ┌─────────────────────────────────────────────────────────┐   │
│ │ section.embedded-posts                                  │   │
│ │                                                         │   │
│ │ ┌─────────────────────────────────────────────────────┐ │   │
│ │ │ Embedded Post #2                                    │ │   │
│ │ │ "Reply to owner..."                                 │ │   │
│ │ └─────────────────────────────────────────────────────┘ │   │
│ │                                                         │   │
│ │ ┌─────────────────────────────────────────────────────┐ │   │
│ │ │ Embedded Post #3                                    │ │   │
│ │ │ "Another reply..."                                  │ │   │
│ │ └─────────────────────────────────────────────────────┘ │   │
│ │                                                         │   │
│ │ ┌─────────────────────────────────────────────────────┐ │   │
│ │ │ div.embedded-posts-controls (Flex Container)        │ │   │
│ │ │                                                     │ │   │
│ │ │        ┌───────┐  ┌─────────────┐                  │ │   │
│ │ │        │ Reply │  │ Collapse ▲  │                  │ │   │
│ │ │        └───────┘  └─────────────┘                  │ │   │
│ │ │           ↑            ↑                            │ │   │
│ │ │           │            │                            │ │   │
│ │ │      .embedded-   .collapse-up                     │ │   │
│ │ │      reply-button                                  │ │   │
│ │ └─────────────────────────────────────────────────────┘ │   │
│ └─────────────────────────────────────────────────────────┘   │
└───────────────────────────────────────────────────────────────┘
```

## DOM Structure

```html
<article class="topic-post" data-post-number="1">
  <div class="topic-body">
    <!-- Owner's post content -->
  </div>
  
  <section class="embedded-posts" data-reply-btn-bound="1">
    <!-- Embedded post items -->
    <div class="embedded-post" data-post-number="2">
      <div class="post-info">...</div>
      <div class="post-content">Reply to owner...</div>
    </div>
    
    <div class="embedded-post" data-post-number="3">
      <div class="post-info">...</div>
      <div class="post-content">Another reply...</div>
    </div>
    
    <!-- Button container (created by our code) -->
    <div class="embedded-posts-controls">
      <button 
        class="btn btn-small embedded-reply-button" 
        data-owner-post-number="1"
        type="button"
        title="Reply to owner's post"
        aria-label="Reply to owner's post">
        Reply
      </button>
      
      <button 
        class="widget-button btn collapse-up no-text btn-icon"
        title="collapse"
        aria-label="Collapse embedded replies">
        <svg class="fa d-icon d-icon-chevron-up svg-icon svg-string">
          <use href="#chevron-up"></use>
        </svg>
      </button>
    </div>
  </section>
</article>
```

## CSS Layout Breakdown

### Container (`.embedded-posts-controls`)

```scss
.embedded-posts-controls {
  display: flex;              // Flexbox layout
  align-items: center;        // Vertical centering
  justify-content: center;    // Horizontal centering
  gap: 0.5rem;               // 8px space between buttons
  margin-top: 1rem;          // 16px space from posts above
  padding: 0.5rem;           // 8px padding around buttons
}
```

**Visual:**
```
┌─────────────────────────────────────────────┐
│ .embedded-posts-controls                    │
│ ┌─────────────────────────────────────────┐ │ ← padding: 0.5rem
│ │                                         │ │
│ │     [Reply]  ←gap→  [Collapse ▲]       │ │ ← justify-content: center
│ │        ↑                                │ │
│ │        └─ align-items: center           │ │
│ └─────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
     ↑
     margin-top: 1rem (from posts above)
```

### Reply Button (`.embedded-reply-button`)

```scss
.embedded-reply-button {
  padding: 0.25rem 0.75rem;   // 4px top/bottom, 12px left/right
  font-size: var(--font-down-1);
  background-color: var(--tertiary);
  color: var(--secondary);
  border: 1px solid var(--tertiary);
  border-radius: 4px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  white-space: nowrap;        // Prevents "Reply" from wrapping
}
```

**Visual:**
```
┌─────────────────┐
│  ←12px→ ←12px→  │
│    ↑            │
│   4px           │
│    ↓            │
│   Reply         │ ← white-space: nowrap
│    ↑            │
│   4px           │
│    ↓            │
└─────────────────┘
```

## Alignment Details

### Horizontal Alignment

Both buttons are in a flex container with `justify-content: center`:

```
        Section Width
┌───────────────────────────────┐
│                               │
│    [Reply] [Collapse ▲]       │
│       ↑         ↑             │
│       └─────────┘             │
│     Centered Group            │
└───────────────────────────────┘
```

### Vertical Alignment

Both buttons are vertically centered with `align-items: center`:

```
Container Height
┌─────────────────┐
│                 │ ← Top padding
│  [Reply] [↑]    │ ← Buttons centered
│                 │ ← Bottom padding
└─────────────────┘
```

### Spacing Between Buttons

The `gap: 0.5rem` property creates consistent spacing:

```
[Reply]  ←─ 0.5rem (8px) ─→  [Collapse ▲]
```

## Responsive Behavior

The flex container automatically adjusts:

### Desktop
```
┌─────────────────────────────────────┐
│                                     │
│      [Reply]  [Collapse ▲]          │
│                                     │
└─────────────────────────────────────┘
```

### Mobile (if needed, buttons stay horizontal)
```
┌───────────────────┐
│                   │
│ [Reply] [Collapse]│
│                   │
└───────────────────┘
```

## Hover States

### Reply Button Hover
```scss
&:hover {
  background-color: var(--tertiary-hover);
  filter: brightness(0.9);
  transform: translateY(-1px);  // Lifts up slightly
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}
```

**Visual:**
```
Before Hover:
[Reply]

During Hover:
┌─────────┐
│  Reply  │ ← Lifted 1px
└─────────┘
    ↓
  shadow
```

## Color Scheme

### Reply Button
- **Background**: `var(--tertiary)` (theme's tertiary color, usually blue)
- **Text**: `var(--secondary)` (theme's secondary color, usually white)
- **Border**: `var(--tertiary)`

### Collapse Button
- **Background**: Default Discourse button style
- **Icon**: SVG chevron-up

## Accessibility

Both buttons have proper ARIA attributes:

```html
<!-- Reply Button -->
<button 
  aria-label="Reply to owner's post"
  title="Reply to owner's post">
  Reply
</button>

<!-- Collapse Button -->
<button 
  aria-label="Collapse embedded replies"
  title="collapse">
  <svg>...</svg>
</button>
```

## Browser Compatibility

The flex layout works in all modern browsers:
- ✅ Chrome/Edge (Chromium)
- ✅ Firefox
- ✅ Safari
- ✅ Mobile browsers

## Summary

The positioning fix ensures:
1. ✅ Buttons are always horizontally aligned
2. ✅ Buttons are centered in the section
3. ✅ Consistent spacing between buttons (0.5rem gap)
4. ✅ Proper vertical alignment
5. ✅ Clean, semantic HTML structure
6. ✅ Responsive and accessible

