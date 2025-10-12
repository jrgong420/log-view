# Quick Start Testing Guide - Embedded Reply Buttons

## 🚀 Quick Test (5 minutes)

This is a fast way to verify the embedded reply buttons feature is working.

### Prerequisites
- Discourse instance with log-view theme component installed
- A topic with replies from multiple users
- Browser with DevTools (F12)

### Step 1: Open Console
1. Press **F12** to open browser DevTools
2. Click the **Console** tab
3. Clear the console (optional)

### Step 2: Navigate to Test Topic
1. Go to a topic in a configured category
2. Look for the console message:
   ```
   [Embedded Reply Buttons] Initializer starting...
   [Embedded Reply Buttons] Global click handler bound successfully
   ```
   ✅ If you see this, the feature is loaded

### Step 3: Enter Filtered View
1. Click the "Show Owner Comments" toggle button
2. Wait for the page to reload with `?username_filters=...` in the URL
3. Look for console messages:
   ```
   [Embedded Reply Buttons] Page change detected
   [Embedded Reply Buttons] Owner comment mode: true
   [Embedded Reply Buttons] Found X embedded post sections
   [Embedded Reply Buttons] Button injected successfully
   ```
   ✅ If you see this, buttons are being injected

### Step 4: Visual Check
1. Scroll through the topic
2. Look for embedded posts (replies from other users shown in gray boxes)
3. Each embedded post should have a small **"Reply"** button
   ✅ If you see reply buttons, injection is working

### Step 5: Test Composer Opening
1. Click any **"Reply"** button on an embedded post
2. Look for console messages:
   ```
   [Embedded Reply Buttons] Reply button clicked
   [Embedded Reply Buttons] Opening composer with options
   [Embedded Reply Buttons] Composer opened successfully
   ```
3. The composer should open at the bottom of the page
4. Check the reply indicator shows the correct username
   ✅ If composer opens with correct context, feature is working!

### Step 6: Test Filtered View Persistence
1. Type a test message in the composer
2. Click "Reply" to post
3. Verify you stay on the filtered view (URL still has `?username_filters=...`)
   ✅ If you stay in filtered view, persistence is working!

## ✅ Success Criteria

If all steps above pass, the feature is working correctly!

## ❌ Troubleshooting

### No console messages
**Problem**: Feature not loading
**Fix**: 
- Refresh the page
- Check theme is active in Admin → Customize → Themes
- Check browser console for JavaScript errors

### "Owner comment mode: false"
**Problem**: Not in filtered view
**Fix**: 
- Click the toggle button to enter filtered view
- Verify URL has `?username_filters=...`

### No reply buttons visible
**Problem**: Buttons not injected
**Fix**:
- Check console for "Found 0 embedded post sections"
- Verify there are embedded posts in the topic
- Try scrolling to load more posts

### Composer doesn't open
**Problem**: Click handler not working
**Fix**:
- Check console for error messages
- Verify button has class `embedded-reply-button`
- Try clicking directly on the button text

### Wrong reply context
**Problem**: Replying to wrong post
**Fix**:
- Check console for "Parent post number" log
- Verify the post number matches the owner's post
- Check "Reply indicator" in composer

## 📊 Expected Console Output (Full Test)

```
[Embedded Reply Buttons] Initializer starting...
[Embedded Reply Buttons] Binding global click handler...
[Embedded Reply Buttons] Global click handler bound successfully
[Embedded Reply Buttons] Initializer setup complete
[Embedded Reply Buttons] Page change detected: { url: "...", title: "..." }
[Embedded Reply Buttons] afterRender: Checking for embedded posts...
[Embedded Reply Buttons] Owner comment mode: true
[Embedded Reply Buttons] Found 2 embedded post sections
[Embedded Reply Buttons] Processing embedded section 1...
[Embedded Reply Buttons] Found 3 embedded items in section 1
[Embedded Reply Buttons] Section 1, Item 1: Injecting reply button...
[Embedded Reply Buttons] Section 1, Item 1: Button injected successfully
[Embedded Reply Buttons] Section 1, Item 2: Injecting reply button...
[Embedded Reply Buttons] Section 1, Item 2: Button injected successfully
[Embedded Reply Buttons] Section 1, Item 3: Injecting reply button...
[Embedded Reply Buttons] Section 1, Item 3: Button injected successfully
[Embedded Reply Buttons] Button injection complete

[User clicks a reply button]

[Embedded Reply Buttons] Reply button clicked: <button>
[Embedded Reply Buttons] Topic model: { id: 123, ... }
[Embedded Reply Buttons] Composer service: ComposerService { ... }
[Embedded Reply Buttons] Parent post number: "1"
[Embedded Reply Buttons] Parent post model: { id: 456, post_number: 1, ... }
[Embedded Reply Buttons] Draft key: "topic_123"
[Embedded Reply Buttons] Draft sequence: 0
[Embedded Reply Buttons] Opening composer with options: { action: "REPLY", ... }
[Embedded Reply Buttons] Composer opened successfully
```

## 🔍 Advanced Testing

For comprehensive testing, see:
- **Full Test Suite**: `docs/EMBEDDED_REPLY_BUTTONS_TESTING.md` (10 test cases)
- **Technical Details**: `docs/EMBEDDED_REPLY_BUTTONS_IMPLEMENTATION.md`
- **Feature Summary**: `FEATURE_SUMMARY.md`

## 📝 Reporting Issues

If you find a bug, please report with:
1. Full console output (copy/paste from DevTools)
2. Browser and version (e.g., Chrome 120)
3. Discourse version
4. Steps to reproduce
5. Expected vs actual behavior
6. Screenshots (if applicable)

## 🎯 Next Steps

After quick testing:
1. Run full test suite (see `docs/EMBEDDED_REPLY_BUTTONS_TESTING.md`)
2. Test on mobile devices
3. Test with different user roles
4. Test in different categories
5. Test SPA navigation (navigate between topics)

## 💡 Tips

- **Filter console**: Type `[Embedded Reply Buttons]` in the console filter box
- **Clear console**: Click the 🚫 icon to clear old messages
- **Preserve log**: Check "Preserve log" to keep messages across page loads
- **Verbose mode**: All logging is already verbose by default
- **Mobile testing**: Use DevTools device emulation or real device

## ✨ Feature Highlights

What makes this feature great:
- ✅ **No navigation**: Stay in filtered view while replying
- ✅ **Correct context**: Always replies to the right post
- ✅ **SPA compatible**: Works with Discourse's routing
- ✅ **Comprehensive logging**: Easy to debug and verify
- ✅ **Clean UI**: Buttons match theme design
- ✅ **Idempotent**: No duplicate buttons on re-renders

Happy testing! 🎉

