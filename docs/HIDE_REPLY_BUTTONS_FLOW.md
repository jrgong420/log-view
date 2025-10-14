# Hide Reply Buttons - Implementation Flow

## Visual Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     Page Change Event                            │
│                  (api.onPageChange)                              │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
                    ┌────────────────┐
                    │ Setting enabled?│
                    └────────┬────────┘
                             │
                    ┌────────┴────────┐
                    │                 │
                   NO                YES
                    │                 │
                    ▼                 ▼
          ┌──────────────────┐  ┌──────────┐
          │ Remove body class│  │Get topic │
          │      EXIT        │  └────┬─────┘
          └──────────────────┘       │
                                     ▼
                              ┌──────────────┐
                              │ Topic exists?│
                              └──────┬───────┘
                                     │
                              ┌──────┴──────┐
                              │             │
                             NO            YES
                              │             │
                              ▼             ▼
                    ┌──────────────────┐  ┌────────────────────┐
                    │ Remove body class│  │Category configured?│
                    │      EXIT        │  └─────────┬──────────┘
                    └──────────────────┘            │
                                             ┌──────┴──────┐
                                             │             │
                                            NO            YES
                                             │             │
                                             ▼             ▼
                                   ┌──────────────────┐  ┌──────────────┐
                                   │ Remove body class│  │Get owner ID  │
                                   │      EXIT        │  └──────┬───────┘
                                   └──────────────────┘         │
                                                                ▼
                                                         ┌──────────────┐
                                                         │Owner exists? │
                                                         └──────┬───────┘
                                                                │
                                                         ┌──────┴──────┐
                                                         │             │
                                                        NO            YES
                                                         │             │
                                                         ▼             ▼
                                               ┌──────────────────┐  ┌──────────────────┐
                                               │ Remove body class│  │Get current user  │
                                               │      EXIT        │  └────────┬─────────┘
                                               └──────────────────┘           │
                                                                              ▼
                                                                    ┌──────────────────────┐
                                                                    │ Viewer = Owner?      │
                                                                    └──────────┬───────────┘
                                                                               │
                                                                    ┌──────────┴──────────┐
                                                                    │                     │
                                                                   YES                   NO
                                                                    │                     │
                                                                    ▼                     ▼
                                                          ┌──────────────────┐  ┌──────────────────┐
                                                          │Remove body class │  │ Add body class   │
                                                          │(show top-level)  │  │(hide top-level)  │
                                                          └────────┬─────────┘  └────────┬─────────┘
                                                                   │                     │
                                                                   └──────────┬──────────┘
                                                                              │
                                                                              ▼
                                                                    ┌──────────────────────┐
                                                                    │ Classify Posts       │
                                                                    │ (owner vs non-owner) │
                                                                    └──────────┬───────────┘
                                                                               │
                                                                               ▼
                                                                    ┌──────────────────────┐
                                                                    │ Setup MutationObserver│
                                                                    │ (for new posts)      │
                                                                    └──────────────────────┘
```

## Two-Part Hiding Mechanism

### Part 1: Top-Level Hiding (Body Class)

```
┌─────────────────────────────────────────────────────────────────┐
│                    Body Class Mechanism                          │
└─────────────────────────────────────────────────────────────────┘

JavaScript Decision:
┌──────────────────────────────────────────────────────────────┐
│ if (!currentUser || currentUser.id !== topicOwnerId) {      │
│   document.body.classList.add('hide-reply-buttons-non-owners')│
│ } else {                                                      │
│   document.body.classList.remove('hide-reply-buttons-non-owners')│
│ }                                                             │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
CSS Application:
┌──────────────────────────────────────────────────────────────┐
│ body.hide-reply-buttons-non-owners {                         │
│   .timeline-footer-controls .create { display: none; }       │
│   .topic-footer-main-buttons .create { display: none; }      │
│ }                                                             │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
Result:
┌──────────────────────────────────────────────────────────────┐
│ Timeline footer "Reply" button: HIDDEN                        │
│ Topic footer "Reply" button: HIDDEN                           │
└──────────────────────────────────────────────────────────────┘
```

### Part 2: Post-Level Hiding (Post Classification)

```
┌─────────────────────────────────────────────────────────────────┐
│                  Post Classification Mechanism                   │
└─────────────────────────────────────────────────────────────────┘

For each post:
┌──────────────────────────────────────────────────────────────┐
│ const post = topic.postStream.posts.find(...)                │
│ const isOwnerPost = post.user_id === topicOwnerId            │
│                                                               │
│ if (isOwnerPost) {                                            │
│   postElement.classList.add('owner-post')                    │
│ } else {                                                      │
│   postElement.classList.add('non-owner-post')                │
│ }                                                             │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
CSS Application:
┌──────────────────────────────────────────────────────────────┐
│ article.topic-post.non-owner-post {                          │
│   nav.post-controls .actions button.reply {                  │
│     display: none !important;                                │
│   }                                                           │
│ }                                                             │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
Result:
┌──────────────────────────────────────────────────────────────┐
│ Owner posts: Reply buttons VISIBLE                            │
│ Non-owner posts: Reply buttons HIDDEN                         │
└──────────────────────────────────────────────────────────────┘
```

## State Transitions

### Scenario: Non-Owner Viewing Topic

```
Initial State:
┌──────────────────────────────────────────────────────────────┐
│ <body>                                                        │
│   <div class="timeline-footer-controls">                     │
│     <button class="create">Reply</button> ← VISIBLE          │
│   </div>                                                      │
│   <article class="topic-post" data-post-number="1">          │
│     <nav class="post-controls">                              │
│       <button class="reply">Reply</button> ← VISIBLE         │
│     </nav>                                                    │
│   </article>                                                  │
│ </body>                                                       │
└──────────────────────────────────────────────────────────────┘

After JavaScript Execution:
┌──────────────────────────────────────────────────────────────┐
│ <body class="hide-reply-buttons-non-owners">                 │
│   <div class="timeline-footer-controls">                     │
│     <button class="create">Reply</button> ← HIDDEN (CSS)     │
│   </div>                                                      │
│   <article class="topic-post owner-post" data-owner-marked="1">│
│     <nav class="post-controls">                              │
│       <button class="reply">Reply</button> ← VISIBLE         │
│     </nav>                                                    │
│   </article>                                                  │
│   <article class="topic-post non-owner-post" data-owner-marked="1">│
│     <nav class="post-controls">                              │
│       <button class="reply">Reply</button> ← HIDDEN (CSS)    │
│     </nav>                                                    │
│   </article>                                                  │
│ </body>                                                       │
└──────────────────────────────────────────────────────────────┘
```

### Scenario: Owner Viewing Topic

```
After JavaScript Execution:
┌──────────────────────────────────────────────────────────────┐
│ <body>  ← NO CLASS                                            │
│   <div class="timeline-footer-controls">                     │
│     <button class="create">Reply</button> ← VISIBLE          │
│   </div>                                                      │
│   <article class="topic-post owner-post" data-owner-marked="1">│
│     <nav class="post-controls">                              │
│       <button class="reply">Reply</button> ← VISIBLE         │
│     </nav>                                                    │
│   </article>                                                  │
│   <article class="topic-post non-owner-post" data-owner-marked="1">│
│     <nav class="post-controls">                              │
│       <button class="reply">Reply</button> ← VISIBLE         │
│     </nav>                                                    │
│   </article>                                                  │
│ </body>                                                       │
└──────────────────────────────────────────────────────────────┘
```

## MutationObserver Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    MutationObserver Setup                        │
└─────────────────────────────────────────────────────────────────┘

Initial Setup:
┌──────────────────────────────────────────────────────────────┐
│ const streamContainer = document.querySelector('.post-stream')│
│ streamObserver = new MutationObserver((mutations) => {...})  │
│ streamObserver.observe(streamContainer, {                    │
│   childList: true,                                            │
│   subtree: true                                               │
│ })                                                            │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
When New Post Added:
┌──────────────────────────────────────────────────────────────┐
│ User clicks "Load More" or "Show Replies"                    │
│           ↓                                                   │
│ Discourse adds new <article> elements                        │
│           ↓                                                   │
│ MutationObserver detects new nodes                           │
│           ↓                                                   │
│ For each new article.topic-post:                             │
│   - Extract post number                                       │
│   - Find post in topic.postStream                            │
│   - Compare post.user_id with topicOwnerId                   │
│   - Add owner-post or non-owner-post class                   │
│   - Set data-owner-marked="1"                                │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
Result:
┌──────────────────────────────────────────────────────────────┐
│ Newly loaded posts are automatically classified              │
│ CSS rules apply immediately                                   │
│ Reply buttons hidden/shown as appropriate                     │
└──────────────────────────────────────────────────────────────┘

Cleanup on Navigation:
┌──────────────────────────────────────────────────────────────┐
│ api.onPageChange() triggered                                  │
│           ↓                                                   │
│ if (streamObserver) {                                         │
│   streamObserver.disconnect()                                │
│   streamObserver = null                                       │
│ }                                                             │
│           ↓                                                   │
│ New observer created for new page                            │
└──────────────────────────────────────────────────────────────┘
```

## Summary

The implementation uses two independent mechanisms:

1. **Body Class** (`hide-reply-buttons-non-owners`)
   - Controls top-level button visibility
   - Based on viewer identity vs topic owner
   - Applied/removed on page changes

2. **Post Classification** (`owner-post` / `non-owner-post`)
   - Controls post-level button visibility
   - Based on post authorship vs topic owner
   - Applied to all posts (initial + dynamically loaded)

Both mechanisms work together to provide comprehensive reply button hiding while maintaining clean separation of concerns.

