FactoryBot.define do
  factory :check, class: Status::Check do
    sequence(:name) { |n| "check_#{n}" }
    checkable { create(:status_repository_publish) }
    url { Faker::Internet.url }
    state { %w[pending error failure success].sample }
    short_description { Faker::Lorem.sentence }
  end
end
