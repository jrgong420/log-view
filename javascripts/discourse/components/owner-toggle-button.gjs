import Component from "@glimmer/component";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";
import { createLogger } from "../lib/logger";

/**
 * Shared toggle button component for owner-filtered view.
 * Reuses the same toggle logic as the footer button.
 * Can be rendered in multiple outlets (timeline, mobile progress, footer).
 *
 * Settings used:
 * - debug_logging_enabled: enable verbose console logging
 */

const log = createLogger("[Owner View] [Toggle Button]");

export default class OwnerToggleButton extends Component {
  @service router;

  toggleFilter = () => {
    const topic = this.topic;
    const owner = topic?.details?.created_by?.username;

    log.info("Toggle button clicked", {
      isOwnerFiltered: this.isOwnerFiltered,
      owner,
      topicId: topic?.id
    });

    if (this.isOwnerFiltered) {
      // Go to unfiltered view
      this.goUnfiltered(topic?.id);
    } else {
      // Go to owner-filtered view
      this.goOwnerFiltered(owner);
    }
  };

get topic() {
    return this.args.topic;
  }

  get isOwnerFiltered() {
    const owner = this.topic?.details?.created_by?.username;
    const url = new URL(window.location.href);
    const current = url.searchParams.get("username_filters");
    return !!owner && current === owner;
  }

  get icon() {
    return this.isOwnerFiltered ? "toggle-on" : "toggle-off";
  }

  get translatedLabel() {
    return this.isOwnerFiltered
      ? i18n(themePrefix("js.owner_toggle.filtered"))
      : i18n(themePrefix("js.owner_toggle.unfiltered"));
  }



  goOwnerFiltered(owner) {
    if (!owner) {
      log.warn("Cannot filter: owner username not available");
      return;
    }
    const url = new URL(window.location.href);
    url.searchParams.set("username_filters", owner);

    log.info("Navigating to owner-filtered view", {
      owner,
      url: url.toString()
    });

    window.location.replace(url.toString());
  }

  goUnfiltered(topicId) {
    // Set opt-out flag so auto-mode won't immediately re-apply
    if (topicId) {
      this.setOptOut(topicId);
    }
    const url = new URL(window.location.href);
    url.searchParams.delete("username_filters");

    log.info("Navigating to unfiltered view", {
      topicId,
      optOutSet: !!topicId,
      url: url.toString()
    });

    window.location.replace(url.toString());
  }

  setOptOut(topicId) {
    try {
      sessionStorage.setItem(`ownerCommentsOptOut:${topicId}`, "1");
      log.debug("Set opt-out flag in sessionStorage", { topicId });
    } catch (error) {
      log.warn("Failed to set opt-out flag", { topicId, error });
    }
  }

  <template>
    <DButton
      @icon={{this.icon}}
      @translatedLabel={{this.translatedLabel}}
      @action={{this.toggleFilter}}
      class="btn-default owner-toggle-button {{if this.isOwnerFiltered 'filtered' 'unfiltered'}}"
    />
  </template>
}

