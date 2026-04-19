# frozen_string_literal: true

RSpec.describe DiscourseMemberlist::MemberlistController do
  before do
    enable_current_plugin
    SiteSetting.discourse_memberlist_enabled = true
  end

  def find_or_create_group(group_name)
    Group.find_by(name: group_name) || Fabricate(:group, name: group_name)
  end

  def create_ranked_member(rank_name, username:, extra_group_names: [])
    group = find_or_create_group(rank_name)
    user = Fabricate(:user, username: username)

    group.add(user)
    user.update!(primary_group: group)
    extra_group_names.each do |group_name|
      find_or_create_group(group_name).add(user)
    end

    group
  end

  describe "GET /memberlist-data" do
    it "returns sections in rank order and flags reserve ranks" do
      create_ranked_member("guildsman", username: "guild_member")
      create_ranked_member("founder", username: "founder_member")
      create_ranked_member("retired_leader", username: "retired_member")
      create_ranked_member(
        "leader",
        username: "leader_member",
        extra_group_names: ["master_guardian", "grand_guardian"]
      )
      create_ranked_member(
        "high_council",
        username: "council_member",
        extra_group_names: ["grand_guardian"]
      )
      create_ranked_member("emeritus", username: "emeritus_member")

      get "/memberlist-data.json"

      expect(response.status).to eq(200)

      sections = response.parsed_body["sections"]

      expect(sections.map { |section| section["label"] }).to eq(
        [
          "Founder",
          "Leader",
          "High Council",
          "Retired Leader",
          "Emeritus",
          "Guildsman"
        ]
      )
      expect(sections.map { |section| section["sort_order"] }).to eq(
        [0, 1, 2, 15, 16, 17]
      )
      expect(
        sections.first(3).map { |section| section["is_reserve_rank"] }
      ).to eq([false, false, false])
      expect(
        sections.last(3).map { |section| section["is_reserve_rank"] }
      ).to eq([true, true, true])
      expect(
        sections
          .find { |section| section["label"] == "Leader" }
          .dig("members", 0, "has_master_guardian_glow")
      ).to eq(true)
      expect(
        sections
          .find { |section| section["label"] == "Leader" }
          .dig("members", 0, "has_grand_guardian_glow")
      ).to eq(true)
      expect(
        sections
          .find { |section| section["label"] == "High Council" }
          .dig("members", 0, "has_master_guardian_glow")
      ).to eq(false)
      expect(
        sections
          .find { |section| section["label"] == "High Council" }
          .dig("members", 0, "has_grand_guardian_glow")
      ).to eq(true)
      expect(
        sections
          .find { |section| section["label"] == "Founder" }
          .dig("members", 0, "has_master_guardian_glow")
      ).to eq(false)
      expect(
        sections
          .find { |section| section["label"] == "Founder" }
          .dig("members", 0, "has_grand_guardian_glow")
      ).to eq(false)
    end

    it "returns 404 when the feature is disabled" do
      SiteSetting.discourse_memberlist_enabled = false

      get "/memberlist-data.json"

      expect(response.status).to eq(404)
    end
  end
end
