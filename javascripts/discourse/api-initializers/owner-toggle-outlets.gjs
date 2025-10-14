import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { apiInitializer } from "discourse/lib/api";
import OwnerToggleButton from "../components/owner-toggle-button";
import {
  isUserAllowedAccess,
  shouldShowToggleButton,
} from "../lib/group-access-utils";
import { createLogger } from "../lib/logger";

/**
 * Owner Toggle Outlets - Render toggle button in timeline and mobile outlets
 *
 * Settings used:
 * - toggle_view_button_enabled: enable toggle button
 * - owner_comment_categories: list of category IDs
 * - allowed_groups: list of group IDs for access control
 * - debug_logging_enabled: enable verbose console logging
 */

const log = createLogger("[Owner View] [Toggle Outlets]");

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
  static shouldRender(outletArgs, helper) {
    const shouldShow = shouldShowToggleButton(outletArgs);
    if (!shouldShow) {
      log.debug("Timeline toggle: shouldShowToggleButton returned false");
      return false;
    }

    const hasAccess = isUserAllowedAccess(helper, outletArgs);
    if (!hasAccess) {
      log.debug("Timeline toggle: user access denied");
      return false;
    }

    const owner = getOwner(helper);
    const site = owner?.lookup?.("service:site");
    const isDesktop = !!site && !site.mobileView;

    log.debug("Timeline toggle shouldRender", {
      shouldShow,
      hasAccess,
      isDesktop,
      result: isDesktop
    });

    return isDesktop;
  }

  get wrapperClass() {
    return "owner-toggle-wrapper owner-toggle-wrapper--timeline";
  }
}

class MobileOwnerToggle extends BaseOwnerToggle {
  static shouldRender(outletArgs, helper) {
    const shouldShow = shouldShowToggleButton(outletArgs);
    if (!shouldShow) {
      log.debug("Mobile toggle: shouldShowToggleButton returned false");
      return false;
    }

    const hasAccess = isUserAllowedAccess(helper, outletArgs);
    if (!hasAccess) {
      log.debug("Mobile toggle: user access denied");
      return false;
    }

    const owner = getOwner(helper);
    const site = owner?.lookup?.("service:site");
    const isMobile = !!site && site.mobileView;

    log.debug("Mobile toggle shouldRender", {
      shouldShow,
      hasAccess,
      isMobile,
      result: isMobile
    });

    return isMobile;
  }

  get wrapperClass() {
    return "owner-toggle-wrapper owner-toggle-wrapper--mobile";
  }
}

export default apiInitializer("1.15.0", (api) => {
  log.info("Registering toggle button outlets");
  api.renderInOutlet("timeline-footer-controls-after", TimelineOwnerToggle);
  api.renderInOutlet("before-topic-progress", MobileOwnerToggle);
});
