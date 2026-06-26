FactoryBot.define do
  factory :path_element do
    sequence(:position) { |n| n }
    repository
    link { association :repository }
  end
end
