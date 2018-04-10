# frozen_string_literal: true
FactoryBot.define do
  factory :architecture do
    sequence(:name) { |n| "arch_factory_#{n}" }
  end
end
