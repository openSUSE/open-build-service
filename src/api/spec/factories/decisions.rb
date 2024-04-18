FactoryBot.define do
  factory :decision do
    moderator factory: [:user]
    reason { Faker::Markdown.emphasis }

    after(:build) do |decision|
      decision.reports << create(:report, reason: 'This is spam!') if decision.reports.empty?
    end

    trait :cleared do
      type { 'DecisionCleared' }
    end

    trait :favored do
      type { 'DecisionFavored' }
    end
  end
end
