# frozen_string_literal: true
FactoryBot.define do
  factory :attrib_namespace do
    name { Faker::Lorem.word }
  end
end
