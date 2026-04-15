import { apiInitializer } from "discourse/lib/api";
import getURL from "discourse/lib/get-url";

export default apiInitializer((api) => {
  const siteSettings = api.container.lookup("service:site-settings");

  if (!siteSettings.discourse_memberlist_enabled) {
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
