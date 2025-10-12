import { apiInitializer } from "discourse/lib/api";
import { schedule } from "@ember/runloop";

export default apiInitializer("1.14.0", (api) => {
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




  // Function to inject reply buttons into embedded posts
  function injectEmbeddedReplyButtons(container) {
    const embeddedItemsNodeList = container.querySelectorAll(EMBEDDED_ITEM_SELECTOR);

    // Filter out our own buttons to avoid treating them as items
    const embeddedItems = Array.from(embeddedItemsNodeList).filter((el) => !el.matches(".embedded-reply-button, button.embedded-reply-button"));

    let injectedCount = 0;

    embeddedItems.forEach((item) => {
      // Skip if already has button flag or an existing reply button inside
      if (item.dataset.replyBtnBound || item.querySelector(".embedded-reply-button")) {
        return;
      }

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

      // Find a good place to insert the button (avoid anchors/buttons)
      let controls = item.querySelector("footer, .embedded-posts__post-footer, .post-controls__inner, .post-controls, .post-actions, .post-menu, .actions, .post-info");
      if (controls && (controls.tagName === "A" || controls.tagName === "BUTTON")) {
        controls = controls.parentElement || item;
      }

      if (controls) {
        controls.appendChild(btn);
      } else {
        item.appendChild(btn);
      }

      // Mark as bound on the item (not the button)
      item.dataset.replyBtnBound = "1";
      injectedCount++;
    });

    return { total: embeddedItems.length, injected: injectedCount };
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
                const res = injectEmbeddedReplyButtons(node);
                if (!res || res.total === 0) {
                  setupSectionChildObserver(node);
                }
                observer.disconnect();
                activeObservers.delete(postElement);
              } else if (node.querySelector) {
                const embeddedSections = node.querySelectorAll("section.embedded-posts");
                if (embeddedSections.length > 0) {
                  embeddedSections.forEach(section => {
                    const res = injectEmbeddedReplyButtons(section);
                    if (!res || res.total === 0) {
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
            const res = injectEmbeddedReplyButtons(section);
            if (!res || res.total === 0) {
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

  // Observe a specific embedded section until items appear, then inject and stop
  function setupSectionChildObserver(section) {
    if (!section) {
      return;
    }
    if (activeObservers.has(section)) {
      return;
    }

    const observer = new MutationObserver(() => {
      const items = section.querySelectorAll(EMBEDDED_ITEM_SELECTOR);
      if (items.length > 0) {
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

        try {
          // Get required services and models
          const topic = api.container.lookup("controller:topic")?.model;
          const composer = api.container.lookup("service:composer");

          if (!topic || !composer) {
            return;
          }

          // Find the embedded row container (closest matching our injection targets)
          let rowContainer = btn.closest(EMBEDDED_ITEM_SELECTOR);
          // If the closest match is the button itself (because it carries data-post-id), climb to the parent
          if (rowContainer === btn) {
            rowContainer = btn.parentElement?.closest(EMBEDDED_ITEM_SELECTOR) || null;
          }
          if (!rowContainer) {
            rowContainer = btn.closest("article.topic-post, [data-post-number], [id^='post_']");
          }
          if (!rowContainer) {
            return;
          }

          // Determine the post_number and post_id for this embedded row
          let postNumber = extractPostNumberFromElement(rowContainer) || btn.dataset.postNumber;
          let postId =
            extractPostIdFromElement(rowContainer) ||
            btn.dataset.postId ||
            rowContainer.getAttribute?.("data-post-id");

          if (!postNumber) {
            // Fallback: resolve via post id if only data-post-id is present
            if (postId && topic?.postStream?.posts) {
              const byId = topic.postStream.posts.find((p) => p.id === Number(postId));
              if (byId) {
                postNumber = byId.post_number;
              }
            }
          }

          if (!postNumber) {
            // Final fallback: parse from hrefs inside the row
            const hrefCandidates = Array.from(rowContainer.querySelectorAll("a[href]"))
              .map((a) => a.getAttribute("href"))
              .filter(Boolean);
            for (const href of hrefCandidates) {
              const parsed = parsePostNumberFromHref(href);
              if (parsed) {
                postNumber = parsed;
                break;
              }
            }
          }

          if (!postNumber) {
            return;
          }

          // Find the embedded post model from the topic's post stream
          let embeddedPost = topic.postStream?.posts?.find(
            (p) => p.post_number === Number(postNumber)
          );

          // If post is not in the stream, try fetching it
          if (!embeddedPost && postId) {
            try {
              const store = api.container.lookup("service:store");
              const fetchedPost = await store.find("post", postId);
              if (fetchedPost) {
                embeddedPost = fetchedPost;
              }
            } catch (fetchError) {
              // Failed to fetch
            }
          }

          if (!embeddedPost) {
            return;
          }

          // The parent post is the one that the embedded post was replying to
          let parentPostNumber = embeddedPost.reply_to_post_number || null;

          // Find the parent post model
          let parentPost = null;
          if (parentPostNumber) {
            parentPost = topic.postStream?.posts?.find(
              (p) => p.post_number === Number(parentPostNumber)
            );

            // If parent post is not in the stream, try fetching it
            if (!parentPost) {
              try {
                const store = api.container.lookup("service:store");
                const topicPosts = await store.query("post", {
                  topic_id: topic.id,
                  post_ids: [parentPostNumber]
                });

                if (topicPosts && topicPosts.length > 0) {
                  parentPost = topicPosts.find(p => p.post_number === parentPostNumber);
                }
              } catch (fetchError) {
                // Failed to fetch
              }

              // If we still don't have the parent post, try opening composer with just the post number
              if (!parentPost) {
                try {
                  await composer.open({
                    action: "reply",
                    topic: topic,
                    draftKey: topic.draft_key,
                    draftSequence: topic.draft_sequence,
                    skipJumpOnSave: true,
                    replyToPostNumber: Number(parentPostNumber),
                  });
                  return;
                } catch (composerError) {
                  return;
                }
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

          if (parentPost) {
            composerOptions.post = parentPost;
          }

          await composer.open(composerOptions);
        } catch (error) {
          // Error opening composer
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

      // Check if embedded posts already exist (fast path)
      schedule("afterRender", () => {
        const existingSection = postElement.querySelector("section.embedded-posts");
        if (existingSection) {
          const res = injectEmbeddedReplyButtons(existingSection);
          if (!res || res.total === 0) {
            setupSectionChildObserver(existingSection);
          }
        } else {
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
        return;
      }

      // Find all embedded post sections that are already expanded
      const embeddedSections = document.querySelectorAll(
        "section.embedded-posts"
      );

      if (embeddedSections.length === 0) {
        return;
      }

      // Inject buttons into each section
      embeddedSections.forEach((section) => {
        const res = injectEmbeddedReplyButtons(section);
        if (!res || res.total === 0) {
          setupSectionChildObserver(section);
        }
      });
    });
  });
});

