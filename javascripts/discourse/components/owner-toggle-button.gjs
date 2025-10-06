import Component from "@glimmer/component";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";

/**
 * Shared toggle button component for owner-filtered view.
 * Reuses the same toggle logic as the footer button.
 * Can be rendered in multiple outlets (timeline, mobile progress, footer).
 */
export default class OwnerToggleButton extends Component {
  @service router;

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
    const prefix = "theme_translations.owner_toggle";
    return this.isOwnerFiltered
      ? i18n(`${prefix}.filtered`)
      : i18n(`${prefix}.unfiltered`);
  }

  toggleFilter = () => {
    const topic = this.topic;
    const owner = topic?.details?.created_by?.username;

    if (this.isOwnerFiltered) {
      // Go to unfiltered view
      this.goUnfiltered(topic?.id);
    } else {
      // Go to owner-filtered view
      this.goOwnerFiltered(owner);
    }
  };

  goOwnerFiltered(owner) {
    if (!owner) {
      return;
    }
    const url = new URL(window.location.href);
    url.searchParams.set("username_filters", owner);
    window.location.replace(url.toString());
  }

  goUnfiltered(topicId) {
    // Set opt-out flag so auto-mode won't immediately re-apply
    if (topicId) {
      this.setOptOut(topicId);
    }
    const url = new URL(window.location.href);
    url.searchParams.delete("username_filters");
    window.location.replace(url.toString());
  }

  setOptOut(topicId) {
    try {
      sessionStorage.setItem(`ownerCommentsOptOut:${topicId}`, "1");
    } catch {
      // no-op
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

