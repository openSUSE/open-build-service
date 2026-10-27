FactoryBot.define do
  factory :distro do
    sequence(:name) { |n| "Distro #{n}" }
    description { Faker::Lorem.sentence }
    url { Faker::Internet.url }
    vendor
  end
end
