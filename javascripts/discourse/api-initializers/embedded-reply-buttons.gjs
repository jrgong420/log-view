import { apiInitializer } from "discourse/lib/api";
import { schedule } from "@ember/runloop";

const LOG_PREFIX = "[Embedded Reply Buttons]";

export default apiInitializer("1.14.0", (api) => {
  console.log(`${LOG_PREFIX} Initializer starting...`);

  let globalClickHandlerBound = false;

  // Global delegated click handler for embedded reply buttons
  if (!globalClickHandlerBound) {
    console.log(`${LOG_PREFIX} Binding global click handler...`);
    
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

          // Find the parent post container
          const postContainer = btn.closest("article.topic-post");
          if (!postContainer) {
            console.error(`${LOG_PREFIX} No parent post container found`);
            return;
          }

          const postNumber = postContainer.dataset.postNumber;
          console.log(`${LOG_PREFIX} Parent post number:`, postNumber);

          if (!postNumber) {
            console.error(`${LOG_PREFIX} No post number found on container`);
            return;
          }

          // Find the post model from the topic's post stream
          const parentPost = topic.postStream?.posts?.find(
            (p) => p.post_number === Number(postNumber)
          );

          console.log(`${LOG_PREFIX} Parent post model:`, parentPost);

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
    console.log(`${LOG_PREFIX} Global click handler bound successfully`);
  }

  // Inject reply buttons into embedded posts on page changes
  api.onPageChange((url, title) => {
    console.log(`${LOG_PREFIX} Page change detected:`, { url, title });

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

      // Find all embedded post sections
      const embeddedSections = document.querySelectorAll(
        "section.embedded-posts"
      );
      console.log(
        `${LOG_PREFIX} Found ${embeddedSections.length} embedded post sections`
      );

      embeddedSections.forEach((section, sectionIndex) => {
        console.log(
          `${LOG_PREFIX} Processing embedded section ${sectionIndex + 1}...`
        );

        // Find all embedded post items within this section
        const embeddedItems = section.querySelectorAll(".embedded-post");
        console.log(
          `${LOG_PREFIX} Found ${embeddedItems.length} embedded items in section ${sectionIndex + 1}`
        );

        embeddedItems.forEach((item, itemIndex) => {
          // Skip if button already injected
          if (item.dataset.replyBtnBound) {
            console.log(
              `${LOG_PREFIX} Section ${sectionIndex + 1}, Item ${itemIndex + 1}: Button already bound, skipping`
            );
            return;
          }

          console.log(
            `${LOG_PREFIX} Section ${sectionIndex + 1}, Item ${itemIndex + 1}: Injecting reply button...`
          );

          // Create the reply button
          const btn = document.createElement("button");
          btn.className = "btn btn-small embedded-reply-button";
          btn.type = "button";
          btn.textContent = "Reply";
          btn.title = "Reply to this post";

          // Find a good place to insert the button
          // Try to find the post-info or post-actions area
          const postInfo = item.querySelector(".post-info");
          const postActions = item.querySelector(".post-actions");

          if (postActions) {
            console.log(
              `${LOG_PREFIX} Section ${sectionIndex + 1}, Item ${itemIndex + 1}: Appending to post-actions`
            );
            postActions.appendChild(btn);
          } else if (postInfo) {
            console.log(
              `${LOG_PREFIX} Section ${sectionIndex + 1}, Item ${itemIndex + 1}: Appending to post-info`
            );
            postInfo.appendChild(btn);
          } else {
            console.log(
              `${LOG_PREFIX} Section ${sectionIndex + 1}, Item ${itemIndex + 1}: Appending to item directly`
            );
            item.appendChild(btn);
          }

          // Mark as bound
          item.dataset.replyBtnBound = "1";
          console.log(
            `${LOG_PREFIX} Section ${sectionIndex + 1}, Item ${itemIndex + 1}: Button injected successfully`
          );
        });
      });

      console.log(`${LOG_PREFIX} Button injection complete`);
    });
  });

  console.log(`${LOG_PREFIX} Initializer setup complete`);
});

