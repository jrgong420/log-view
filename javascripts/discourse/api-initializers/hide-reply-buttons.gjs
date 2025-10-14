import { schedule } from "@ember/runloop";
import { apiInitializer } from "discourse/lib/api";
import { parseCategoryIds } from "../lib/group-access-utils";

/**
 * Hide Reply Buttons for Non-Owners
 *
 * When enabled, hides reply buttons on posts authored by non-owners in categories
 * configured for owner comments. Applies in both filtered and regular topic views.
 * Does not check Allowed groups setting.
 *
 * This is a UI-only restriction and does not prevent replies via keyboard
 * shortcuts (Shift+R) or API calls.
 */

const DEBUG = false; // Reduced logging by default; set to true for troubleshooting

function debugLog(...args) {
  if (DEBUG) {
    // eslint-disable-next-line no-console
    console.log("[Hide Reply Buttons]", ...args);
  }
}

// Track active MutationObserver to clean up on route changes
let streamObserver = null;

/**
 * Extract post number from a post element
 */
function extractPostNumberFromElement(el) {
  if (!el) return null;

  // Try data-post-number attribute
  if (el.dataset?.postNumber) {
    return Number(el.dataset.postNumber);
  }

  // Try id attribute (e.g., "post_123")
  const id = el.id || "";
  const match = id.match(/^post[_-](\d+)$/i);
  if (match) {
    return Number(match[1]);
  }

  return null;
}

/**
 * Classify a single post element as owner or non-owner
 */
function classifyPost(postElement, topic, topicOwnerId) {
  // Skip if already classified
  if (postElement.dataset.ownerMarked) {
    return;
  }

  const postNumber = extractPostNumberFromElement(postElement);
  if (!postNumber) {
    debugLog("Could not extract post number from element:", postElement);
    return;
  }

  // Find the post model in the topic's post stream
  const post = topic.postStream?.posts?.find(p => p.post_number === postNumber);
  if (!post) {
    debugLog(`Post #${postNumber} not found in post stream`);
    return;
  }

  const postAuthorId = post.user_id;
  const isOwnerPost = postAuthorId === topicOwnerId;

  debugLog(`Post #${postNumber}: author=${postAuthorId}, owner=${topicOwnerId}, isOwner=${isOwnerPost}`);

  // Add classification class
  if (isOwnerPost) {
    postElement.classList.add("owner-post");
    postElement.classList.remove("non-owner-post");
  } else {
    postElement.classList.add("non-owner-post");
    postElement.classList.remove("owner-post");
  }

  // Mark as processed
  postElement.dataset.ownerMarked = "1";
}

/**
 * Process all visible posts in the stream
 */
function processVisiblePosts(topic, topicOwnerId) {
  const postElements = document.querySelectorAll("article.topic-post");
  debugLog(`Processing ${postElements.length} visible posts`);

  postElements.forEach(postElement => {
    classifyPost(postElement, topic, topicOwnerId);
  });
}

/**
 * Set up MutationObserver to classify newly rendered posts
 */
function observeStreamForNewPosts(topic, topicOwnerId) {
  // Clean up existing observer
  if (streamObserver) {
    streamObserver.disconnect();
    streamObserver = null;
  }

  const streamContainer = document.querySelector("#topic .post-stream, .post-stream");
  if (!streamContainer) {
    debugLog("Post stream container not found");
    return;
  }

  streamObserver = new MutationObserver((mutations) => {
    for (const mutation of mutations) {
      if (mutation.type === "childList") {
        mutation.addedNodes.forEach(node => {
          if (node.nodeType === Node.ELEMENT_NODE) {
            // Check if the added node is a post
            if (node.matches && node.matches("article.topic-post")) {
              debugLog("New post detected, classifying:", node);
              classifyPost(node, topic, topicOwnerId);
            }
            // Check if the added node contains posts
            else if (node.querySelectorAll) {
              const posts = node.querySelectorAll("article.topic-post");
              posts.forEach(post => {
                debugLog("New post detected (nested), classifying:", post);
                classifyPost(post, topic, topicOwnerId);
              });
            }
          }
        });
      }
    }
  });

  streamObserver.observe(streamContainer, {
    childList: true,
    subtree: true
  });

  debugLog("MutationObserver set up for post stream");
}

export default apiInitializer("1.15.0", (api) => {
  api.onPageChange((url) => {
    schedule("afterRender", () => {
      debugLog("Page changed to:", url);

      // Clean up previous observer
      if (streamObserver) {
        streamObserver.disconnect();
        streamObserver = null;
      }

      // Guard 1: Check if setting is enabled
      if (!settings.hide_reply_buttons_for_non_owners) {
        debugLog("Setting disabled; skipping");
        return;
      }

      debugLog("Setting enabled; evaluating conditions");

      // Guard 2: Get topic data
      const topic = api.container.lookup("controller:topic")?.model;
      if (!topic) {
        debugLog("No topic found; skipping");
        return;
      }

      debugLog("Topic found:", { id: topic.id, category_id: topic.category_id });

      // Guard 3: Check if category is configured for owner comments
      const categoryId = topic.category_id;
      const enabledCategories = parseCategoryIds(settings.owner_comment_categories);

      debugLog("Category check:", {
        topicCategory: categoryId,
        enabledCategories,
      });

      if (!enabledCategories.includes(categoryId)) {
        debugLog("Category not configured; skipping");
        return;
      }

      debugLog("Category is configured; proceeding with post classification");

      // Guard 4: Get topic owner ID
      const topicOwnerId = topic.details?.created_by?.id;

      if (!topicOwnerId) {
        debugLog("No topic owner data; skipping");
        return;
      }

      debugLog("Topic owner ID:", topicOwnerId);

      // Process all visible posts
      processVisiblePosts(topic, topicOwnerId);

      // Set up observer for newly rendered posts
      observeStreamForNewPosts(topic, topicOwnerId);
    });
  });
});

