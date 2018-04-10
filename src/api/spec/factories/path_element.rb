# frozen_string_literal: true
FactoryBot.define do
  factory :path_element do
    sequence(:position) { |n| n }
    repository
    link { create(:repository) }
  end
end
