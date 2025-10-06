import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import OwnerToggleButton from "../../components/owner-toggle-button";
import {
  isUserAllowedAccess,
  shouldShowToggleButton,
} from "../../lib/group-access-utils";

/**
 * Mobile connector: renders toggle button before topic progress wrapper.
 * Only shows on mobile view, in configured categories, and when user has access.
 */
export default class MobileOwnerToggle extends Component {
  // Only render on mobile view, in enabled categories, and if user has group access
  static shouldRender(outletArgs, helper) {
    const owner = getOwner(helper);
    const site = owner.lookup("service:site");

    // Check mobile view
    if (!site?.mobileView) {
      return false;
    }

    // Check if toggle button is enabled and category is configured
    if (!shouldShowToggleButton(outletArgs)) {
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

