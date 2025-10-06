import Component from "@glimmer/component";
import { service } from "@ember/service";
import { getOwner } from "@ember/owner";
import OwnerToggleButton from "../../components/owner-toggle-button";

/**
 * Mobile connector: renders toggle button before topic progress wrapper.
 * Only shows on mobile view.
 */
export default class MobileOwnerToggle extends Component {
  @service site;

  // Only render on mobile view
  static shouldRender(outletArgs, helper) {
    const owner = getOwner(helper);
    const site = owner.lookup("service:site");

    // Only show on mobile
    return site?.mobileView;
  }

  <template>
    <OwnerToggleButton @topic={{@outletArgs.model}} />
  </template>
}

