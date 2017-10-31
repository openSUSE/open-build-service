FactoryBot.define do
  factory :status_message do
    message { Faker::Lorem.paragraph }
    severity "Green"
    user
  end
end
