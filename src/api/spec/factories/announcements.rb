FactoryBot.define do
  factory :announcement do
    message { Faker::Lorem.sentence }
    communication_scope { 'all_users' }
  end
end
