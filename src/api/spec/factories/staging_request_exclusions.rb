FactoryBot.define do
  factory :request_exclusion, class: 'Staging::RequestExclusion' do
    description { Faker::Lorem.sentence }
  end
end
