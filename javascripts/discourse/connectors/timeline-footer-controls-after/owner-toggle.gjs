import Component from "@glimmer/component";
import { service } from "@ember/service";
import { getOwner } from "@ember/owner";
import OwnerToggleButton from "../../components/owner-toggle-button";

/**
 * Desktop connector: renders toggle button in timeline footer controls.
 * Only shows on desktop when timeline is present.
 */
export default class TimelineOwnerToggle extends Component {
  @service site;

  // Only render on desktop view (timeline is desktop-only)
  static shouldRender(outletArgs, helper) {
    const owner = getOwner(helper);
    const site = owner.lookup("service:site");

    // Only show on desktop
    return !site?.mobileView;
  }

  <template>
    <OwnerToggleButton @topic={{@outletArgs.model}} />
  </template>
}

