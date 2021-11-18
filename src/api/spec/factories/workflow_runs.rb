FactoryBot.define do
  factory :workflow_run do
    request_headers  { Faker::Lorem.characters(number: 32) }
    request_payload  { Faker::Lorem.characters(number: 32) }
    token
  end
end
