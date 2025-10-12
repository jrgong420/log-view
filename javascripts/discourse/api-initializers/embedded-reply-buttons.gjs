import { apiInitializer } from "discourse/lib/api";
import { schedule } from "@ember/runloop";

const LOG_PREFIX = "[Embedded Reply Buttons]";

export default apiInitializer("1.14.0", (api) => {
  console.log(`${LOG_PREFIX} Initializer starting...`);

  let globalClickHandlerBound = false;
  let showRepliesClickHandlerBound = false;

  // Map to track active MutationObservers per post
  const activeObservers = new Map();
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



  // Function to inject reply buttons into embedded posts
  function injectEmbeddedReplyButtons(container) {
    console.log(`${LOG_PREFIX} Injecting buttons into container:`, container);

    const embeddedItems = container.querySelectorAll(EMBEDDED_ITEM_SELECTOR);
    console.log(`${LOG_PREFIX} Found ${embeddedItems.length} embedded post items (selector: ${EMBEDDED_ITEM_SELECTOR})`);

    let injectedCount = 0;
    let skippedCount = 0;

    embeddedItems.forEach((item, index) => {
      // Skip if already has button
      if (item.dataset.replyBtnBound) {
        console.log(`${LOG_PREFIX} Item ${index + 1}: Button already bound, skipping`);
        skippedCount++;
        return;
      }

      console.log(`${LOG_PREFIX} Item ${index + 1}: Injecting reply button...`);

      // Create the reply button
      const btn = document.createElement("button");
      btn.className = "btn btn-small embedded-reply-button";
      btn.type = "button";
      btn.textContent = "Reply";
      btn.title = "Reply to this post";

      // Persist identifiers on the button for robust retrieval
      const candidateNumber = extractPostNumberFromElement(item);
      if (candidateNumber) {
        btn.dataset.postNumber = String(candidateNumber);
      }
      const candidateId = extractPostIdFromElement(item);
      if (candidateId) {
        btn.dataset.postId = String(candidateId);
      }

      // Find a good place to insert the button
      const controls = item.querySelector(".post-controls, .post-actions, .post-info, .embedded-posts__post-footer, footer, .post-menu, .actions, .post-controls__inner");

      if (controls) {
        console.log(`${LOG_PREFIX} Item ${index + 1}: Appending to controls container`);
        controls.appendChild(btn);
      } else {
        console.log(`${LOG_PREFIX} Item ${index + 1}: Appending to item directly (no controls found)`);
        item.appendChild(btn);
      }

      // Mark as bound
      item.dataset.replyBtnBound = "1";
      injectedCount++;
      console.log(`${LOG_PREFIX} Item ${index + 1}: Button injected successfully`);
    });

    console.log(`${LOG_PREFIX} Injection complete: ${injectedCount} injected, ${skippedCount} skipped`);
    return { total: embeddedItems.length, injected: injectedCount };
  }

  // Function to setup MutationObserver for a specific post
  function setupPostObserver(postElement) {
    const postId = postElement?.id || postElement?.dataset?.postId || postElement?.dataset?.postNumber || "unknown";

    if (!postElement) {
      console.warn(`${LOG_PREFIX} setupPostObserver called without a valid postElement`);
      return;
    }

    // Don't create duplicate observers
    if (activeObservers.has(postElement)) {
      console.log(`${LOG_PREFIX} Observer already exists for post ${postId}`);
      return;
    }

    console.log(`${LOG_PREFIX} Setting up MutationObserver for post ${postId}`);

    const observer = new MutationObserver((mutations) => {
      console.log(`${LOG_PREFIX} Mutations detected in post ${postId}: ${mutations.length} mutations`);

      // Check if embedded-posts section was added
      for (const mutation of mutations) {
        if (mutation.type === "childList") {
          mutation.addedNodes.forEach((node) => {
            if (node.nodeType === Node.ELEMENT_NODE) {
              // Check if the added node is or contains section.embedded-posts
              if (node.matches && node.matches("section.embedded-posts")) {
                console.log(`${LOG_PREFIX} Embedded posts section detected in post ${postId}`);
                const res = injectEmbeddedReplyButtons(node);
                if (!res || res.total === 0) {
                  console.log(`${LOG_PREFIX} No embedded items yet in section; observing section children...`);
                  setupSectionChildObserver(node);
                }
                observer.disconnect();
                activeObservers.delete(postElement);
              } else if (node.querySelector) {
                const embeddedSections = node.querySelectorAll("section.embedded-posts");
                if (embeddedSections.length > 0) {
                  console.log(`${LOG_PREFIX} Found ${embeddedSections.length} embedded sections in added node`);
                  embeddedSections.forEach(section => {
                    const res = injectEmbeddedReplyButtons(section);
                    if (!res || res.total === 0) {
                      console.log(`${LOG_PREFIX} No embedded items yet in section; observing section children...`);
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
    console.log(`${LOG_PREFIX} Observer started for post ${postId}`);
  }

  // Function to observe stream for a specific embedded section id (fallback)
  function setupSectionObserverById(sectionId) {
    if (!sectionId) {
      console.warn(`${LOG_PREFIX} setupSectionObserverById called without sectionId`);
      return;
    }
    const targetSelector = `#${CSS.escape(sectionId)}`;
    const stream = document.querySelector("#topic .post-stream, .post-stream");
    if (!stream) {
      console.warn(`${LOG_PREFIX} Could not find .post-stream container to observe for id`, sectionId);
      return;
    }

    // Avoid duplicate observers on the same stream+id by keying the map with the selector
    if (activeObservers.has(targetSelector)) {
      console.log(`${LOG_PREFIX} Observer already exists for section id ${sectionId}`);
      return;
    }

    console.log(`${LOG_PREFIX} Setting up stream observer for section id ${sectionId}`);
    const observer = new MutationObserver((mutations) => {
      for (const mutation of mutations) {
        if (mutation.type === "childList") {
          // Check if our target section now exists
          const section = stream.querySelector(targetSelector);
          if (section) {
            console.log(`${LOG_PREFIX} Detected target section #${sectionId} in stream; injecting`);
            const res = injectEmbeddedReplyButtons(section);
            if (!res || res.total === 0) {
              console.log(`${LOG_PREFIX} No embedded items yet in section; observing section children...`);
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
    console.log(`${LOG_PREFIX} Stream observer started for section id ${sectionId}`);
  }

  // Observe a specific embedded section until items appear, then inject and stop
  function setupSectionChildObserver(section) {
    if (!section) {
      console.warn(`${LOG_PREFIX} setupSectionChildObserver called without section`);
      return;
    }
    if (activeObservers.has(section)) {
      console.log(`${LOG_PREFIX} Section observer already exists for`, section.id || section);
      return;
    }

    console.log(`${LOG_PREFIX} Setting up child observer for section`, section.id || section);
    const observer = new MutationObserver((mutationsList) => {
      const items = section.querySelectorAll(EMBEDDED_ITEM_SELECTOR);
      if (items.length > 0) {
        console.log(`${LOG_PREFIX} Section child observer detected ${items.length} items; injecting now`);
        injectEmbeddedReplyButtons(section);
        observer.disconnect();
        activeObservers.delete(section);
      } else {
        // Debug: log newly added nodes to refine selectors if needed
        let logged = 0;
        for (const m of mutationsList) {
          if (m.type === "childList" && m.addedNodes && m.addedNodes.length) {
            for (const n of Array.from(m.addedNodes)) {
              if (logged >= 3) break;
              const nodeName = (n.nodeName || "").toLowerCase();
              const cls = n.className || "";
              console.log(`${LOG_PREFIX} Section child added: <${nodeName}> ${cls}`);
              logged++;
            }
          }
          if (logged >= 3) break;
        }
      }
    });

    observer.observe(section, { childList: true, subtree: true });
    activeObservers.set(section, observer);
    console.log(`${LOG_PREFIX} Section child observer started for`, section.id || section);
  }

  // Global delegated click handler for embedded reply buttons
  if (!globalClickHandlerBound) {
    console.log(`${LOG_PREFIX} Binding global click handler for reply buttons...`);

    document.addEventListener(
      "click",
      async (e) => {
        const btn = e.target?.closest?.(".embedded-reply-button");
        if (!btn) return;

        console.log(`${LOG_PREFIX} Reply button clicked:`, btn);
        e.preventDefault();
        e.stopPropagation();

        try {
          // Get required services and models
          const topic = api.container.lookup("controller:topic")?.model;
          const composer = api.container.lookup("service:composer");

          console.log(`${LOG_PREFIX} Topic model:`, topic);
          console.log(`${LOG_PREFIX} Composer service:`, composer);

          if (!topic) {
            console.error(`${LOG_PREFIX} No topic model found`);
            return;
          }

          if (!composer) {
            console.error(`${LOG_PREFIX} No composer service found`);
            return;
          }

          // Find the embedded row container (closest matching our injection targets)
          const rowContainer = btn.closest(EMBEDDED_ITEM_SELECTOR) ||
                               btn.closest("article.topic-post, [data-post-number], [id^='post_']");
          if (!rowContainer) {
            console.error(`${LOG_PREFIX} No embedded row container found`);
            return;
          }

          // Determine the post_number for this embedded row
          let postNumber = extractPostNumberFromElement(rowContainer) || btn.dataset.postNumber;
          if (!postNumber) {
            // Fallback: resolve via post id if only data-post-id is present
            const postId =
              extractPostIdFromElement(rowContainer) ||
              btn.dataset.postId ||
              rowContainer.getAttribute?.("data-post-id");
            console.log(`${LOG_PREFIX} Fallback post id from DOM/button:`, postId);
            if (postId && topic?.postStream?.posts) {
              const byId = topic.postStream.posts.find((p) => p.id === Number(postId));
              if (byId) {
                postNumber = byId.post_number;
                console.log(`${LOG_PREFIX} Resolved post number via post id mapping:`, postNumber);
              }
            }
          }
          console.log(`${LOG_PREFIX} Target embedded post number:`, postNumber);

          if (!postNumber) {
            console.error(`${LOG_PREFIX} No post number found for embedded row`);
            return;
          }

          // Find the post model from the topic's post stream
          const parentPost = topic.postStream?.posts?.find(
            (p) => p.post_number === Number(postNumber)
          );

          console.log(`${LOG_PREFIX} Target embedded post model:`, parentPost);

          if (!parentPost) {
            console.error(
              `${LOG_PREFIX} Could not find post model for post number ${postNumber}`
            );
            console.log(
              `${LOG_PREFIX} Available posts:`,
              topic.postStream?.posts?.map((p) => p.post_number)
            );
            return;
          }

          // Get draft key and sequence from topic
          const draftKey = topic.draft_key;
          const draftSequence = topic.draft_sequence;

          console.log(`${LOG_PREFIX} Draft key:`, draftKey);
          console.log(`${LOG_PREFIX} Draft sequence:`, draftSequence);

          // Import Composer model for action constants
          const { default: Composer } = await import(
            "discourse/models/composer"
          );

          console.log(`${LOG_PREFIX} Opening composer with options:`, {
            action: "REPLY",
            topicId: topic.id,
            postId: parentPost.id,
            postNumber: parentPost.post_number,
            draftKey,
            draftSequence,
            skipJumpOnSave: true,
          });

          // Open the composer
          await composer.open({
            action: Composer.REPLY,
            topic: topic,
            post: parentPost,
            draftKey: draftKey,
            draftSequence: draftSequence,
            skipJumpOnSave: true,
          });

          console.log(`${LOG_PREFIX} Composer opened successfully`);
        } catch (error) {
          console.error(`${LOG_PREFIX} Error opening composer:`, error);
        }
      },
      true // Use capture phase
    );

    globalClickHandlerBound = true;
    console.log(`${LOG_PREFIX} Global click handler for reply buttons bound successfully`);
  }

  // Delegated click handler for "show replies" buttons
  if (!showRepliesClickHandlerBound) {
    console.log(`${LOG_PREFIX} Binding delegated click handler for show-replies buttons...`);

    document.addEventListener("click", (e) => {
      // Check if click is on show-replies button or load-more-replies
      const showRepliesBtn = e.target?.closest?.(".post-controls .show-replies, .show-replies, .post-action-menu__show-replies");
      const loadMoreBtn = e.target?.closest?.(".embedded-posts .load-more-replies");

      if (!showRepliesBtn && !loadMoreBtn) return;

      const clickedBtn = showRepliesBtn || loadMoreBtn;
      console.log(`${LOG_PREFIX} Show replies / Load more button clicked:`, clickedBtn);

      // Only process in owner comment mode
      const isOwnerCommentMode = document.body.dataset.ownerCommentMode === "true";
      if (!isOwnerCommentMode) {
        console.log(`${LOG_PREFIX} Not in owner comment mode, ignoring click`);
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
      let derivedPostNumber = null;
      if (!postElement && controlsId) {
        const m = controlsId.match(/--(\d+)$/);
        if (m) {
          derivedPostNumber = m[1];
          console.log(`${LOG_PREFIX} Derived post number from aria-controls:`, derivedPostNumber);
          postElement = document.querySelector(`article.topic-post[data-post-number="${derivedPostNumber}"]`) ||
                        document.querySelector(`[data-post-number="${derivedPostNumber}"]`);
        }
      }

      if (!postElement) {
        console.warn(`${LOG_PREFIX} Could not find parent post element; will observe stream for section id`, controlsId);
        if (controlsId) {
          setupSectionObserverById(controlsId);
        }
        return;
      }

      const postId = postElement.id || postElement.dataset.postId || postElement.dataset.postNumber || "unknown";
      console.log(`${LOG_PREFIX} Processing click for post ${postId}`);

      // Check if embedded posts already exist (fast path)
      schedule("afterRender", () => {
        const existingSection = postElement.querySelector("section.embedded-posts");
        if (existingSection) {
          console.log(`${LOG_PREFIX} Embedded section already present in post ${postId}, injecting immediately`);
          const res = injectEmbeddedReplyButtons(existingSection);
          if (!res || res.total === 0) {
            console.log(`${LOG_PREFIX} No embedded items yet; observing section children...`);
            setupSectionChildObserver(existingSection);
          }
        } else {
          console.log(`${LOG_PREFIX} Embedded section not yet present, setting up observer for post ${postId}`);
          setupPostObserver(postElement);
          // Also set up a fallback observer using aria-controls if available
          if (controlsId) {
            setupSectionObserverById(controlsId);
          }
        }
      });

    }, true); // Use capture phase

    showRepliesClickHandlerBound = true;
    console.log(`${LOG_PREFIX} Delegated click handler for show-replies bound successfully`);
  }

  // Inject reply buttons into embedded posts on page changes (for already-expanded sections)
  api.onPageChange((url, title) => {
    console.log(`${LOG_PREFIX} Page change detected:`, { url, title });

    // Clean up old observers
    console.log(`${LOG_PREFIX} Cleaning up ${activeObservers.size} active observers`);
    activeObservers.forEach((observer, element) => {
      observer.disconnect();
    });
    activeObservers.clear();
    console.log(`${LOG_PREFIX} Observers cleaned up`);

    schedule("afterRender", () => {
      console.log(`${LOG_PREFIX} afterRender: Checking for embedded posts...`);

      // Check if we're in owner comment mode (filtered view)
      const isOwnerCommentMode =
        document.body.dataset.ownerCommentMode === "true";
      console.log(`${LOG_PREFIX} Owner comment mode:`, isOwnerCommentMode);

      if (!isOwnerCommentMode) {
        console.log(
          `${LOG_PREFIX} Not in owner comment mode, skipping button injection`
        );
        return;
      }

      // Find all embedded post sections that are already expanded
      const embeddedSections = document.querySelectorAll(
        "section.embedded-posts"
      );
      console.log(
        `${LOG_PREFIX} Found ${embeddedSections.length} already-expanded embedded post sections`
      );

      if (embeddedSections.length === 0) {
        console.log(`${LOG_PREFIX} No embedded sections found on initial load (will be detected on user click)`);
        return;
      }

      // Inject buttons into each section
      embeddedSections.forEach((section, sectionIndex) => {
        console.log(
          `${LOG_PREFIX} Processing already-expanded section ${sectionIndex + 1}...`
        );
        const res = injectEmbeddedReplyButtons(section);
        if (!res || res.total === 0) {
          console.log(`${LOG_PREFIX} No embedded items yet; observing section children...`);
          setupSectionChildObserver(section);
        }
      });

      console.log(`${LOG_PREFIX} Button injection complete`);
    });
  });

  console.log(`${LOG_PREFIX} Initializer setup complete`);
});

