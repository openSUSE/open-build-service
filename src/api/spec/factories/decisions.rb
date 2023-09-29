FactoryBot.define do
  factory :decision do
    moderator factory: [:user]
    reason { Faker::Markdown.emphasis }

    after(:build) do |decision|
      decision.reports << create(:report, reason: 'This is spam!')
    end

    trait :cleared do
      kind { 'cleared' }
    end

    trait :favor do
      kind { 'favor' }
    end
  end
end
