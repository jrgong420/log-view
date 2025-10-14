import { apiInitializer } from "discourse/lib/api";
import { schedule } from "@ember/runloop";
import { createLogger } from "../lib/logger";

export default apiInitializer("1.14.0", (api) => {
  let globalClickHandlerBound = false;
  let showRepliesClickHandlerBound = false;
  let composerEventsBound = false;

  // Map to track active MutationObservers per post
  const activeObservers = new Map();

  // Centralized logger (controlled by debug_logging_enabled setting)
  const log = createLogger("[Owner View] [Embedded Reply Buttons]");

  // Module-scoped state to remember last reply parent for fallback
  let lastReplyContext = { topicId: null, parentPostNumber: null };
  // Module-scoped state to track newly created post for auto-scroll
  let lastCreatedPost = null;

  // Standard reply button interception state
  let standardReplyInterceptBound = false;
  let suppressStandardReplyScroll = false;
  let suppressedReplyPostNumber = null;

  // Collapsed section expansion state
  let replyToCollapsedSection = false;
  let replyOwnerPostNumberForExpand = null;
  let expandOrchestratorActive = false;

  // Support multiple markup variants for embedded rows
  // Support multiple markup variants for embedded rows (broad but scoped to the section)
  const EMBEDDED_ITEM_SELECTOR = "[data-post-id], [data-post-number], li[id^=\"post_\"], article[id^=\"post_\"], article.topic-post, .embedded-posts__post, .embedded-post, li.embedded-post, .embedded-post-item";

  function extractPostNumberFromElement(el) {
    if (!el) return null;
    const ds = el.dataset || {};
    if (ds.postNumber) return Number(ds.postNumber);
    const attrPN = el.getAttribute?.("data-post-number");
    if (attrPN) return Number(attrPN);
    const id = el.id || "";
    let m = id.match(/^post[_-](\d+)$/i);
    if (m) return Number(m[1]);
    // Look for descendant hints (some rows wrap inner article/li)
    const inner = el.querySelector?.("[data-post-number], [id^='post_']");
    if (inner) {
      const ds2 = inner.dataset || {};
      if (ds2.postNumber) return Number(ds2.postNumber);
      const id2 = inner.id || "";
      m = id2.match(/^post[_-](\d+)$/i);
      if (m) return Number(m[1]);
    }
    return null;
  }

  function extractPostIdFromElement(el) {
    if (!el) return null;
    const ds = el.dataset || {};
    if (ds.postId) return Number(ds.postId);
    const attrPI = el.getAttribute?.("data-post-id");
    if (attrPI) return Number(attrPI);
    // Look for descendant hints
    const inner = el.querySelector?.("[data-post-id]");
    if (inner) {
      const ds2 = inner.dataset || {};
      if (ds2.postId) return Number(ds2.postId);
      const attr2 = inner.getAttribute?.("data-post-id");
      if (attr2) return Number(attr2);
    }
    return null;
  }

  // Get the owner post (the post that contains the embedded section)
  function getOwnerPostFromSection(section) {
    if (!section) return null;

    // Try closest first (most reliable)
    let ownerPost = section.closest("article.topic-post");

    if (!ownerPost) {
      // Fallback 1: Try parent traversal
      let current = section.parentElement;
      while (current && current !== document.body) {
        if (current.matches && current.matches("article.topic-post")) {
          ownerPost = current;
          break;
        }
        current = current.parentElement;
      }
    }

    if (!ownerPost) {
      // Fallback 2: Try finding by data-post-number in parent chain
      let current = section.parentElement;
      while (current && current !== document.body) {
        if (current.dataset && current.dataset.postNumber) {
          ownerPost = current;
          break;
        }
        current = current.parentElement;
      }
    }

    return ownerPost;
  }

  function parsePostNumberFromHref(href) {
    if (!href || typeof href !== "string") return null;
    // Pattern: /t/<slug>/<topicId>/<postNumber>
    let m = href.match(/\/t\/[^/]+\/\d+\/(\d+)(?:$|[?#])/);
    if (m) return Number(m[1]);
    // Pattern: #post_82 or #post-82
    m = href.match(/#post[_-](\d+)/i);
    if (m) return Number(m[1]);
    return null;
  }
  // Dispatch a robust synthetic click that works with widget/Glimmer handlers
  function robustClick(el) {
    if (!el) return false;
    try {
      el.focus?.();
      const opts = { bubbles: true, cancelable: true, view: window };
      const sequence = [];

      // Add PointerEvent if available
      if (typeof PointerEvent !== "undefined") {
        sequence.push(new PointerEvent("pointerdown", { bubbles: true, cancelable: true }));
      }

      // Add standard mouse events
      sequence.push(new MouseEvent("mousedown", opts));
      sequence.push(new MouseEvent("mouseup", opts));
      sequence.push(new MouseEvent("click", opts));

      for (const ev of sequence) {
        el.dispatchEvent(ev);
        // If any listener prevented default and stopped propagation we still continue
      }
      return true;
    } catch (e) {
      try {
        el.click();
        return true;
      } catch (e2) {
        return false;
      }
    }
  }

  // Helper function to scroll to newly created embedded post
  function tryScrollToNewReply(section) {
    if (!lastCreatedPost?.postNumber) {
      log.debug("AutoScroll: no lastCreatedPost to scroll to");
      return false;
    }

    log.debug(`AutoScroll: searching for post #${lastCreatedPost.postNumber} in section`);

    // Build selectors to find the newly created post (by number and optional id)
    const selectors = [
      `[data-post-number="${lastCreatedPost.postNumber}"]`,
      `#post_${lastCreatedPost.postNumber}`,
      `#post-${lastCreatedPost.postNumber}`
    ];

    if (lastCreatedPost.postId) {
      selectors.push(`[data-post-id="${lastCreatedPost.postId}"]`);
    }

    let foundElement = null;
    for (const selector of selectors) {
      const el = section.querySelector(selector);
      if (el) {
        foundElement = el;
        log.debug(`AutoScroll: found element with selector: ${selector}`);
        break;
      }
    }

    // Fallback: scan all embedded items and match by extracted post number
    if (!foundElement) {
      const candidates = section.querySelectorAll(EMBEDDED_ITEM_SELECTOR);
      for (const el of candidates) {
        const pn = extractPostNumberFromElement(el);
        if (pn === Number(lastCreatedPost.postNumber)) {
          foundElement = el;
          log.debug(`AutoScroll: found element by scanning candidates (post #${pn})`);
          break;
        }
      }
    }

    if (foundElement) {
      log.info(`AutoScroll: scrolling to post #${lastCreatedPost.postNumber}`);

      // Scroll the element into view
      foundElement.scrollIntoView({
        block: "center",
        behavior: "smooth"
      });

      // Optional: Add a temporary highlight for visual feedback
      foundElement.classList.add("highlighted-reply");
      setTimeout(() => {
        foundElement.classList.remove("highlighted-reply");
      }, 2000);

      // Hide duplicate post in the main stream (owner comment mode only)
      try {
        const pn = lastCreatedPost?.postNumber;
        const pid = lastCreatedPost?.postId;
        if (pn || pid) {
          hideMainStreamDuplicateInOwnerMode(pn, pid);
        }
      } catch (err) {
        log.warn("Failed to hide duplicate in main stream", err);
      }

      // Clear the state to avoid repeated scrolls
      log.debug("AutoScroll: clearing lastCreatedPost after successful scroll");
      lastCreatedPost = null;
      return true;
    }

    log.debug(`AutoScroll: post #${lastCreatedPost.postNumber} not found in section yet`);
    return false;
  }

  // Hide the newly appended post in the main stream when in owner comment mode
  function hideMainStreamDuplicateInOwnerMode(postNumber, postId) {
    try {
      const isOwnerCommentMode = document.body.dataset.ownerCommentMode === "true";
      if (!isOwnerCommentMode) return;
      if (!postNumber && !postId) return;

      const candidates = [
        `article.topic-post[data-post-number="${postNumber}"]`,
        `article#post_${postNumber}`,
        `article#post-${postNumber}`
      ];

      let article = null;
      for (const sel of candidates) {
        if (!postNumber) break;
        const el = document.querySelector(sel);
        if (el && !el.closest("section.embedded-posts")) {
          article = el.closest("article.topic-post, article");
          break;
        }
      }

      if (!article && postId) {
        const el2 = document.querySelector(`article.topic-post [data-post-id="${postId}"]`);
        if (el2 && !el2.closest("section.embedded-posts")) {
          article = el2.closest("article.topic-post, article");
        }
      }

      if (article) {
        article.style.display = "none";
        article.dataset.ownerModeHidden = "true";
        log.debug(`Hidden main stream post #${postNumber || "(unknown)"} in owner mode`);
      } else {
        log.debug(`No main stream duplicate found to hide for post #${postNumber || "(unknown)"}`);
      }
    } catch (err) {
      log.warn("Failed to hide main stream duplicate", err);
    }
  }

  /**
   * Expand the embedded replies section for a collapsed owner post
   * @param {HTMLElement} ownerPostElement - The owner post article element
   * @param {Object} options - Configuration options
   * @param {number} options.timeoutMs - Maximum time to wait for expansion (default: 5000ms)
   * @returns {Promise<boolean>} - True if expansion succeeded, false otherwise
   */
  async function expandEmbeddedReplies(ownerPostElement, { timeoutMs = 5000 } = {}) {
    if (!ownerPostElement) {
      log.debug("Expand: no owner post element provided");
      return false;
    }

    const postNumber = ownerPostElement.dataset?.postNumber;
    log.debug(`Expand: attempting to expand embedded replies for post #${postNumber}`);

    // Check if already expanded
    const existingSection = ownerPostElement.querySelector("section.embedded-posts");
    if (existingSection) {
      log.debug(`Expand: section already exists for post #${postNumber}`);
      return true;
    }

    // Find the expand/toggle button (reuse selectors from "show replies" handler)
    const toggleBtn = ownerPostElement.querySelector(
      ".post-controls .show-replies, .show-replies, .post-action-menu__show-replies"
    );

    if (!toggleBtn) {
      log.debug(`Expand: no toggle button found for post #${postNumber}`);
      return false;
    }

    log.debug(`Expand: clicking toggle button for post #${postNumber}`);
    const clicked = robustClick(toggleBtn);
    if (!clicked) {
      log.debug(`Expand: failed to click toggle button for post #${postNumber}`);
      return false;
    }

    // Wait for section.embedded-posts to appear
    return new Promise((resolve) => {
      let resolved = false;
      const timeoutId = setTimeout(() => {
        if (!resolved) {
          resolved = true;
          observer.disconnect();
          log.debug(`Expand: timeout waiting for section to appear for post #${postNumber}`);
          resolve(false);
        }
      }, timeoutMs);

      const observer = new MutationObserver(() => {
        const section = ownerPostElement.querySelector("section.embedded-posts");
        if (section && !resolved) {
          resolved = true;
          clearTimeout(timeoutId);
          observer.disconnect();
          log.debug(`Expand: section appeared for post #${postNumber}`);
          resolve(true);
        }
      });

      observer.observe(ownerPostElement, {
        childList: true,
        subtree: true
      });
    });
  }

  /**
   * Load all embedded replies by clicking "load more" until no button remains
   * @param {HTMLElement} ownerPostElement - The owner post article element
   * @param {Object} options - Configuration options
   * @param {number} options.maxClicks - Maximum number of "load more" clicks (default: 20)
   * @param {number} options.timeoutMs - Maximum total time for loading (default: 10000ms)
   * @returns {Promise<boolean>} - True if all replies loaded, false if timed out
   */
  async function loadAllEmbeddedReplies(ownerPostElement, { maxClicks = 20, timeoutMs = 10000 } = {}) {
    if (!ownerPostElement) {
      log.debug(`LoadAll: no owner post element provided`);
      return false;
    }

    const postNumber = ownerPostElement.dataset?.postNumber;
    const section = ownerPostElement.querySelector("section.embedded-posts");

    if (!section) {
      log.debug(`LoadAll: no embedded section found for post #${postNumber}`);
      return false;
    }

    log.debug(`LoadAll: starting to load all replies for post #${postNumber}`);

    const startTime = Date.now();
    let clickCount = 0;

    while (clickCount < maxClicks) {
      // Check timeout
      if (Date.now() - startTime > timeoutMs) {
        log.debug(`LoadAll: timeout after ${clickCount} clicks for post #${postNumber}`);
        return false;
      }

      // Find load more button
      const loadMoreBtn = section.querySelector(".load-more-replies");
      if (!loadMoreBtn) {
        log.debug(`LoadAll: no more load-more button, all replies loaded for post #${postNumber} (${clickCount} clicks)`);
        return true;
      }

      // Check if button is disabled/loading
      if (loadMoreBtn.disabled || loadMoreBtn.classList.contains("loading")) {
        log.debug(`LoadAll: button is disabled/loading, waiting...`);
        await new Promise(resolve => setTimeout(resolve, 500));
        continue;
      }

      log.debug(`LoadAll: clicking load-more button (click #${clickCount + 1}) for post #${postNumber}`);
      const clicked = robustClick(loadMoreBtn);
      if (!clicked) {
        log.debug(`LoadAll: failed to click load-more button for post #${postNumber}`);
        return false;
      }

      clickCount++;

      // Wait for DOM to update
      await new Promise((resolve) => {
        const observer = new MutationObserver(() => {
          observer.disconnect();
          resolve();
        });
        observer.observe(section, { childList: true, subtree: true });

        // Fallback timeout in case no mutation occurs
        setTimeout(() => {
          observer.disconnect();
          resolve();
        }, 1000);
      });

      // Small delay between clicks
      await new Promise(resolve => setTimeout(resolve, 200));
    }

    log.debug(`LoadAll: reached max clicks (${maxClicks}) for post #${postNumber}`);
    return false;
  }

  /**
   * Clear collapsed section expansion state
   */
  function finalizeCollapsedFlow() {
    log.debug(`Finalize: clearing collapsed expansion state and ephemeral reply state`);
    replyToCollapsedSection = false;
    replyOwnerPostNumberForExpand = null;
    expandOrchestratorActive = false;
    // Also clear per-reply ephemeral state to avoid stale fallbacks between replies
    lastReplyContext = { topicId: null, parentPostNumber: null };
    lastCreatedPost = null;
  }



  /**
   * Shared function to open composer for replying to owner's post
   * Used by both embedded reply button and intercepted standard reply button
   */
  async function openReplyToOwnerPost(topic, ownerPost, ownerPostNumber) {
    log.info(`Opening reply to owner post #${ownerPostNumber}`);

    const composer = api.container.lookup("service:composer");
    if (!composer) {
      log.debug(`Composer not available`);
      return;
    }

    // Build composer options
    const composerOptions = {
      action: "reply",
      topic: topic,
      draftKey: topic.draft_key,
      draftSequence: topic.draft_sequence,
      skipJumpOnSave: true,
    };

    // Store context for auto-refresh fallback
    lastReplyContext = {
      topicId: topic.id,
      parentPostNumber: ownerPostNumber,
      ownerPostNumber
    };
    log.info(`Stored lastReplyContext`, lastReplyContext);

    // Add post model if available, otherwise use post number
    if (ownerPost) {
      composerOptions.post = ownerPost;
    } else {
      composerOptions.replyToPostNumber = ownerPostNumber;
    }

    await composer.open(composerOptions);
    log.info(`Composer opened successfully`);
  }

  // Function to inject a single reply button at the section level
  function injectEmbeddedReplyButtons(section) {
    // Skip if section already has a reply button
    if (!section || section.dataset.replyBtnBound || section.querySelector(".embedded-reply-button")) {
      log.debug(`Section already has reply button, skipping injection`);
      return { injected: 0, reason: "already-bound" };
    }

    // Find the collapse button to position our button next to it
    const collapseButton = section.querySelector(".widget-button.collapse-up, button.collapse-up, .collapse-embedded-posts");

    if (!collapseButton) {
      log.debug(`Collapse button not found in section, will append to section`);
    }

    // Create the reply button
    const btn = document.createElement("button");
    btn.className = "btn btn-small embedded-reply-button";
    btn.type = "button";
    btn.textContent = "Reply";
    btn.title = "Reply to owner's post";
    btn.setAttribute("aria-label", "Reply to owner's post");

    // Store the owner post number on the button for easy retrieval
    log.debug(`Attempting to find owner post for section:`, section);
    log.debug(`Section ID:`, section.id);
    log.debug(`Section classes:`, section.className);

    const ownerPost = getOwnerPostFromSection(section);
    log.debug(`Owner post element:`, ownerPost);

    let ownerPostNumber = null;

    if (ownerPost) {
      ownerPostNumber = extractPostNumberFromElement(ownerPost);
      log.debug(`Extracted owner post number from element:`, ownerPostNumber);

      if (!ownerPostNumber) {
        log.warn(`Could not extract post number from owner post element`);
        log.warn(`Owner post dataset:`, ownerPost.dataset);
        log.warn(`Owner post id:`, ownerPost.id);
        log.warn(`Owner post attributes:`, Array.from(ownerPost.attributes).map(a => `${a.name}="${a.value}"`));
      }
    } else {
      log.warn(`Could not find owner post element (article.topic-post) for section`);
      log.warn(`Section parent elements:`, section.parentElement, section.parentElement?.parentElement);

      // Fallback: Try to extract from section ID (e.g., "embedded-posts--123")
      if (section.id) {
        const match = section.id.match(/--(\d+)$/);
        if (match) {
          ownerPostNumber = Number(match[1]);
          log.debug(`Extracted owner post number from section ID:`, ownerPostNumber);
        }
      }
    }

    if (ownerPostNumber) {
      btn.dataset.ownerPostNumber = String(ownerPostNumber);
      log.debug(`Successfully stored owner post number ${ownerPostNumber} on button`);
      log.debug(`Button data-owner-post-number attribute:`, btn.dataset.ownerPostNumber);
      log.debug(`Button element after setting attribute:`, btn);
    } else {
      log.error(`CRITICAL: Could not determine owner post number - button will not work!`);
      log.error(`Section:`, section);
      log.error(`Owner post:`, ownerPost);
    }

    // Position the button next to the collapse button
    if (collapseButton) {
      // Find or create a container for the buttons
      let buttonContainer = collapseButton.parentElement;

      // Check if the parent is the section itself or a proper container
      if (buttonContainer === section) {
        // Collapse button is a direct child of section
        // Create a wrapper div for both buttons
        const wrapper = document.createElement("div");
        wrapper.className = "embedded-posts-controls";

        // Insert wrapper before collapse button
        section.insertBefore(wrapper, collapseButton);

        // Move collapse button into wrapper
        wrapper.appendChild(collapseButton);

        // Insert reply button before collapse button in wrapper
        wrapper.insertBefore(btn, collapseButton);

        log.debug(`Created button container and injected reply button`);
      } else {
        // Collapse button is already in a container
        // Just insert our button before it
        buttonContainer.insertBefore(btn, collapseButton);

        // Ensure the container has proper flex layout
        if (!buttonContainer.classList.contains("embedded-posts-controls")) {
          buttonContainer.classList.add("embedded-posts-controls");
        }

        log.debug(`Injected reply button into existing container`);
      }
    } else {
      // Fallback: create a container at the end of the section
      const wrapper = document.createElement("div");
      wrapper.className = "embedded-posts-controls";
      wrapper.appendChild(btn);
      section.appendChild(wrapper);
      log.debug(`Created button container at end of section (collapse button not found)`);
    }

    // Mark section as having a button
    section.dataset.replyBtnBound = "1";

    return { injected: 1, reason: "success" };
  }

  // Function to setup MutationObserver for a specific post
  function setupPostObserver(postElement) {
    if (!postElement) {
      return;
    }

    // Don't create duplicate observers
    if (activeObservers.has(postElement)) {
      return;
    }

    const observer = new MutationObserver((mutations) => {
      // Check if embedded-posts section was added
      for (const mutation of mutations) {
        if (mutation.type === "childList") {
          mutation.addedNodes.forEach((node) => {
            if (node.nodeType === Node.ELEMENT_NODE) {
              // Check if the added node is or contains section.embedded-posts
              if (node.matches && node.matches("section.embedded-posts")) {
                log.debug(`Embedded section detected, attempting injection`);
                const res = injectEmbeddedReplyButtons(node);
                if (res.reason === "success") {
                  log.debug(`Button injected successfully`);
                  observer.disconnect();
                  activeObservers.delete(postElement);
                } else if (res.reason === "already-bound") {
                  log.debug(`Section already has button`);
                  observer.disconnect();
                  activeObservers.delete(postElement);
                } else {
                  // Wait for collapse button to appear
                  setupSectionChildObserver(node);
                  observer.disconnect();
                  activeObservers.delete(postElement);
                }
              } else if (node.querySelector) {
                const embeddedSections = node.querySelectorAll("section.embedded-posts");
                if (embeddedSections.length > 0) {
                  embeddedSections.forEach(section => {
                    log.debug(`Embedded section detected (nested), attempting injection`);
                    const res = injectEmbeddedReplyButtons(section);
                    if (res.reason !== "success" && res.reason !== "already-bound") {
                      setupSectionChildObserver(section);
                    }
                  });
                  observer.disconnect();
                  activeObservers.delete(postElement);
                }
              }
            }
          });
        }
      }
    });

    // Observe the post element for child additions
    observer.observe(postElement, {
      childList: true,
      subtree: true
    });

    activeObservers.set(postElement, observer);
    log.debug(`Set up observer for post element`);
  }

  // Function to observe stream for a specific embedded section id (fallback)
  function setupSectionObserverById(sectionId) {
    if (!sectionId) {
      return;
    }
    const targetSelector = `#${CSS.escape(sectionId)}`;
    const stream = document.querySelector("#topic .post-stream, .post-stream");
    if (!stream) {
      return;
    }

    // Avoid duplicate observers on the same stream+id by keying the map with the selector
    if (activeObservers.has(targetSelector)) {
      return;
    }

    const observer = new MutationObserver((mutations) => {
      for (const mutation of mutations) {
        if (mutation.type === "childList") {
          // Check if our target section now exists
          const section = stream.querySelector(targetSelector);
          if (section) {
            log.debug(`Section found by ID, attempting injection`);
            const res = injectEmbeddedReplyButtons(section);
            if (res.reason !== "success" && res.reason !== "already-bound") {
              setupSectionChildObserver(section);
            }
            observer.disconnect();
            activeObservers.delete(targetSelector);
            return;
          }
        }
      }
    });

    observer.observe(stream, { childList: true, subtree: true });
    activeObservers.set(targetSelector, observer);
  }

  // Observe a specific embedded section until collapse button appears, then inject and stop
  function setupSectionChildObserver(section) {
    if (!section) {
      return;
    }
    if (activeObservers.has(section)) {
      return;
    }

    log.debug(`Waiting for collapse button to appear in section`);

    const observer = new MutationObserver(() => {
      // Check if collapse button is now present
      const collapseButton = section.querySelector(".widget-button.collapse-up, button.collapse-up, .collapse-embedded-posts");
      if (collapseButton) {
        log.debug(`Collapse button detected, injecting reply button`);
        injectEmbeddedReplyButtons(section);
        observer.disconnect();
        activeObservers.delete(section);
      }
    });

    observer.observe(section, { childList: true, subtree: true });
    activeObservers.set(section, observer);
  }

  // Global delegated click handler for embedded reply buttons
  if (!globalClickHandlerBound) {
    document.addEventListener(
      "click",
      async (e) => {
        const btn = e.target?.closest?.(".embedded-reply-button");
        if (!btn) return;

        e.preventDefault();
        e.stopPropagation();

        log.debug(`Section-level reply button clicked`);
        log.debug(`Button element:`, btn);
        log.debug(`Button dataset:`, btn.dataset);
        log.debug(`Button data-owner-post-number:`, btn.dataset.ownerPostNumber);

        try {
          // Get required services and models
          const topic = api.container.lookup("controller:topic")?.model;
          const composer = api.container.lookup("service:composer");

          if (!topic || !composer) {
            log.debug(`Topic or composer not available`);
            return;
          }

          // Get the owner post number from the button's data attribute
          const ownerPostNumber = btn.dataset.ownerPostNumber ? Number(btn.dataset.ownerPostNumber) : null;
          log.debug(`Parsed owner post number:`, ownerPostNumber);

          if (!ownerPostNumber) {
            log.error(`Owner post number not found on button`);
            log.error(`Button HTML:`, btn.outerHTML);
            log.error(`All button attributes:`, Array.from(btn.attributes).map(a => `${a.name}="${a.value}"`));
            return;
          }

          log.debug(`Replying to owner post #${ownerPostNumber}`);

          // Find the owner post model
          let ownerPost = topic.postStream?.posts?.find(
            (p) => p.post_number === ownerPostNumber
          );

          // If owner post is not in the stream, try fetching it
          if (!ownerPost) {
            try {
              const store = api.container.lookup("service:store");
              const topicPosts = await store.query("post", {
                topic_id: topic.id,
                post_ids: [ownerPostNumber]
              });

              if (topicPosts && topicPosts.length > 0) {
                ownerPost = topicPosts.find(p => p.post_number === ownerPostNumber);
              }
            } catch (fetchError) {
              log.debug(`Failed to fetch owner post:`, fetchError);
            }

            // If we still don't have the owner post, use shared function with null post
            if (!ownerPost) {
              try {
                await openReplyToOwnerPost(topic, null, ownerPostNumber);
                return;
              } catch (composerError) {
                log.debug(`Failed to open composer:`, composerError);
                return;
              }
            }
          }

          // Use shared function to open composer
          await openReplyToOwnerPost(topic, ownerPost, ownerPostNumber);
        } catch (error) {
          log.debug(`Error opening composer:`, error);
        }
      },
      true // Use capture phase
    );

    globalClickHandlerBound = true;
  }

  // Delegated click handler for "show replies" buttons
  if (!showRepliesClickHandlerBound) {
    document.addEventListener("click", (e) => {
      // Check if click is on show-replies button or load-more-replies
      const showRepliesBtn = e.target?.closest?.(".post-controls .show-replies, .show-replies, .post-action-menu__show-replies");
      const loadMoreBtn = e.target?.closest?.(".embedded-posts .load-more-replies");

      if (!showRepliesBtn && !loadMoreBtn) return;

      const clickedBtn = showRepliesBtn || loadMoreBtn;

      // Only process in owner comment mode
      const isOwnerCommentMode = document.body.dataset.ownerCommentMode === "true";
      if (!isOwnerCommentMode) {
        return;
      }

      // Try to find the parent post element
      let postElement = clickedBtn.closest("article.topic-post");
      if (!postElement) {
        // Fallback 1: any ancestor with data-post-number
        postElement = clickedBtn.closest("[data-post-number]");
      }

      // Fallback 2: derive from aria-controls
      const controlsId = clickedBtn.getAttribute("aria-controls");
      if (!postElement && controlsId) {
        const m = controlsId.match(/--(\d+)$/);
        if (m) {
          const derivedPostNumber = m[1];
          postElement = document.querySelector(`article.topic-post[data-post-number="${derivedPostNumber}"]`) ||
                        document.querySelector(`[data-post-number="${derivedPostNumber}"]`);
        }
      }

      if (!postElement) {
        if (controlsId) {
          setupSectionObserverById(controlsId);
        }
        return;
      }

      log.debug(`Show replies button clicked for post #${postElement?.dataset?.postNumber}`);

      // Check if embedded posts already exist (fast path)
      schedule("afterRender", () => {
        const existingSection = postElement.querySelector("section.embedded-posts");
        if (existingSection) {
          log.debug(`Embedded section already exists, attempting injection`);
          const res = injectEmbeddedReplyButtons(existingSection);
          if (res.reason !== "success" && res.reason !== "already-bound") {
            setupSectionChildObserver(existingSection);
          }
        } else {
          log.debug(`Embedded section not yet rendered, setting up observer`);
          setupPostObserver(postElement);
          // Also set up a fallback observer using aria-controls if available
          if (controlsId) {
            setupSectionObserverById(controlsId);
          }
        }
      });

    }, true); // Use capture phase

    showRepliesClickHandlerBound = true;
  }

  // Delegated click handler for standard reply buttons (intercept in filtered view)
  if (!standardReplyInterceptBound) {
    document.addEventListener(
      "click",
      async (e) => {
        const btn = e.target?.closest?.(".post-action-menu__reply");
        if (!btn) return;

        // Guard 1: Only intercept in owner comment mode
        const isOwnerCommentMode = document.body.dataset.ownerCommentMode === "true";
        if (!isOwnerCommentMode) {
          log.debug(`Standard reply - not in owner mode, allowing default`);
          return;
        }

        // Guard 2: Find post element or derive postNumber (multi-fallback approach)
        let postElement = btn.closest("article.topic-post,[data-post-number],[data-post-id],li[id^='post_'],article[id^='post_']");
        let postNumber = postElement ? extractPostNumberFromElement(postElement) : null;

        // Fallback 1: Try data attributes on button itself
        if (!postNumber) {
          postNumber = Number(btn.dataset?.postNumber || btn.getAttribute("data-post-number"));
        }

        // Fallback 2: Parse aria-label (e.g., "Reply to post #814 by @username")
        if (!postNumber) {
          const ariaLabel = btn.getAttribute("aria-label");
          const match = ariaLabel && ariaLabel.match(/post\s*#?(\d+)/i);
          if (match) {
            postNumber = Number(match[1]);
            log.debug(`Standard reply - derived postNumber ${postNumber} from aria-label`);
          }
        }

        // Fallback 3: If we have postNumber but no element, resolve globally
        if (!postElement && postNumber) {
          postElement = document.querySelector(
            `article.topic-post[data-post-number="${postNumber}"],[data-post-number="${postNumber}"],#post_${postNumber}`
          );
          if (postElement) {
            log.debug(`Standard reply - resolved postElement globally for post #${postNumber}`);
          }
        }

        if (!postElement && !postNumber) {
          log.debug(`Standard reply - no post element or number found`);
          return;
        }

        // Guard 3: Get topic and verify data availability
        const topic = api.container.lookup("controller:topic")?.model;
        const topicOwnerId = topic?.details?.created_by?.id;

        if (!postNumber || !topic || !topicOwnerId) {
          log.debug(`Standard reply - missing required data`);
          return;
        }

        // Guard 4: Check if this is an owner post
        const post = topic.postStream?.posts?.find(p => p.post_number === postNumber);
        const isOwnerPost = post?.user_id === topicOwnerId;

        if (!isOwnerPost) {
          log.debug(`Standard reply - not owner post, allowing default`);
          return;
        }

        // All guards passed - intercept the click!
        log.info(`Standard reply intercepted for owner post #${postNumber}`);

        // Prevent default Discourse behavior
        e.preventDefault();
        e.stopPropagation();

        // Detect if embedded section is collapsed
        const section = postElement?.querySelector("section.embedded-posts");
        const hasToggleBtn = postElement?.querySelector(
          ".post-controls .show-replies, .show-replies, .post-action-menu__show-replies"
        );
        const isCollapsed = !section || !!hasToggleBtn;

        if (isCollapsed) {
          log.debug(`Detected collapsed embedded section for post #${postNumber}`);
          replyToCollapsedSection = true;
          replyOwnerPostNumberForExpand = postNumber;
        } else {
          log.debug(`Embedded section is expanded for post #${postNumber}`);
          replyToCollapsedSection = false;
          replyOwnerPostNumberForExpand = null;
        }

        // Set suppression flag for post-creation handling
        suppressStandardReplyScroll = true;
        suppressedReplyPostNumber = postNumber;
        log.debug(`Set suppression flag for post #${postNumber}`);

        try {
          // Use shared function to open composer (same as embedded button)
          await openReplyToOwnerPost(topic, post, postNumber);
        } catch (error) {
          log.error(`Error opening composer for standard reply:`, error);
          // Clear suppression flag on error
          suppressStandardReplyScroll = false;
          suppressedReplyPostNumber = null;
        }
      },
      true // Use capture phase for early interception
    );

    standardReplyInterceptBound = true;
    log.debug(`Standard reply interceptor bound`);
  }

  // Inject reply buttons into embedded posts on page changes (for already-expanded sections)
  api.onPageChange(() => {
    // Clean up old observers
    activeObservers.forEach((observer) => {
      observer.disconnect();
    });
    activeObservers.clear();

    // Clear collapsed section expansion state on navigation
    if (replyToCollapsedSection || replyOwnerPostNumberForExpand || expandOrchestratorActive) {
      log.debug(`onPageChange: clearing stale collapsed expansion state`);
      finalizeCollapsedFlow();
    }

    schedule("afterRender", () => {
      // Check if we're in owner comment mode (filtered view)
      const isOwnerCommentMode =
        document.body.dataset.ownerCommentMode === "true";

      if (!isOwnerCommentMode) {
        log.debug(`Not in owner comment mode, skipping injection`);
        return;
      }

      // Find all embedded post sections that are already expanded
      const embeddedSections = document.querySelectorAll(
        "section.embedded-posts"
      );

      if (embeddedSections.length === 0) {
        log.debug(`No embedded sections found on page`);
        return;
      }

      log.debug(`Found ${embeddedSections.length} embedded section(s), injecting buttons`);

      // Inject buttons into each section
      let successCount = 0;
      embeddedSections.forEach((section) => {
        const res = injectEmbeddedReplyButtons(section);
        if (res.reason === "success") {
          successCount++;
        } else if (res.reason !== "already-bound") {
          setupSectionChildObserver(section);
        }
      });

      log.debug(`Injected ${successCount} button(s) on page load`);
    });
  });

  // Auto-refresh embedded posts after reply submission
  if (!composerEventsBound) {
    log.info(`AutoRefresh: initializing composer event listeners`);
    const appEvents = api.container.lookup("service:app-events");

    if (appEvents) {
      // Listen to post:created to capture the newly created post details
      log.debug(`AutoScroll: binding post:created listener`);
      appEvents.on("post:created", (createdPost) => {
        const isOwnerCommentMode = document.body.dataset.ownerCommentMode === "true";
        log.debug(`AutoScroll: post:created fired`, {
          post_number: createdPost?.post_number,
          reply_to_post_number: createdPost?.reply_to_post_number,
          topic_id: createdPost?.topic_id,
          isOwnerCommentMode
        });

        if (!isOwnerCommentMode) {
          log.debug(`AutoScroll: skipping - not in owner comment mode`);
          return;
        }

        // Store the newly created post details for auto-scroll
        lastCreatedPost = {
          topicId: createdPost?.topic_id,
          postNumber: createdPost?.post_number,
          postId: createdPost?.id || createdPost?.post_id,
          replyToPostNumber: createdPost?.reply_to_post_number,
          timestamp: Date.now()
        };
        log.debug(`AutoScroll: stored lastCreatedPost`, lastCreatedPost);
      });

      log.debug(`AutoRefresh: app-events service available, binding composer:saved`);
      appEvents.on("composer:saved", (post) => {
        try {

        log.info(`AutoRefresh: binding composer:saved handler`);

        // Check and consume suppression flag from standard reply interception
        if (suppressStandardReplyScroll) {
          log.info(`Standard reply suppression active - preventing default scroll`);
          log.info(`Suppressed post number: ${suppressedReplyPostNumber}`);
          suppressStandardReplyScroll = false;
          suppressedReplyPostNumber = null;
          // Continue with embedded refresh logic below
        }

        // Only process in owner comment mode
        const isOwnerCommentMode = document.body.dataset.ownerCommentMode === "true";
        log.info(`AutoRefresh: composer:saved fired`, { id: post?.id, post_number: post?.post_number, reply_to_post_number: post?.reply_to_post_number, isOwnerCommentMode });
        if (!isOwnerCommentMode) {
          log.info(`AutoRefresh: skipping - not in owner comment mode`);
          return;
        }

        // Derive parent post number from multiple sources (fallback chain)
        const composerSvc = api.container.lookup("service:composer");
        const composerModel = composerSvc?.model;
        log.info(`AutoRefresh: composer.model snapshot`, {
          action: composerModel?.action,
          replyToPostNumber: composerModel?.replyToPostNumber,
          post_number: composerModel?.post?.post_number,
          topic_id: composerModel?.topic?.id,
        });

        let parentPostNumber = null;
        let parentSource = null;

        if (post?.reply_to_post_number) {
          parentPostNumber = post.reply_to_post_number;
          parentSource = "event.reply_to_post_number";
        } else if (composerModel?.replyToPostNumber) {
          parentPostNumber = composerModel.replyToPostNumber;
          parentSource = "composer.model.replyToPostNumber";
        } else if (composerModel?.post?.post_number) {
          parentPostNumber = composerModel.post.post_number;
          parentSource = "composer.model.post.post_number";
        } else {
          const currentTopic = api.container.lookup("controller:topic")?.model;
          if (currentTopic && lastReplyContext.topicId === currentTopic.id) {
            parentPostNumber = lastReplyContext.parentPostNumber;
            parentSource = "lastReplyContext";
            log.info(`AutoRefresh: using lastReplyContext fallback`, lastReplyContext);
          }
        }

        if (!parentPostNumber) {
          log.info(`AutoRefresh: skipping - could not determine parent post number`);
          return;
        }

        log.info(`AutoRefresh: target parent post #${parentPostNumber} (source: ${parentSource})`);

        // In filtered view, the embedded post we replied to is NOT a standalone article.topic-post
        // Instead, it's embedded inside an owner's post in section.embedded-posts
        // We need to find which owner's post contains this embedded post

        let ownerPostElement = null;

        // Strategy 0: If we captured the owner's post number during click, use it directly
        if (lastReplyContext?.ownerPostNumber) {
          ownerPostElement = document.querySelector(
            `article.topic-post[data-post-number="${lastReplyContext.ownerPostNumber}"]`
          );
          if (ownerPostElement) {
            log.debug(`AutoRefresh: using ownerPostNumber from lastReplyContext -> #${lastReplyContext.ownerPostNumber}`);
          }
        }

        // Strategy 0b: Prefer direct lookup by parent post number; section scanning may fail when collapsed
        if (!ownerPostElement) {
          ownerPostElement = document.querySelector(`article.topic-post[data-post-number="${parentPostNumber}"]`)
            || document.querySelector(`#post_${parentPostNumber}`)?.closest?.("article.topic-post, article")
            || document.querySelector(`#post-${parentPostNumber}`)?.closest?.("article.topic-post, article")
            || document.querySelector(`[data-post-number="${parentPostNumber}"]`)?.closest?.("article.topic-post, article");
          if (ownerPostElement) {
            log.debug(`AutoRefresh: direct owner post lookup succeeded for #${parentPostNumber}`);
          }
        }

        // Strategy 1: Try to find the embedded post element by data-post-number or data-post-id inside sections
        // Hoist sections outside the conditional and iterate safely
        const allEmbeddedSections = document.querySelectorAll("section.embedded-posts");
        log.debug(`AutoRefresh: found ${allEmbeddedSections.length} embedded-posts sections`);

        if (!ownerPostElement) {
          for (const section of allEmbeddedSections) {
            const embeddedPost = section.querySelector(
              `[data-post-number="${parentPostNumber}"], #post_${parentPostNumber}, #post-${parentPostNumber}`
            );
            if (embeddedPost) {
              ownerPostElement = section.closest("article.topic-post");
              log.debug(`AutoRefresh: found embedded post #${parentPostNumber} inside owner post #${ownerPostElement?.dataset?.postNumber}`);
              break;
            }
          }
        }

        // Strategy 1b: Match section.id pattern (e.g., "embedded-posts--<ownerPostNumber>")
        if (!ownerPostElement) {
          for (const section of allEmbeddedSections) {
            if (section.id && /--(\d+)$/.test(section.id)) {
              const m = section.id.match(/--(\d+)$/);
              if (m && Number(m[1]) === Number(parentPostNumber)) {
                ownerPostElement = section.closest("article.topic-post") || section.closest("article") || section.parentElement;
                log.debug(`AutoRefresh: matched owner post by section.id -> #${parentPostNumber}`);
                break;
              }
            }
          }
        }

        // Strategy 1c: Removed single-section fallback to prevent wrong owner selection when only one embedded section is present
        // (When collapsed, scanning sections is unreliable; we rely on direct owner lookup instead.)

        // Strategy 2: Direct lookups for the owner post element
        if (!ownerPostElement) {
          ownerPostElement = document.querySelector(`article.topic-post[data-post-number="${parentPostNumber}"]`)
            || document.querySelector(`#post_${parentPostNumber}`)?.closest?.("article.topic-post, article")
            || document.querySelector(`#post-${parentPostNumber}`)?.closest?.("article.topic-post, article")
            || document.querySelector(`[data-post-number="${parentPostNumber}"]`)?.closest?.("article.topic-post, article");
          if (ownerPostElement) {
            log.debug(`AutoRefresh: found owner post via direct lookup variants for #${parentPostNumber}`);
          }
        }

        if (!ownerPostElement) {
          log.debug(`AutoRefresh: could not find owner post containing embedded post #${parentPostNumber}`);
          return;
        }
        log.debug(`AutoRefresh: targeting owner post #${ownerPostElement.dataset?.postNumber || ownerPostElement.id || "(unknown)"} for refresh`);

        // Decide expansion based on current DOM state (more robust than stored flags)
        let ownerPostNumber = Number(ownerPostElement?.dataset?.postNumber);
        // Fallbacks if dataset is missing
        let toggleBtnForInference = ownerPostElement.querySelector(
          ".post-action-menu__show-replies, .show-replies, .post-action-menu__show-replies"
        );
        if (!ownerPostNumber) {
          const ac = toggleBtnForInference?.getAttribute("aria-controls") || "";
          const m = ac.match(/--(\d+)$/);
          if (m) {
            ownerPostNumber = Number(m[1]);
          }
        }
        if (!ownerPostNumber) {
          ownerPostNumber = Number(lastReplyContext?.ownerPostNumber) || Number(lastReplyContext?.parentPostNumber) || null;
        }

        const sectionNow = ownerPostElement.querySelector("section.embedded-posts");
        const hasToggleNow = toggleBtnForInference;
        const collapsedNow = !sectionNow || !!hasToggleNow;

        if (collapsedNow) {
          log.info(`AutoRefresh: collapsed detected for owner post #${ownerPostNumber} — expanding and loading replies`);

          // Prevent duplicate orchestration
          if (expandOrchestratorActive) {
            log.debug(`AutoRefresh: expansion already in progress, skipping`);
            return;
          }
          expandOrchestratorActive = true;

          // Orchestrate: expand → load all → scroll → hide duplicate
          schedule("afterRender", async () => {
            try {
              // Step 1: Expand the collapsed section
              log.debug(`AutoRefresh: Step 1 - Expanding collapsed section for post #${ownerPostNumber}`);
              const expanded = await expandEmbeddedReplies(ownerPostElement, { timeoutMs: 5000 });

              if (!expanded) {
                log.warn(`AutoRefresh: expansion failed for post #${ownerPostNumber}, attempting best-effort`);
                // Hide duplicate anyway
                if (lastCreatedPost?.postNumber || lastCreatedPost?.postId) {
                  hideMainStreamDuplicateInOwnerMode(lastCreatedPost.postNumber, lastCreatedPost.postId);
                }
                finalizeCollapsedFlow();
                return;
              }

              // Step 2: Load all replies
              log.debug(`AutoRefresh: Step 2 - Loading all replies for post #${ownerPostNumber}`);
              const allLoaded = await loadAllEmbeddedReplies(ownerPostElement, { maxClicks: 20, timeoutMs: 10000 });

              if (!allLoaded) {
                log.warn(`AutoRefresh: loading all replies timed out or reached max clicks for post #${ownerPostNumber}`);
                // Continue anyway - the new post might already be visible
              }

              // Step 3: Scroll to new reply (best-effort; falls back to bottom)
              const section = ownerPostElement.querySelector("section.embedded-posts");
              if (section) {
                if (lastCreatedPost?.postNumber) {
                  log.debug(`AutoRefresh: Step 3 - Attempting to scroll to new post #${lastCreatedPost.postNumber}`);
                  const scrolled = tryScrollToNewReply(section);

                  if (!scrolled) {
                    log.debug(`AutoRefresh: immediate scroll failed, setting up observer`);
                    const scrollObserver = new MutationObserver(() => {
                      if (tryScrollToNewReply(section)) {
                        log.debug(`AutoRefresh: observer successfully scrolled to new post`);
                        scrollObserver.disconnect();
                      }
                    });

                    scrollObserver.observe(section, {
                      childList: true,
                      subtree: true
                    });

                    // Timeout for observer
                    setTimeout(() => {
                      log.debug(`AutoRefresh: scroll observer timeout`);
                      scrollObserver.disconnect();
                      lastCreatedPost = null;
                    }, 10000);
                  }
                } else {
                  // Fallback: scroll to bottom of section to reveal latest reply
                  section.lastElementChild?.scrollIntoView({ block: "end", behavior: "smooth" });
                }
              }

              // Step 4: Hide duplicate in main stream
              if (lastCreatedPost?.postNumber || lastCreatedPost?.postId) {
                hideMainStreamDuplicateInOwnerMode(lastCreatedPost.postNumber, lastCreatedPost.postId);
              }

              // Clear collapsed flow state
              finalizeCollapsedFlow();
            } catch (err) {
              log.error(`AutoRefresh: error in collapsed flow orchestration`, err);
              finalizeCollapsedFlow();
            }
          });

          return; // Exit early - collapsed flow is handled above
        }

        // Normal flow (expanded section) - existing logic continues below
        // Wait for DOM to update, then trigger "load more replies"
        schedule("afterRender", () => {
          // Try to find the "load more replies" button in the owner's post
          log.debug(`AutoRefresh: schedule(afterRender) start for owner post #${ownerPostElement.dataset.postNumber}`);
          const embeddedSection = ownerPostElement.querySelector("section.embedded-posts");
          log.debug(`AutoRefresh: embeddedSection ${embeddedSection ? "found" : "NOT found"}`);
          const loadMoreBtn = embeddedSection?.querySelector(".load-more-replies");
          log.debug(`AutoRefresh: loadMoreBtn ${loadMoreBtn ? "found" : "NOT found"}`);

          if (loadMoreBtn) {
            // Clear stored context after handling to avoid stale data
            lastReplyContext = { topicId: null, parentPostNumber: null };
            log.debug(`AutoRefresh: cleared lastReplyContext`);

            log.debug(`AutoRefresh: clicking loadMoreBtn immediately`);
            const ok = robustClick(loadMoreBtn);
            log.debug(`AutoRefresh: robustClick(loadMoreBtn) =>`, ok);

            // After clicking, try to scroll to the new post or set up observer
            if (embeddedSection) {
              // Try immediate scroll (in case post is already rendered)
              if (!tryScrollToNewReply(embeddedSection)) {
                // If not found yet, set up observer to scroll when it appears
                log.debug(`AutoScroll: setting up observer for new post after load-more click`);
                const scrollObserver = new MutationObserver(() => {
                  if (tryScrollToNewReply(embeddedSection)) {
                    log.debug(`AutoScroll: observer successfully scrolled to new post`);
                    scrollObserver.disconnect();
                  }
                });

                scrollObserver.observe(embeddedSection, {
                  childList: true,
                  subtree: true
                });

                // Timeout to prevent infinite observation (10 seconds)
                setTimeout(() => {
                  log.debug(`AutoScroll: observer timeout - new post not found within 10s`);
                  scrollObserver.disconnect();
                  // Clear stale state
                  lastCreatedPost = null;
                }, 10000);
              }
            }
          } else {
            // If button doesn't exist yet, set up an observer to wait for it
            log.debug(`AutoRefresh: waiting for loadMoreBtn via MutationObserver`);
            const observer = new MutationObserver(() => {
              const btn = ownerPostElement.querySelector(
                "section.embedded-posts .load-more-replies"
              );

              if (btn) {
                log.debug(`AutoRefresh: observer found loadMoreBtn, clicking`);
                // Clear stored context before clicking
                lastReplyContext = { topicId: null, parentPostNumber: null };
                log.debug(`AutoRefresh: cleared lastReplyContext`);
                const ok2 = robustClick(btn);
                log.debug(`AutoRefresh: robustClick(observer btn) =>`, ok2);
                observer.disconnect();

                // After clicking, set up scroll observer
                const section = ownerPostElement.querySelector("section.embedded-posts");
                if (section) {
                  // Try immediate scroll
                  if (!tryScrollToNewReply(section)) {
                    // Set up observer to scroll when new post appears
                    log.debug(`AutoScroll: setting up observer for new post after delayed load-more click`);
                    const scrollObserver = new MutationObserver(() => {
                      if (tryScrollToNewReply(section)) {
                        log.debug(`AutoScroll: observer successfully scrolled to new post`);
                        scrollObserver.disconnect();
                      }
                    });

                    scrollObserver.observe(section, {
                      childList: true,
                      subtree: true
                    });

                    // Timeout to prevent infinite observation (10 seconds)
                    setTimeout(() => {
                      log.debug(`AutoScroll: observer timeout - new post not found within 10s`);
                      scrollObserver.disconnect();
                      // Clear stale state
                      lastCreatedPost = null;
                    }, 10000);
                  }
                }
              }
            });

            observer.observe(ownerPostElement, {
              childList: true,
              subtree: true
            });

            // Timeout to prevent infinite observation (5 seconds)
            setTimeout(() => {
              log.debug(`AutoRefresh: observer timeout - loadMoreBtn not found within 5s`);
              observer.disconnect();
            }, 5000);
          }
        });
      } catch (err) {
        log.error(`AutoRefresh: error inside composer:saved`, err);
      }
      });

      composerEventsBound = true;
    }
  }
});

