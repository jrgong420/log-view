# Reply Button Placement - Before vs After

## Before: Multiple Buttons (Per-Item)

```
┌─────────────────────────────────────────────────────┐
│ article.topic-post (Owner's Post #1)                │
│                                                     │
│ "This is the owner's post content..."              │
│                                                     │
│ ┌─────────────────────────────────────────────────┐ │
│ │ section.embedded-posts                          │ │
│ │                                                 │ │
│ │ ┌─────────────────────────────────────────────┐ │ │
│ │ │ Embedded Post #2                            │ │ │
│ │ │ "Reply to owner's post..."                  │ │ │
│ │ │ [Reply] ← Button for this post              │ │ │
│ │ └─────────────────────────────────────────────┘ │ │
│ │                                                 │ │
│ │ ┌─────────────────────────────────────────────┐ │ │
│ │ │ Embedded Post #3                            │ │ │
│ │ │ "Another reply..."                          │ │ │
│ │ │ [Reply] ← Button for this post              │ │ │
│ │ └─────────────────────────────────────────────┘ │ │
│ │                                                 │ │
│ │ ┌─────────────────────────────────────────────┐ │ │
│ │ │ Embedded Post #4                            │ │ │
│ │ │ "Yet another reply..."                      │ │ │
│ │ │ [Reply] ← Button for this post              │ │ │
│ │ └─────────────────────────────────────────────┘ │ │
│ │                                                 │ │
│ │ [Collapse ▲]                                    │ │
│ └─────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────┘
```

**Issues:**
- 3 reply buttons (one per embedded post)
- Cluttered interface
- User must choose which post to reply to
- Each button replies to its specific embedded post

---

## After: Single Button (Section-Level)

```
┌─────────────────────────────────────────────────────┐
│ article.topic-post (Owner's Post #1)                │
│                                                     │
│ "This is the owner's post content..."              │
│                                                     │
│ ┌─────────────────────────────────────────────────┐ │
│ │ section.embedded-posts                          │ │
│ │                                                 │ │
│ │ ┌─────────────────────────────────────────────┐ │ │
│ │ │ Embedded Post #2                            │ │ │
│ │ │ "Reply to owner's post..."                  │ │ │
│ │ │                                             │ │ │
│ │ └─────────────────────────────────────────────┘ │ │
│ │                                                 │ │
│ │ ┌─────────────────────────────────────────────┐ │ │
│ │ │ Embedded Post #3                            │ │ │
│ │ │ "Another reply..."                          │ │ │
│ │ │                                             │ │ │
│ │ └─────────────────────────────────────────────┘ │ │
│ │                                                 │ │
│ │ ┌─────────────────────────────────────────────┐ │ │
│ │ │ Embedded Post #4                            │ │ │
│ │ │ "Yet another reply..."                      │ │ │
│ │ │                                             │ │ │
│ │ └─────────────────────────────────────────────┘ │ │
│ │                                                 │ │
│ │ [Reply] [Collapse ▲] ← Single button at bottom │ │
│ └─────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────┘
```

**Benefits:**
- **1 reply button** per section (clean interface)
- Positioned next to collapse button (consistent location)
- Replies to **owner's post** (Post #1 in this example)
- Clear, uncluttered design

---

## DOM Structure

### Button Placement in DOM

```html
<article class="topic-post" data-post-number="1">
  <!-- Owner's post content -->
  
  <section class="embedded-posts" data-reply-btn-bound="1">
    <!-- Embedded post items -->
    <div class="embedded-post" data-post-number="2">...</div>
    <div class="embedded-post" data-post-number="3">...</div>
    <div class="embedded-post" data-post-number="4">...</div>
    
    <!-- Section footer with buttons -->
    <button 
      class="btn btn-small embedded-reply-button" 
      data-owner-post-number="1"
      title="Reply to owner's post"
      aria-label="Reply to owner's post">
      Reply
    </button>
    
    <button 
      class="widget-button btn collapse-up no-text btn-icon"
      title="collapse"
      aria-label="Collapse embedded replies">
      <svg>...</svg> <!-- chevron-up icon -->
    </button>
  </section>
</article>
```

---

## Click Flow

### User clicks "Reply" button

1. **Event captured** by delegated click handler
2. **Extract owner post number** from `data-owner-post-number` attribute
3. **Find owner post model** in topic's post stream
4. **Open composer** with:
   - `action: "reply"`
   - `post: ownerPost` (Post #1)
   - `replyToPostNumber: 1`
5. **Store context** for auto-refresh: `{ topicId, parentPostNumber: 1, ownerPostNumber: 1 }`

### After user submits reply

1. **Composer saves** the new post
2. **Auto-refresh triggers** via `composer:saved` event
3. **Find owner post** element (Post #1)
4. **Click "load more replies"** button in embedded section
5. **Section refreshes** to show the new reply

---

## Styling

### CSS for Button Positioning

```scss
.embedded-reply-button {
  margin-right: 0.5rem;  // Space before collapse button
  display: inline-flex;
  align-items: center;
  vertical-align: middle;
  // ... other styles
}

section.embedded-posts {
  > footer,
  > .embedded-posts-footer,
  > .embedded-posts__footer {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }
}
```

This ensures the Reply button and Collapse button are:
- Aligned horizontally
- Properly spaced
- Vertically centered

