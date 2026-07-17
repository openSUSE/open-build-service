FactoryBot.define do
  factory :status_message do
    message { Faker::Lorem.paragraph }
    severity { :green }
    communication_scope { 'all_users' }
    association :creator, factory: :user

    trait :admins_only do
      communication_scope { 'admin_users' }
    end
  end
end
