import { schedule } from "@ember/runloop";
import { apiInitializer } from "discourse/lib/api";
import { parseCategoryIds } from "../lib/group-access-utils";
import { createLogger } from "../lib/logger";

/**
 * Hide Reply Buttons for Non-Owners
 *
 * When enabled, hides reply buttons on posts authored by non-owners in categories
 * configured for owner comments. Applies in both filtered and regular topic views.
 * Does not check Allowed groups setting.
 *
 * This is a UI-only restriction and does not prevent replies via keyboard
 * shortcuts (Shift+R) or API calls.
 *
 * Settings used:
 * - hide_reply_buttons_for_non_owners: enable this feature
 * - owner_comment_categories: list of category IDs
 * - debug_logging_enabled: enable verbose console logging
 */

const log = createLogger("[Owner View] [Hide Reply Buttons]");

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
    log.warn("Could not extract post number from element", { postElement });
    return;
  }

  // Find the post model in the topic's post stream
  const post = topic.postStream?.posts?.find(p => p.post_number === postNumber);
  if (!post) {
    log.debug("Post not found in post stream", { postNumber });
    return;
  }

  const postAuthorId = post.user_id;
  const isOwnerPost = postAuthorId === topicOwnerId;

  log.debug("Classifying post", {
    postNumber,
    postAuthorId,
    topicOwnerId,
    isOwnerPost
  });

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
  log.info("Processing visible posts", { count: postElements.length });

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
    log.debug("Disconnected previous MutationObserver");
  }

  const streamContainer = document.querySelector("#topic .post-stream, .post-stream");
  if (!streamContainer) {
    log.warn("Post stream container not found");
    return;
  }

  streamObserver = new MutationObserver((mutations) => {
    for (const mutation of mutations) {
      if (mutation.type === "childList") {
        mutation.addedNodes.forEach(node => {
          if (node.nodeType === Node.ELEMENT_NODE) {
            // Check if the added node is a post
            if (node.matches && node.matches("article.topic-post")) {
              log.debugThrottled("New post detected (direct)", { node });
              classifyPost(node, topic, topicOwnerId);
            }
            // Check if the added node contains posts
            else if (node.querySelectorAll) {
              const posts = node.querySelectorAll("article.topic-post");
              if (posts.length > 0) {
                log.debugThrottled("New posts detected (nested)", { count: posts.length });
                posts.forEach(post => {
                  classifyPost(post, topic, topicOwnerId);
                });
              }
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

  log.info("MutationObserver set up for post stream");
}

export default apiInitializer("1.15.0", (api) => {
  api.onPageChange((url) => {
    schedule("afterRender", () => {
      log.debug("Page changed", { url });

      // Clean up previous observer
      if (streamObserver) {
        streamObserver.disconnect();
        streamObserver = null;
        log.debug("Cleaned up previous observer");
      }

      // Guard 1: Check if setting is enabled
      if (!settings.hide_reply_buttons_for_non_owners) {
        log.debug("Setting disabled; skipping");
        return;
      }

      log.info("Hide reply buttons feature enabled; evaluating conditions");

      // Guard 2: Get topic data
      const topic = api.container.lookup("controller:topic")?.model;
      if (!topic) {
        log.debug("No topic found; skipping");
        return;
      }

      log.debug("Topic found", {
        topicId: topic.id,
        categoryId: topic.category_id
      });

      // Guard 3: Check if category is configured for owner comments
      const categoryId = topic.category_id;
      const enabledCategories = parseCategoryIds(settings.owner_comment_categories);

      log.debug("Category check", {
        topicCategory: categoryId,
        enabledCategories
      });

      if (!enabledCategories.includes(categoryId)) {
        log.debug("Category not configured; skipping");
        return;
      }

      log.info("Category is configured; proceeding with post classification");

      // Guard 4: Get topic owner ID
      const topicOwnerId = topic.details?.created_by?.id;

      if (!topicOwnerId) {
        log.warn("No topic owner data available; skipping");
        return;
      }

      log.info("Starting post classification", { topicOwnerId });

      // Process visible posts with a small delay to ensure DOM is ready
      // Discourse's post rendering can happen after afterRender in some cases
      const processWithRetry = (attempt = 1, maxAttempts = 3) => {
        const postCount = document.querySelectorAll("article.topic-post").length;

        if (postCount > 0) {
          log.debug("Posts found in DOM", { count: postCount, attempt });
          processVisiblePosts(topic, topicOwnerId);
          observeStreamForNewPosts(topic, topicOwnerId);
        } else if (attempt < maxAttempts) {
          log.debug("No posts found yet, retrying", { attempt, maxAttempts });
          setTimeout(() => processWithRetry(attempt + 1, maxAttempts), 100);
        } else {
          log.warn("No posts found after retries", { maxAttempts });
          // Still set up observer in case posts load later
          observeStreamForNewPosts(topic, topicOwnerId);
        }
      };

      processWithRetry();
    });
  });
});

