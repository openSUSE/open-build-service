# frozen_string_literal: true
FactoryBot.define do
  factory :maintained_project do
    project
    maintenance_project
  end
end
