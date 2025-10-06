import Component from "@glimmer/component";
import { service } from "@ember/service";
import { getOwner } from "@ember/owner";
import OwnerToggleButton from "../../components/owner-toggle-button";
import { isUserAllowedAccess } from "../../lib/group-access-utils";

/**
 * Desktop connector: renders toggle button in timeline footer controls.
 * Only shows on desktop when timeline is present and when user has access.
 */
export default class TimelineOwnerToggle extends Component {
  @service site;

  // Only render on desktop view and if user has group access
  static shouldRender(outletArgs, helper) {
    const owner = getOwner(helper);
    const site = owner.lookup("service:site");

    // Check desktop view
    if (site?.mobileView) {
      return false;
    }

    // Check group-based access control
    return isUserAllowedAccess(helper);
  }

  <template>
    <OwnerToggleButton @topic={{@outletArgs.model}} />
  </template>
}

