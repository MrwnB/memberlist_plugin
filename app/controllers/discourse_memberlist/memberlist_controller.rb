# frozen_string_literal: true

module ::DiscourseMemberlist
  class MemberlistController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    def index
      render_json_dump(sections: member_sections)
    end

    private

    def member_sections
      return [] unless SiteSetting.discourse_memberlist_enabled

      # Intentionally ignore group/member visibility checks so the public
      # memberlist shows every non-automatic closed group.
      Group
        .where(public_admission: false, automatic: false)
        .order("groups.name ASC")
        .distinct
        .includes(:group_users, users: :primary_group)
        .map { |group| serialize_group(group) }
        .compact
    end

    def serialize_group(group)
      owner_user_ids = group.group_users.select(&:owner?).map(&:user_id).to_set
      members =
        group
          .users
          .includes(:primary_group)
          .where(staged: false)
          .distinct
          .order(Arel.sql("LOWER(users.username)"))

      serialized_members =
        members.map do |user|
          {
            id: user.id,
            username: user.username,
            username_lower: user.username_lower,
            name: user.name,
            avatar_template: user.avatar_template,
            title: user.title,
            primary_group_name: user.primary_group&.full_name.presence || user.primary_group&.name,
            owner: owner_user_ids.include?(user.id),
          }
        end

      return if serialized_members.empty?

      {
        id: group.id,
        name: group.name,
        label: group.full_name.presence || group.name.tr("_-", " ").split.map(&:capitalize).join(" "),
        members: serialized_members,
      }
    end
  end
end
