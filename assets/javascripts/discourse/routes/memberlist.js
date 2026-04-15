import DiscourseRoute from "discourse/routes/discourse";

export default class MemberlistRoute extends DiscourseRoute {
  titleToken() {
    return "Memberlist";
  }
}
