import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import OwnerToggleButton from "../../components/owner-toggle-button";
import { isUserAllowedAccess } from "../../lib/group-access-utils";

/**
 * Desktop connector: renders toggle button in timeline footer controls.
 * Only shows on desktop when timeline is present and when user has access.
 */
export default class TimelineOwnerToggle extends Component {
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

@service site;




  <template>
    <OwnerToggleButton @topic={{@outletArgs.model}} />
  </template>
}

