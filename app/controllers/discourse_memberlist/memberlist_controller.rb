# frozen_string_literal: true

module ::DiscourseMemberlist
  class MemberlistController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    RANK_ORDER = [
      "founder",
      "leader",
      "high council",
      "head warlord",
      "council",
      "app manager",
      "warlord",
      "eventmaster",
      "officer",
      "elite guardian",
      "high guardian",
      "heroic guardian",
      "honoured guardian",
      "guardian",
      "initiate guardian",
    ].freeze
    RESERVE_RANKS = ["retired leader", "emeritus", "guildsman"].freeze
    RANK_ORDER_INDEX = RANK_ORDER.each_with_index.to_h.freeze
    RESERVE_RANK_INDEX = RESERVE_RANKS.each_with_index.to_h.freeze
    RSN_FIELD_KEY = "rsn"

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
        .to_a
        .sort_by do |group|
          [group_bucket(group), rank_sort_order_for(group), normalized_rank_key(group_label(group))]
        end
        .filter_map { |group| serialize_group(group) }
    end

    def serialize_group(group)
      sort_order = rank_sort_order_for(group)
      members = group.users.where(staged: false, primary_group_id: group.id).order(:username_lower).to_a
      return if members.empty?

      rsn_values_by_user_id = rsn_values_by_user_id_for(members)

      {
        id: group.id,
        name: group.name,
        label: group_label(group),
        sort_order: sort_order,
        is_reserve_rank: reserve_rank?(group),
        members:
          members.map do |user|
            {
              id: user.id,
              username: user.username,
              username_lower: user.username_lower,
              name: user.name,
              avatar_template: user.avatar_template,
              rsn: rsn_values_by_user_id[user.id],
            }
          end,
      }
    end

    def group_label(group)
      group.full_name.presence || group.name.tr("_-", " ").split.map(&:capitalize).join(" ")
    end

    def normalized_rank_key(value)
      value.to_s.strip.downcase.gsub(/[_\s-]+/, " ")
    end

    def rank_sort_order_for(group)
      if reserve_rank?(group)
        [group.full_name, group.name].each do |value|
          normalized_value = normalized_rank_key(value)
          return RESERVE_RANK_INDEX[normalized_value] if RESERVE_RANK_INDEX.key?(normalized_value)
        end

        return RESERVE_RANKS.length
      end

      if main_rank?(group)
        [group.full_name, group.name].each do |value|
          normalized_value = normalized_rank_key(value)
          return RANK_ORDER_INDEX[normalized_value] if RANK_ORDER_INDEX.key?(normalized_value)
        end

        return RANK_ORDER.length
      end

      RANK_ORDER.length
    end

    def main_rank?(group)
      return false if reserve_rank?(group)

      [group.full_name, group.name].any? do |value|
        RANK_ORDER.include?(normalized_rank_key(value))
      end
    end

    def group_bucket(group)
      return 0 if main_rank?(group)
      return 1 if reserve_rank?(group)

      2
    end

    def reserve_rank?(group)
      [group.full_name, group.name].any? do |value|
        RESERVE_RANKS.include?(normalized_rank_key(value))
      end
    end

    def rsn_values_by_user_id_for(members)
      return {} if members.empty? || rsn_user_field_id.blank?

      UserCustomField
        .where(user_id: members.map(&:id), name: "user_field_#{rsn_user_field_id}")
        .pluck(:user_id, :value)
        .to_h
        .transform_values { |value| cleaned_value(value) }
    end

    def rsn_user_field_id
      @rsn_user_field_id ||=
        UserField.where("LOWER(name) = :field_name OR LOWER(external_name) = :field_name", field_name: RSN_FIELD_KEY).pick(:id)
    end

    def cleaned_value(value)
      value.to_s.strip.presence
    end
  end
end
