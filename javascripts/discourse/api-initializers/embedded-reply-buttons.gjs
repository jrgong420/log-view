import { apiInitializer } from "discourse/lib/api";
import { schedule } from "@ember/runloop";

export default apiInitializer("1.14.0", (api) => {
  let globalClickHandlerBound = false;
  let showRepliesClickHandlerBound = false;
  let composerEventsBound = false;

  // Map to track active MutationObservers per post
  const activeObservers = new Map();
  const LOG_PREFIX = "[Embedded Reply Buttons]";
  // Module-scoped state to remember last reply parent for fallback
  let lastReplyContext = { topicId: null, parentPostNumber: null };
  // Module-scoped state to track newly created post for auto-scroll
  let lastCreatedPost = null;

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
      console.log(`${LOG_PREFIX} AutoScroll: no lastCreatedPost to scroll to`);
      return false;
    }

    console.log(`${LOG_PREFIX} AutoScroll: searching for post #${lastCreatedPost.postNumber} in section`);

    // Build selector to find the newly created post
    const selectors = [
      `[data-post-number="${lastCreatedPost.postNumber}"]`,
      `#post_${lastCreatedPost.postNumber}`,
      `#post-${lastCreatedPost.postNumber}`
    ];

    let foundElement = null;
    for (const selector of selectors) {
      foundElement = section.querySelector(selector);
      if (foundElement) {
        console.log(`${LOG_PREFIX} AutoScroll: found element with selector: ${selector}`);
        break;
      }
    }

    if (foundElement) {
      console.log(`${LOG_PREFIX} AutoScroll: scrolling to post #${lastCreatedPost.postNumber}`);

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

      // Clear the state to avoid repeated scrolls
      console.log(`${LOG_PREFIX} AutoScroll: clearing lastCreatedPost after successful scroll`);
      lastCreatedPost = null;
      return true;
    }

    console.log(`${LOG_PREFIX} AutoScroll: post #${lastCreatedPost.postNumber} not found in section yet`);
    return false;
  }

  // Function to inject a single reply button at the section level
  function injectEmbeddedReplyButtons(section) {
    // Skip if section already has a reply button
    if (!section || section.dataset.replyBtnBound || section.querySelector(".embedded-reply-button")) {
      console.log(`${LOG_PREFIX} Section already has reply button, skipping injection`);
      return { injected: 0, reason: "already-bound" };
    }

    // Find the collapse button to position our button next to it
    const collapseButton = section.querySelector(".widget-button.collapse-up, button.collapse-up, .collapse-embedded-posts");

    if (!collapseButton) {
      console.log(`${LOG_PREFIX} Collapse button not found in section, will append to section`);
    }

    // Create the reply button
    const btn = document.createElement("button");
    btn.className = "btn btn-small embedded-reply-button";
    btn.type = "button";
    btn.textContent = "Reply";
    btn.title = "Reply to owner's post";
    btn.setAttribute("aria-label", "Reply to owner's post");

    // Store the owner post number on the button for easy retrieval
    console.log(`${LOG_PREFIX} Attempting to find owner post for section:`, section);
    console.log(`${LOG_PREFIX} Section ID:`, section.id);
    console.log(`${LOG_PREFIX} Section classes:`, section.className);

    const ownerPost = getOwnerPostFromSection(section);
    console.log(`${LOG_PREFIX} Owner post element:`, ownerPost);

    let ownerPostNumber = null;

    if (ownerPost) {
      ownerPostNumber = extractPostNumberFromElement(ownerPost);
      console.log(`${LOG_PREFIX} Extracted owner post number from element:`, ownerPostNumber);

      if (!ownerPostNumber) {
        console.warn(`${LOG_PREFIX} Could not extract post number from owner post element`);
        console.warn(`${LOG_PREFIX} Owner post dataset:`, ownerPost.dataset);
        console.warn(`${LOG_PREFIX} Owner post id:`, ownerPost.id);
        console.warn(`${LOG_PREFIX} Owner post attributes:`, Array.from(ownerPost.attributes).map(a => `${a.name}="${a.value}"`));
      }
    } else {
      console.warn(`${LOG_PREFIX} Could not find owner post element (article.topic-post) for section`);
      console.warn(`${LOG_PREFIX} Section parent elements:`, section.parentElement, section.parentElement?.parentElement);

      // Fallback: Try to extract from section ID (e.g., "embedded-posts--123")
      if (section.id) {
        const match = section.id.match(/--(\d+)$/);
        if (match) {
          ownerPostNumber = Number(match[1]);
          console.log(`${LOG_PREFIX} Extracted owner post number from section ID:`, ownerPostNumber);
        }
      }
    }

    if (ownerPostNumber) {
      btn.dataset.ownerPostNumber = String(ownerPostNumber);
      console.log(`${LOG_PREFIX} Successfully stored owner post number ${ownerPostNumber} on button`);
      console.log(`${LOG_PREFIX} Button data-owner-post-number attribute:`, btn.dataset.ownerPostNumber);
      console.log(`${LOG_PREFIX} Button element after setting attribute:`, btn);
    } else {
      console.error(`${LOG_PREFIX} CRITICAL: Could not determine owner post number - button will not work!`);
      console.error(`${LOG_PREFIX} Section:`, section);
      console.error(`${LOG_PREFIX} Owner post:`, ownerPost);
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

        console.log(`${LOG_PREFIX} Created button container and injected reply button`);
      } else {
        // Collapse button is already in a container
        // Just insert our button before it
        buttonContainer.insertBefore(btn, collapseButton);

        // Ensure the container has proper flex layout
        if (!buttonContainer.classList.contains("embedded-posts-controls")) {
          buttonContainer.classList.add("embedded-posts-controls");
        }

        console.log(`${LOG_PREFIX} Injected reply button into existing container`);
      }
    } else {
      // Fallback: create a container at the end of the section
      const wrapper = document.createElement("div");
      wrapper.className = "embedded-posts-controls";
      wrapper.appendChild(btn);
      section.appendChild(wrapper);
      console.log(`${LOG_PREFIX} Created button container at end of section (collapse button not found)`);
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
                console.log(`${LOG_PREFIX} Embedded section detected, attempting injection`);
                const res = injectEmbeddedReplyButtons(node);
                if (res.reason === "success") {
                  console.log(`${LOG_PREFIX} Button injected successfully`);
                  observer.disconnect();
                  activeObservers.delete(postElement);
                } else if (res.reason === "already-bound") {
                  console.log(`${LOG_PREFIX} Section already has button`);
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
                    console.log(`${LOG_PREFIX} Embedded section detected (nested), attempting injection`);
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
    console.log(`${LOG_PREFIX} Set up observer for post element`);
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
            console.log(`${LOG_PREFIX} Section found by ID, attempting injection`);
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

    console.log(`${LOG_PREFIX} Waiting for collapse button to appear in section`);

    const observer = new MutationObserver(() => {
      // Check if collapse button is now present
      const collapseButton = section.querySelector(".widget-button.collapse-up, button.collapse-up, .collapse-embedded-posts");
      if (collapseButton) {
        console.log(`${LOG_PREFIX} Collapse button detected, injecting reply button`);
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

        console.log(`${LOG_PREFIX} Section-level reply button clicked`);
        console.log(`${LOG_PREFIX} Button element:`, btn);
        console.log(`${LOG_PREFIX} Button dataset:`, btn.dataset);
        console.log(`${LOG_PREFIX} Button data-owner-post-number:`, btn.dataset.ownerPostNumber);

        try {
          // Get required services and models
          const topic = api.container.lookup("controller:topic")?.model;
          const composer = api.container.lookup("service:composer");

          if (!topic || !composer) {
            console.log(`${LOG_PREFIX} Topic or composer not available`);
            return;
          }

          // Get the owner post number from the button's data attribute
          const ownerPostNumber = btn.dataset.ownerPostNumber ? Number(btn.dataset.ownerPostNumber) : null;
          console.log(`${LOG_PREFIX} Parsed owner post number:`, ownerPostNumber);

          if (!ownerPostNumber) {
            console.error(`${LOG_PREFIX} Owner post number not found on button`);
            console.error(`${LOG_PREFIX} Button HTML:`, btn.outerHTML);
            console.error(`${LOG_PREFIX} All button attributes:`, Array.from(btn.attributes).map(a => `${a.name}="${a.value}"`));
            return;
          }

          console.log(`${LOG_PREFIX} Replying to owner post #${ownerPostNumber}`);

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
              console.log(`${LOG_PREFIX} Failed to fetch owner post:`, fetchError);
            }

            // If we still don't have the owner post, try opening composer with just the post number
            if (!ownerPost) {
              try {
                // Store context for auto-refresh fallback before opening composer
                lastReplyContext = { topicId: topic.id, parentPostNumber: ownerPostNumber, ownerPostNumber };
                console.log(`${LOG_PREFIX} AutoRefresh: stored lastReplyContext (early path)`, lastReplyContext);

                await composer.open({
                  action: "reply",
                  topic: topic,
                  draftKey: topic.draft_key,
                  draftSequence: topic.draft_sequence,
                  skipJumpOnSave: true,
                  replyToPostNumber: ownerPostNumber,
                });
                return;
              } catch (composerError) {
                console.log(`${LOG_PREFIX} Failed to open composer:`, composerError);
                return;
              }
            }
          }

          // Open the composer
          const composerOptions = {
            action: "reply",
            topic: topic,
            draftKey: topic.draft_key,
            draftSequence: topic.draft_sequence,
            skipJumpOnSave: true,
          };

          // Remember context for auto-refresh fallback
          lastReplyContext = { topicId: topic.id, parentPostNumber: ownerPostNumber, ownerPostNumber };
          console.log(`${LOG_PREFIX} AutoRefresh: stored lastReplyContext`, lastReplyContext);

          if (ownerPost) {
            composerOptions.post = ownerPost;
          }

          await composer.open(composerOptions);
          console.log(`${LOG_PREFIX} Composer opened successfully`);
        } catch (error) {
          console.log(`${LOG_PREFIX} Error opening composer:`, error);
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

      console.log(`${LOG_PREFIX} Show replies button clicked for post #${postElement?.dataset?.postNumber}`);

      // Check if embedded posts already exist (fast path)
      schedule("afterRender", () => {
        const existingSection = postElement.querySelector("section.embedded-posts");
        if (existingSection) {
          console.log(`${LOG_PREFIX} Embedded section already exists, attempting injection`);
          const res = injectEmbeddedReplyButtons(existingSection);
          if (res.reason !== "success" && res.reason !== "already-bound") {
            setupSectionChildObserver(existingSection);
          }
        } else {
          console.log(`${LOG_PREFIX} Embedded section not yet rendered, setting up observer`);
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

  // Inject reply buttons into embedded posts on page changes (for already-expanded sections)
  api.onPageChange(() => {
    // Clean up old observers
    activeObservers.forEach((observer) => {
      observer.disconnect();
    });
    activeObservers.clear();

    schedule("afterRender", () => {
      // Check if we're in owner comment mode (filtered view)
      const isOwnerCommentMode =
        document.body.dataset.ownerCommentMode === "true";

      if (!isOwnerCommentMode) {
        console.log(`${LOG_PREFIX} Not in owner comment mode, skipping injection`);
        return;
      }

      // Find all embedded post sections that are already expanded
      const embeddedSections = document.querySelectorAll(
        "section.embedded-posts"
      );

      if (embeddedSections.length === 0) {
        console.log(`${LOG_PREFIX} No embedded sections found on page`);
        return;
      }

      console.log(`${LOG_PREFIX} Found ${embeddedSections.length} embedded section(s), injecting buttons`);

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

      console.log(`${LOG_PREFIX} Injected ${successCount} button(s) on page load`);
    });
  });

  // Auto-refresh embedded posts after reply submission
  if (!composerEventsBound) {
    console.log(`${LOG_PREFIX} AutoRefresh: initializing composer event listeners`);
    const appEvents = api.container.lookup("service:app-events");

    if (appEvents) {
      // Listen to post:created to capture the newly created post details
      console.log(`${LOG_PREFIX} AutoScroll: binding post:created listener`);
      appEvents.on("post:created", (createdPost) => {
        const isOwnerCommentMode = document.body.dataset.ownerCommentMode === "true";
        console.log(`${LOG_PREFIX} AutoScroll: post:created fired`, {
          post_number: createdPost?.post_number,
          reply_to_post_number: createdPost?.reply_to_post_number,
          topic_id: createdPost?.topic_id,
          isOwnerCommentMode
        });

        if (!isOwnerCommentMode) {
          console.log(`${LOG_PREFIX} AutoScroll: skipping - not in owner comment mode`);
          return;
        }

        // Store the newly created post details for auto-scroll
        lastCreatedPost = {
          topicId: createdPost?.topic_id,
          postNumber: createdPost?.post_number,
          replyToPostNumber: createdPost?.reply_to_post_number,
          timestamp: Date.now()
        };
        console.log(`${LOG_PREFIX} AutoScroll: stored lastCreatedPost`, lastCreatedPost);
      });

      console.log(`${LOG_PREFIX} AutoRefresh: app-events service available, binding composer:saved`);
      appEvents.on("composer:saved", (post) => {
        console.log(`${LOG_PREFIX} AutoRefresh: binding composer:saved handler`);
        // Only process in owner comment mode
        const isOwnerCommentMode = document.body.dataset.ownerCommentMode === "true";
        console.log(`${LOG_PREFIX} AutoRefresh: composer:saved fired`, { id: post?.id, post_number: post?.post_number, reply_to_post_number: post?.reply_to_post_number, isOwnerCommentMode });
        if (!isOwnerCommentMode) {
          console.log(`${LOG_PREFIX} AutoRefresh: skipping - not in owner comment mode`);
          return;
        }

        // Derive parent post number from multiple sources (fallback chain)
        const composerSvc = api.container.lookup("service:composer");
        const composerModel = composerSvc?.model;
        console.log(`${LOG_PREFIX} AutoRefresh: composer.model snapshot`, {
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
            console.log(`${LOG_PREFIX} AutoRefresh: using lastReplyContext fallback`, lastReplyContext);
          }
        }

        if (!parentPostNumber) {
          console.log(`${LOG_PREFIX} AutoRefresh: skipping - could not determine parent post number`);
          return;
        }

        console.log(`${LOG_PREFIX} AutoRefresh: target parent post #${parentPostNumber} (source: ${parentSource})`);

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
            console.log(`${LOG_PREFIX} AutoRefresh: using ownerPostNumber from lastReplyContext -> #${lastReplyContext.ownerPostNumber}`);
          }
        }

        // Strategy 1: Try to find the embedded post element by data-post-number or data-post-id inside sections
        if (!ownerPostElement) {
          const allEmbeddedSections = document.querySelectorAll("section.embedded-posts");
          console.log(`${LOG_PREFIX} AutoRefresh: found ${allEmbeddedSections.length} embedded-posts sections`);
          for (const section of allEmbeddedSections) {
            const embeddedPost = section.querySelector(
              `[data-post-number="${parentPostNumber}"], #post_${parentPostNumber}, #post-${parentPostNumber}`
            );
            if (embeddedPost) {
              ownerPostElement = section.closest("article.topic-post");
              console.log(`${LOG_PREFIX} AutoRefresh: found embedded post #${parentPostNumber} inside owner post #${ownerPostElement?.dataset?.postNumber}`);
              break;
            }
          }
        }

        for (const section of allEmbeddedSections) {
          // Check if this section contains an embedded post with our target post number
          const embeddedPost = section.querySelector(
            `[data-post-number="${parentPostNumber}"], [data-post-id], #post_${parentPostNumber}, #post-${parentPostNumber}`
          );

          if (embeddedPost) {
            // Found it! Now find the owner's post that contains this section
            ownerPostElement = section.closest("article.topic-post");
            console.log(`${LOG_PREFIX} AutoRefresh: found embedded post #${parentPostNumber} inside owner post #${ownerPostElement?.dataset?.postNumber}`);
            break;
          }
        }

        // Strategy 2: If not found in embedded sections, try direct lookup (fallback for non-filtered view)
        if (!ownerPostElement) {
          ownerPostElement = document.querySelector(
            `article.topic-post[data-post-number="${parentPostNumber}"]`
          );
          if (ownerPostElement) {
            console.log(`${LOG_PREFIX} AutoRefresh: found parent post #${parentPostNumber} as standalone article`);
          }
        }

        if (!ownerPostElement) {
          console.log(`${LOG_PREFIX} AutoRefresh: could not find owner post containing embedded post #${parentPostNumber}`);
          return;
        }
        console.log(`${LOG_PREFIX} AutoRefresh: targeting owner post #${ownerPostElement.dataset.postNumber} for refresh`);

        // Wait for DOM to update, then trigger "load more replies"
        schedule("afterRender", () => {
          // Try to find the "load more replies" button in the owner's post
          console.log(`${LOG_PREFIX} AutoRefresh: schedule(afterRender) start for owner post #${ownerPostElement.dataset.postNumber}`);
          const embeddedSection = ownerPostElement.querySelector("section.embedded-posts");
          console.log(`${LOG_PREFIX} AutoRefresh: embeddedSection ${embeddedSection ? "found" : "NOT found"}`);
          const loadMoreBtn = embeddedSection?.querySelector(".load-more-replies");
          console.log(`${LOG_PREFIX} AutoRefresh: loadMoreBtn ${loadMoreBtn ? "found" : "NOT found"}`);

          if (loadMoreBtn) {
            // Clear stored context after handling to avoid stale data
            lastReplyContext = { topicId: null, parentPostNumber: null };
            console.log(`${LOG_PREFIX} AutoRefresh: cleared lastReplyContext`);

            console.log(`${LOG_PREFIX} AutoRefresh: clicking loadMoreBtn immediately`);
            const ok = robustClick(loadMoreBtn);
            console.log(`${LOG_PREFIX} AutoRefresh: robustClick(loadMoreBtn) =>`, ok);

            // After clicking, try to scroll to the new post or set up observer
            if (embeddedSection) {
              // Try immediate scroll (in case post is already rendered)
              if (!tryScrollToNewReply(embeddedSection)) {
                // If not found yet, set up observer to scroll when it appears
                console.log(`${LOG_PREFIX} AutoScroll: setting up observer for new post after load-more click`);
                const scrollObserver = new MutationObserver(() => {
                  if (tryScrollToNewReply(embeddedSection)) {
                    console.log(`${LOG_PREFIX} AutoScroll: observer successfully scrolled to new post`);
                    scrollObserver.disconnect();
                  }
                });

                scrollObserver.observe(embeddedSection, {
                  childList: true,
                  subtree: true
                });

                // Timeout to prevent infinite observation (10 seconds)
                setTimeout(() => {
                  console.log(`${LOG_PREFIX} AutoScroll: observer timeout - new post not found within 10s`);
                  scrollObserver.disconnect();
                  // Clear stale state
                  lastCreatedPost = null;
                }, 10000);
              }
            }
          } else {
            // If button doesn't exist yet, set up an observer to wait for it
            console.log(`${LOG_PREFIX} AutoRefresh: waiting for loadMoreBtn via MutationObserver`);
            const observer = new MutationObserver(() => {
              const btn = ownerPostElement.querySelector(
                "section.embedded-posts .load-more-replies"
              );

              if (btn) {
                console.log(`${LOG_PREFIX} AutoRefresh: observer found loadMoreBtn, clicking`);
                // Clear stored context before clicking
                lastReplyContext = { topicId: null, parentPostNumber: null };
                console.log(`${LOG_PREFIX} AutoRefresh: cleared lastReplyContext`);
                const ok2 = robustClick(btn);
                console.log(`${LOG_PREFIX} AutoRefresh: robustClick(observer btn) =>`, ok2);
                observer.disconnect();

                // After clicking, set up scroll observer
                const section = ownerPostElement.querySelector("section.embedded-posts");
                if (section) {
                  // Try immediate scroll
                  if (!tryScrollToNewReply(section)) {
                    // Set up observer to scroll when new post appears
                    console.log(`${LOG_PREFIX} AutoScroll: setting up observer for new post after delayed load-more click`);
                    const scrollObserver = new MutationObserver(() => {
                      if (tryScrollToNewReply(section)) {
                        console.log(`${LOG_PREFIX} AutoScroll: observer successfully scrolled to new post`);
                        scrollObserver.disconnect();
                      }
                    });

                    scrollObserver.observe(section, {
                      childList: true,
                      subtree: true
                    });

                    // Timeout to prevent infinite observation (10 seconds)
                    setTimeout(() => {
                      console.log(`${LOG_PREFIX} AutoScroll: observer timeout - new post not found within 10s`);
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
              console.log(`${LOG_PREFIX} AutoRefresh: observer timeout - loadMoreBtn not found within 5s`);
              observer.disconnect();
            }, 5000);
          }
        });
      });

      composerEventsBound = true;
    }
  }
});

