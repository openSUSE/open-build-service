# frozen_string_literal: true
FactoryBot.define do
  factory :watched_project do
    project
    user
  end
end
