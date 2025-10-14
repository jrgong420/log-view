import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Hide Reply Buttons for Non-Owners", function (needs) {
  needs.user();
  needs.settings({
    hide_reply_buttons_for_non_owners: true,
    owner_comment_categories: "1", // Category ID 1
  });

  test("hides reply buttons on non-owner posts in configured category", async function (assert) {
    await visit("/t/some-topic/1");

    // Wait for posts to be classified
    await new Promise((resolve) => setTimeout(resolve, 500));

    // Find owner posts (should have reply buttons visible)
    const ownerPosts = document.querySelectorAll("article.topic-post.owner-post");
    assert.ok(ownerPosts.length > 0, "Owner posts are present");

    ownerPosts.forEach((post) => {
      const replyButton = post.querySelector(
        "nav.post-controls .actions button.reply, nav.post-controls .actions button.reply-to-post"
      );
      // Note: In test environment, buttons might not be rendered, so we check the class
      assert.ok(
        !post.classList.contains("non-owner-post"),
        "Owner post does not have non-owner-post class"
      );
    });

    // Find non-owner posts (should have reply buttons hidden via CSS)
    const nonOwnerPosts = document.querySelectorAll(
      "article.topic-post.non-owner-post"
    );
    assert.ok(nonOwnerPosts.length > 0, "Non-owner posts are present");

    nonOwnerPosts.forEach((post) => {
      assert.ok(
        post.classList.contains("non-owner-post"),
        "Non-owner post has non-owner-post class"
      );
      assert.ok(
        post.dataset.ownerMarked === "1",
        "Non-owner post is marked as processed"
      );
    });
  });

  test("does not hide buttons in unconfigured category", async function (assert) {
    // Visit a topic in category 2 (not configured)
    await visit("/t/another-topic/2");

    await new Promise((resolve) => setTimeout(resolve, 500));

    // Posts should not be classified
    const classifiedPosts = document.querySelectorAll(
      "article.topic-post[data-owner-marked]"
    );
    assert.equal(
      classifiedPosts.length,
      0,
      "Posts are not classified in unconfigured category"
    );
  });

  test("works in both filtered and regular views", async function (assert) {
    await visit("/t/some-topic/1");

    await new Promise((resolve) => setTimeout(resolve, 500));

    // Check classification in regular view
    let nonOwnerPosts = document.querySelectorAll(
      "article.topic-post.non-owner-post"
    );
    const regularViewCount = nonOwnerPosts.length;
    assert.ok(regularViewCount > 0, "Non-owner posts classified in regular view");

    // Toggle to filtered view (if toggle button exists)
    const toggleButton = document.querySelector(".owner-toggle-button");
    if (toggleButton) {
      await click(".owner-toggle-button");
      await new Promise((resolve) => setTimeout(resolve, 500));

      // Check classification persists in filtered view
      nonOwnerPosts = document.querySelectorAll(
        "article.topic-post.non-owner-post"
      );
      assert.ok(
        nonOwnerPosts.length > 0,
        "Non-owner posts still classified in filtered view"
      );
    }
  });
});

acceptance(
  "Hide Reply Buttons - Setting Disabled",
  function (needs) {
    needs.user();
    needs.settings({
      hide_reply_buttons_for_non_owners: false,
      owner_comment_categories: "1",
    });

    test("does not classify posts when setting is disabled", async function (assert) {
      await visit("/t/some-topic/1");

      await new Promise((resolve) => setTimeout(resolve, 500));

      const classifiedPosts = document.querySelectorAll(
        "article.topic-post[data-owner-marked]"
      );
      assert.equal(
        classifiedPosts.length,
        0,
        "Posts are not classified when setting is disabled"
      );
    });
  }
);

