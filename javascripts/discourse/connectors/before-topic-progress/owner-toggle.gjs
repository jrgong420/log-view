import Component from "@glimmer/component";
import { service } from "@ember/service";
import { getOwner } from "@ember/owner";
import OwnerToggleButton from "../../components/owner-toggle-button";
import { isUserAllowedAccess } from "../../lib/group-access-utils";

/**
 * Mobile connector: renders toggle button before topic progress wrapper.
 * Only shows on mobile view and when user has access.
 */
export default class MobileOwnerToggle extends Component {
  @service site;

  // Only render on mobile view and if user has group access
  static shouldRender(outletArgs, helper) {
    const owner = getOwner(helper);
    const site = owner.lookup("service:site");

    // Check mobile view
    if (!site?.mobileView) {
      return false;
    }

    // Check group-based access control
    return isUserAllowedAccess(helper);
  }

  <template>
    <OwnerToggleButton @topic={{@outletArgs.model}} />
  </template>
}

