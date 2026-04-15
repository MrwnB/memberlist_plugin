# frozen_string_literal: true

DiscourseMemberlist::Engine.routes.draw do
  get "/memberlist-data" => "memberlist#index"
end

Discourse::Application.routes.draw do
  get "/memberlist" => "list#latest"
  mount DiscourseMemberlist::Engine, at: "/"
end
