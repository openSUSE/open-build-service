FactoryBot.define do
  factory :decision_favored_with_comment_moderation do
    moderator factory: [:user]
    reason { Faker::Markdown.emphasis }

    after(:build) do |decision|
      decision.reports << create(:report, reason: 'This is spam!') if decision.reports.empty?
    end
  end
end
