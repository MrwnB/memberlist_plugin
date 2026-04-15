# frozen_string_literal: true

DiscourseMemberlist::Engine.routes.draw { get "/memberlist-data" => "memberlist#index" }

Discourse::Application.routes.draw do
  get "/memberlist" => "list#latest"
  mount DiscourseMemberlist::Engine, at: "/"
end
