FactoryBot.define do
  factory :check, class: Status::Check do
    checkable { create(:status_repository_publish) }
    url { Faker::Internet.url }
    state 'failed'
    short_description { Faker::Lorem.sentence }
    name { Faker::Cat.name }
  end
end
