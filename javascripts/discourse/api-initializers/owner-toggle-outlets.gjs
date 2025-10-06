import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { apiInitializer } from "discourse/lib/api";
import OwnerToggleButton from "../components/owner-toggle-button";
import {
  isUserAllowedAccess,
  shouldShowToggleButton,
} from "../lib/group-access-utils";

class BaseOwnerToggle extends Component {
  get topic() {
    return this.args.model ?? this.args.topic;
  }

  get wrapperClass() {
    return "owner-toggle-wrapper";
  }

  <template>
    {{#if this.topic}}
      <div class={{this.wrapperClass}}>
        <OwnerToggleButton @topic={{this.topic}} />
      </div>
    {{/if}}
  </template>
}

class TimelineOwnerToggle extends BaseOwnerToggle {
  get wrapperClass() {
    return "owner-toggle-wrapper owner-toggle-wrapper--timeline";
  }

  static shouldRender(outletArgs, helper) {
    if (!shouldShowToggleButton(outletArgs)) {
      return false;
    }

    if (!isUserAllowedAccess(helper)) {
      return false;
    }

    const owner = getOwner(helper);
    const site = owner?.lookup?.("service:site");

    return !!site && !site.mobileView;
  }
}

class MobileOwnerToggle extends BaseOwnerToggle {
  get wrapperClass() {
    return "owner-toggle-wrapper owner-toggle-wrapper--mobile";
  }

  static shouldRender(outletArgs, helper) {
    if (!shouldShowToggleButton(outletArgs)) {
      return false;
    }

    if (!isUserAllowedAccess(helper)) {
      return false;
    }

    const owner = getOwner(helper);
    const site = owner?.lookup?.("service:site");

    return !!site && site.mobileView;
  }
}

export default apiInitializer("1.15.0", (api) => {
  api.renderInOutlet("timeline-footer-controls-after", TimelineOwnerToggle);
  api.renderInOutlet("before-topic-progress", MobileOwnerToggle);
});
