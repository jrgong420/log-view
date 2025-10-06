# Owner-Comments Theme Component Prototype

## User Perspective
- Theme component auto-filters topics in configured categories to show only the topic owner's posts for a journal/comments view.
- UI-only enforcement is acceptable (e.g., optional CSS tweaks), acknowledging alternate posting methods still work.
- Requires straightforward category scoping and minimal maintenance.

## Feature States
- Inactive: Topic not in configured categories or a filter is already active; component takes no action.
- Active: Topic loads, category matches; component calls `topic.postStream.filterParticipant(ownerUsername)` and sets `document.body.dataset.ownerCommentMode = "true"`.
- Exit: Navigating away or category mismatch clears body dataset and skips further hooks.

## Theme Component Settings (`/common/settings.yml`)
```yaml
owner_comment_categories:
  type: list
  description: "Category slugs or IDs that auto-filter by topic owner"
```
Optional future flags: `show_info_banner`, `highlight_comments` (disabled by default).

## Implementation Blueprint (AI Coding Tool Guidance)

1. **Scaffold**
   - Create:
     - `journal-view-specs/` (documentation only)
     - Theme component files: `common/settings.yml`, `common/javascripts/discourse/initializers/owner-comment-prototype.js`, `common/javascripts/discourse/lib/owner-comment-utils.js` (optional helpers), `desktop/desktop.scss`, `mobile/mobile.scss`, `README.md`.
   - Document limitations (UI-only enforcement, manual tests required).

2. **Owner Filter Hook**
   - In initializer, call `withPluginApi("1.15.0", (api) => { ... })`.
   - On `api.onPageChange`, fetch the topic model from `api.container.lookup("controller:topic")?.model`.
   - If category matches settings and `topic.postStream.userFilters.length === 0`, call `topic.postStream.filterParticipant(ownerUsername)` (see `app/assets/javascripts/discourse/app/models/post-stream.js:256-267`).
   - Debounce with a `topic.__ownerFilterApplied` flag; set `document.body.dataset.ownerCommentMode` accordingly.


4. **UI Adjustments**
   - Scope CSS with `body[data-owner-comment-mode="true"]`:
     - Indent `.post__embedded-posts`. Example:
       ```scss
       body[data-owner-comment-mode="true"] .topic-post.topic-owner .post__embedded-posts {
         padding-left: 1.5em;
         border-left: 2px solid var(--primary-medium);
       }
       ```
     - Hide topic-level reply button for non-owners:
       ```scss
       body[data-owner-comment-mode="true"] .topic-post:not(.topic-owner) .post-controls .reply {
         display: none !important;
       }
       ```
     - Hide the built-in filtered notice (since the prototype provides its own context) by targeting the specific div:
       ```scss
       body[data-owner-comment-mode="true"] .posts-filtered-notice {
         display: none;
       }
       ```
   - Optional info banner via `api.decorateWidget("post-stream:before", ...)`, referencing styling from `app/assets/javascripts/discourse/app/components/post/filtered-notice.gjs:43-71`.

5. **Knowledge Capture & Validation**
   - Update theme README with behaviour, manual test steps, and limitations.
   - Manual checks: confirm URL has `?username_filters=<owner>`, timeline restricts to owner posts, first replies auto-expand, “Show all replies” works, reply button hidden for non-owners.
   - Run `bin/lint` on theme JS (via local copy or theme CLI) to meet lint requirement.

## Theme Component Best Practices & Pitfalls
- Always use `withPluginApi` and specify a pluginId when modifying core classes to avoid conflicts.
- Debounce routing hooks; repeated `filterParticipant` calls can re-request the stream unnecessarily.
- Guard async loops with flags and clean up on component teardown to prevent unhandled promise rejections.
- Keep CSS scoped using data attributes and category IDs so other categories/pages remain unaffected.
- Highlight limitations: CSS-hiding doesn’t enforce permissions; communicate this in README and rollout notes.

## Next Steps
1. Confirm category list and preload defaults for settings.
2. Implement initializer + component modifications per blueprint.
3. Add CSS tweaks, update documentation, lint JS, and perform manual verification before sharing the prototype.
