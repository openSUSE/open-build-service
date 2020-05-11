FactoryBot.define do
  factory :role do
    sequence(:title) { |n| "role_#{n}" }
  end
end
