import getURL from "discourse/lib/get-url";
import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "discourse-memberlist-nav",

  initialize() {
    withPluginApi((api) => {
      if (!settings.discourse_memberlist_enabled) {
        return;
      }

      api.addNavigationBarItem({
        name: "memberlist",
        displayName: "Memberlist",
        href: getURL("/memberlist"),
        forceActive(_category, _args, router) {
          return router.currentRouteName === "memberlist";
        },
      });
    });
  },
};
