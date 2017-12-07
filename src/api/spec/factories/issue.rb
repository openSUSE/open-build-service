FactoryBot.define do
  factory :issue do
    name Faker::Lorem.words(5).join(' ')

    factory :issue_with_tracker do
      issue_tracker
    end
  end
end
