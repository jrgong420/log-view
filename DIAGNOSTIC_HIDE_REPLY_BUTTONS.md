# Diagnostic: Hide Reply Buttons Not Working

## Quick Diagnosis

Paste this into your browser console (F12) while viewing a topic:

```javascript
console.log("╔════════════════════════════════════════════════════════════╗");
console.log("║     HIDE REPLY BUTTONS DIAGNOSTIC                          ║");
console.log("╚════════════════════════════════════════════════════════════╝");

// 1. Check setting
console.log("\n📋 SETTING CHECK:");
console.log("  hide_reply_buttons_for_non_owners:", settings?.hide_reply_buttons_for_non_owners);
console.log("  owner_comment_categories:", settings?.owner_comment_categories);
console.log("  debug_logging_enabled:", settings?.debug_logging_enabled);

// 2. Check topic context
const topicController = require("discourse/controllers/topic").default;
const topic = topicController?.currentModel;
console.log("\n📍 TOPIC CONTEXT:");
console.log("  Topic ID:", topic?.id);
console.log("  Category ID:", topic?.category_id);
console.log("  Topic Owner ID:", topic?.details?.created_by?.id);
console.log("  Topic Owner Username:", topic?.details?.created_by?.username);

// 3. Check post classification
const posts = document.querySelectorAll("article.topic-post");
const ownerPosts = document.querySelectorAll("article.topic-post.owner-post");
const nonOwnerPosts = document.querySelectorAll("article.topic-post.non-owner-post");
const markedPosts = document.querySelectorAll("article.topic-post[data-owner-marked]");

console.log("\n🏷️ POST CLASSIFICATION:");
console.log("  Total posts:", posts.length);
console.log("  Owner posts:", ownerPosts.length);
console.log("  Non-owner posts:", nonOwnerPosts.length);
console.log("  Marked posts:", markedPosts.length);

// 4. Check specific post details
console.log("\n🔍 FIRST 3 POSTS DETAIL:");
Array.from(posts).slice(0, 3).forEach((post, idx) => {
  const postNumber = post.dataset.postNumber || post.id?.match(/\d+/)?.[0];
  const hasOwnerClass = post.classList.contains("owner-post");
  const hasNonOwnerClass = post.classList.contains("non-owner-post");
  const isMarked = post.dataset.ownerMarked;
  const replyButtons = post.querySelectorAll("button.reply, button.reply-to-post, button.create");
  
  console.log(`  Post #${postNumber}:`);
  console.log(`    - owner-post class: ${hasOwnerClass}`);
  console.log(`    - non-owner-post class: ${hasNonOwnerClass}`);
  console.log(`    - data-owner-marked: ${isMarked}`);
  console.log(`    - Reply buttons found: ${replyButtons.length}`);
  console.log(`    - Reply buttons visible: ${Array.from(replyButtons).some(btn => {
      const style = window.getComputedStyle(btn);
      return style.display !== 'none';
    })}`);
});

// 5. Check CSS is loaded
console.log("\n🎨 CSS CHECK:");
const testPost = document.querySelector("article.topic-post.non-owner-post");
if (testPost) {
  const replyBtn = testPost.querySelector("button.reply, button.reply-to-post");
  if (replyBtn) {
    const style = window.getComputedStyle(replyBtn);
    console.log("  Non-owner post reply button display:", style.display);
    console.log("  Expected: 'none'");
    console.log("  Actual:", style.display === 'none' ? "✅ HIDDEN" : "❌ VISIBLE");
  } else {
    console.log("  No reply button found in non-owner post");
  }
} else {
  console.log("  No non-owner posts found to test");
}

// 6. Check if initializer ran
console.log("\n🔧 INITIALIZER CHECK:");
console.log("  Look for logs above containing '[Hide Reply Buttons]'");
console.log("  If missing, initializer may not have run");

console.log("\n╚════════════════════════════════════════════════════════════╝");
```

---

## What to Look For

### Scenario 1: Posts Not Classified
**Symptoms**:
- `Non-owner posts: 0`
- `Marked posts: 0`
- No `owner-post` or `non-owner-post` classes

**Causes**:
1. **Setting disabled**: `hide_reply_buttons_for_non_owners: false`
2. **Wrong category**: Topic category not in `owner_comment_categories`
3. **Initializer not running**: No logs, JavaScript error
4. **Topic data not ready**: `Topic Owner ID: undefined`

**Solutions**:
- Enable setting in Admin → Themes → Settings
- Add category ID to `owner_comment_categories`
- Enable `debug_logging_enabled` and check for errors
- Refresh page to ensure topic data loads

---

### Scenario 2: Posts Classified But Buttons Still Visible
**Symptoms**:
- `Non-owner posts: 3` (or more)
- `Marked posts: 3` (or more)
- Reply buttons visible: `❌ VISIBLE`

**Causes**:
1. **CSS not loaded**: Theme CSS file not deployed
2. **CSS specificity issue**: Another rule overriding the hide rule
3. **Wrong button selector**: Discourse changed button classes

**Solutions**:
- Check theme is active and CSS deployed
- Inspect button element and check computed styles
- Look for `display: none !important` in styles

---

### Scenario 3: Only Some Posts Classified
**Symptoms**:
- `Total posts: 10`
- `Marked posts: 3`
- Some posts missing classification

**Causes**:
1. **Posts loaded after classification**: Infinite scroll, "Load More"
2. **MutationObserver not working**: Observer disconnected or not set up
3. **Post data missing**: Some posts don't have user_id in post stream

**Solutions**:
- Scroll down to trigger MutationObserver
- Check console for MutationObserver logs
- Enable debug logging to see which posts are skipped

---

## Manual Test

### Step 1: Verify Setting is Enabled
```javascript
settings.hide_reply_buttons_for_non_owners
// Should return: true
```

### Step 2: Verify Category is Configured
```javascript
const topic = require("discourse/controllers/topic").default.currentModel;
const categoryId = topic.category_id;
const enabledCategories = settings.owner_comment_categories.split("|").map(id => parseInt(id.trim(), 10));
console.log("Topic category:", categoryId);
console.log("Enabled categories:", enabledCategories);
console.log("Is configured:", enabledCategories.includes(categoryId));
// Should return: true
```

### Step 3: Manually Classify a Post
```javascript
// Get first post
const post = document.querySelector("article.topic-post");

// Add non-owner class
post.classList.add("non-owner-post");
post.dataset.ownerMarked = "1";

// Check if button is hidden
const replyBtn = post.querySelector("button.reply, button.reply-to-post");
const style = window.getComputedStyle(replyBtn);
console.log("Button display:", style.display);
// Should return: "none"
```

If this works, the CSS is fine and the issue is with classification.

### Step 4: Check for JavaScript Errors
```javascript
// Look for errors in console
// Common errors:
// - "Cannot read property 'posts' of undefined" → Post stream not ready
// - "parseCategoryIds is not defined" → Import issue
// - "settings is not defined" → Theme not loaded
```

---

## Common Fixes

### Fix 1: Enable Debug Logging
```javascript
// In Admin → Themes → Settings
debug_logging_enabled = true

// Then refresh page and look for:
// [Owner View] [Hide Reply Buttons] Hide reply buttons feature enabled
// [Owner View] [Hide Reply Buttons] Starting post classification
// [Owner View] [Hide Reply Buttons] Classifying post {postNumber: 1, isOwnerPost: false}
```

### Fix 2: Force Re-classification
```javascript
// Paste this in console to force re-run
const topic = require("discourse/controllers/topic").default.currentModel;
const topicOwnerId = topic.details.created_by.id;

document.querySelectorAll("article.topic-post").forEach(postEl => {
  const postNumber = postEl.dataset.postNumber || postEl.id.match(/\d+/)?.[0];
  const post = topic.postStream.posts.find(p => p.post_number == postNumber);
  
  if (post) {
    const isOwner = post.user_id === topicOwnerId;
    console.log(`Post #${postNumber}: ${isOwner ? 'OWNER' : 'NON-OWNER'}`);
    
    if (isOwner) {
      postEl.classList.add("owner-post");
      postEl.classList.remove("non-owner-post");
    } else {
      postEl.classList.add("non-owner-post");
      postEl.classList.remove("owner-post");
    }
    postEl.dataset.ownerMarked = "1";
  }
});

console.log("Re-classification complete!");
```

### Fix 3: Check CSS Specificity
```javascript
// Check if CSS rule is being applied
const testPost = document.querySelector("article.topic-post.non-owner-post");
const replyBtn = testPost?.querySelector("button.reply");

if (replyBtn) {
  const styles = window.getComputedStyle(replyBtn);
  console.log("All display-related styles:");
  console.log("  display:", styles.display);
  console.log("  visibility:", styles.visibility);
  console.log("  opacity:", styles.opacity);
  
  // Check which CSS rule is winning
  const matchedRules = [...document.styleSheets]
    .flatMap(sheet => {
      try {
        return [...sheet.cssRules];
      } catch (e) {
        return [];
      }
    })
    .filter(rule => {
      try {
        return replyBtn.matches(rule.selectorText);
      } catch (e) {
        return false;
      }
    });
  
  console.log("Matched CSS rules:", matchedRules.length);
  matchedRules.forEach(rule => {
    console.log("  -", rule.selectorText, "→", rule.style.display);
  });
}
```

---

## Expected Behavior

When working correctly:

1. **On page load**:
   - All posts get classified (owner-post or non-owner-post class)
   - Non-owner posts have reply buttons hidden via CSS
   - Console shows classification logs (if debug enabled)

2. **On scroll/load more**:
   - MutationObserver detects new posts
   - New posts get classified automatically
   - Reply buttons hidden on non-owner posts

3. **Visual result**:
   - Topic owner's posts: Reply button visible
   - Other users' posts: Reply button hidden (display: none)

---

## Report Back

After running the diagnostic, share:

1. **Full console output** from the diagnostic script
2. **Any errors** (red text in console)
3. **Screenshot** of a non-owner post showing the reply button
4. **Settings values**:
   - `hide_reply_buttons_for_non_owners`
   - `owner_comment_categories`
   - Current topic's category ID

