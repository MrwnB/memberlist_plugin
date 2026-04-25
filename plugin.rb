# frozen_string_literal: true

# name: memberlist_plugin
# about: Public memberlist page for visible closed groups and their members
# version: 0.1
# authors: GoreDef
# url: https://www.wildernessguardians.com
# required_version: 2.7.0

enabled_site_setting :discourse_memberlist_enabled

register_asset "stylesheets/common/discourse-memberlist.scss"

module ::DiscourseMemberlist
  PLUGIN_NAME = "memberlist_plugin"
end

require_relative "lib/discourse_memberlist/engine"

after_initialize do
  # Plugin boot is handled by the isolated engine and controller files.
end
