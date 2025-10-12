# Troubleshooting: Owner Post Number Not Set

## Quick Diagnosis

### Step 1: Check Console Logs

Open browser console and expand embedded posts. Look for these messages:

✅ **Success:**
```
[Embedded Reply Buttons] Successfully stored owner post number 123 on button
```

❌ **Failure:**
```
[Embedded Reply Buttons] CRITICAL: Could not determine owner post number - button will not work!
```

### Step 2: Identify the Issue

Based on console logs, identify which scenario applies:

## Scenario A: Owner Post Element Not Found

**Console Output:**
```
[Embedded Reply Buttons] Owner post element: null
[Embedded Reply Buttons] Could not find owner post element (article.topic-post) for section
```

**Cause:** Section is not nested inside `article.topic-post`

**Solution:**

1. **Inspect DOM structure:**
   ```javascript
   // In browser console
   const section = document.querySelector("section.embedded-posts");
   console.log("Section:", section);
   console.log("Parent:", section.parentElement);
   console.log("Grandparent:", section.parentElement?.parentElement);
   console.log("Closest article:", section.closest("article.topic-post"));
   ```

2. **Check if section has ID with post number:**
   ```javascript
   console.log("Section ID:", section.id);
   // Should be like: "embedded-posts--123"
   ```

3. **If section ID has post number:**
   - The fallback should extract it automatically
   - Check logs for: `Extracted owner post number from section ID: 123`

4. **If no section ID:**
   - Check if any parent has `data-post-number`:
   ```javascript
   let current = section.parentElement;
   while (current) {
     if (current.dataset?.postNumber) {
       console.log("Found post number:", current.dataset.postNumber);
       break;
     }
     current = current.parentElement;
   }
   ```

## Scenario B: Post Number Not Extracted from Owner Post

**Console Output:**
```
[Embedded Reply Buttons] Owner post element: <article>
[Embedded Reply Buttons] Extracted owner post number from element: null
[Embedded Reply Buttons] Could not extract post number from owner post element
```

**Cause:** Owner post element doesn't have `data-post-number` attribute

**Solution:**

1. **Inspect owner post attributes:**
   ```javascript
   const section = document.querySelector("section.embedded-posts");
   const ownerPost = section.closest("article.topic-post");
   console.log("Owner post dataset:", ownerPost.dataset);
   console.log("Owner post ID:", ownerPost.id);
   console.log("All attributes:", Array.from(ownerPost.attributes).map(a => `${a.name}="${a.value}"`));
   ```

2. **Check for post number in ID:**
   - If ID is like `post_123` or `post-123`, the extraction should work
   - Check `extractPostNumberFromElement()` function

3. **Manual extraction:**
   ```javascript
   // Try to find post number manually
   const postNumber = ownerPost.dataset.postNumber || 
                      ownerPost.id.match(/post[_-](\d+)/)?.[1];
   console.log("Post number:", postNumber);
   ```

## Scenario C: Button Attribute Not Set

**Console Output:**
```
[Embedded Reply Buttons] Button data-owner-post-number: undefined
[Embedded Reply Buttons] Owner post number not found on button
```

**Cause:** Button was created but attribute wasn't set

**Solution:**

1. **Inspect button element:**
   ```javascript
   const btn = document.querySelector(".embedded-reply-button");
   console.log("Button:", btn);
   console.log("Dataset:", btn.dataset);
   console.log("Attributes:", Array.from(btn.attributes).map(a => `${a.name}="${a.value}"`));
   ```

2. **Check if button was created before owner post was available:**
   - This could be a timing issue
   - The MutationObserver should wait for the section to be fully rendered

3. **Manually set attribute (temporary fix):**
   ```javascript
   const btn = document.querySelector(".embedded-reply-button");
   const section = btn.closest("section.embedded-posts");
   const ownerPost = section.closest("article.topic-post");
   const postNumber = ownerPost.dataset.postNumber;
   btn.dataset.ownerPostNumber = postNumber;
   console.log("Manually set:", btn.dataset.ownerPostNumber);
   ```

## Scenario D: Section ID Pattern Mismatch

**Console Output:**
```
[Embedded Reply Buttons] Section ID: some-other-id
[Embedded Reply Buttons] Extracted owner post number from section ID: null
```

**Cause:** Section ID doesn't match expected pattern `embedded-posts--{number}`

**Solution:**

1. **Check actual section ID pattern:**
   ```javascript
   const section = document.querySelector("section.embedded-posts");
   console.log("Section ID:", section.id);
   ```

2. **Update regex pattern if needed:**
   - Current pattern: `/--(\d+)$/`
   - Matches: `embedded-posts--123`
   - If pattern is different (e.g., `embedded-posts-123`), update regex

3. **Example fix for different pattern:**
   ```javascript
   // If ID is "embedded-posts-123" instead of "embedded-posts--123"
   const match = section.id.match(/-(\d+)$/);  // Single dash instead of double
   ```

## Common DOM Structures

### Structure 1: Standard (Should Work)
```html
<article class="topic-post" data-post-number="123">
  <div class="topic-body">...</div>
  <section class="embedded-posts" id="embedded-posts--123">
    <!-- Button injected here -->
  </section>
</article>
```

### Structure 2: Nested (Should Work with Fallback 1)
```html
<article class="topic-post" data-post-number="123">
  <div class="topic-body">...</div>
  <div class="post-footer">
    <section class="embedded-posts" id="embedded-posts--123">
      <!-- Button injected here -->
    </section>
  </div>
</article>
```

### Structure 3: No article.topic-post (Needs Section ID)
```html
<div class="post-wrapper" data-post-number="123">
  <section class="embedded-posts" id="embedded-posts--123">
    <!-- Button injected here -->
    <!-- Fallback: Extract from section ID -->
  </section>
</div>
```

### Structure 4: Problematic (May Fail)
```html
<div class="post-container">
  <section class="embedded-posts">
    <!-- No way to determine owner post number -->
    <!-- Button will not work -->
  </section>
</div>
```

## Manual Testing Commands

### Test Owner Post Detection
```javascript
const section = document.querySelector("section.embedded-posts");
const ownerPost = section.closest("article.topic-post");
console.log("Owner post found:", !!ownerPost);
console.log("Owner post:", ownerPost);
```

### Test Post Number Extraction
```javascript
const section = document.querySelector("section.embedded-posts");
const ownerPost = section.closest("article.topic-post");
const postNumber = ownerPost?.dataset?.postNumber || 
                   ownerPost?.id?.match(/post[_-](\d+)/)?.[1];
console.log("Post number:", postNumber);
```

### Test Section ID Extraction
```javascript
const section = document.querySelector("section.embedded-posts");
const match = section.id?.match(/--(\d+)$/);
const postNumber = match ? match[1] : null;
console.log("Post number from section ID:", postNumber);
```

### Test Button Attribute
```javascript
const btn = document.querySelector(".embedded-reply-button");
console.log("Button has owner post number:", !!btn?.dataset?.ownerPostNumber);
console.log("Owner post number:", btn?.dataset?.ownerPostNumber);
```

## Fallback Chain Summary

The code tries these methods in order:

1. **`section.closest("article.topic-post")`** - Standard Discourse structure
2. **Manual parent traversal** - If `closest()` fails
3. **Find parent with `data-post-number`** - Any parent with post number
4. **Extract from section ID** - Pattern: `embedded-posts--{number}`

If all fail, button will not work and you'll see:
```
[Embedded Reply Buttons] CRITICAL: Could not determine owner post number - button will not work!
```

## Next Steps

1. **Identify which scenario applies** from console logs
2. **Use manual testing commands** to investigate
3. **Check DOM structure** matches expected patterns
4. **Report findings** with console logs and DOM structure
5. **Implement custom fix** if needed for your specific DOM structure

