FactoryBot.define do
  factory :architecture do
    sequence(:name) { |n| "arch_factory_#{n}" }
  end
end
