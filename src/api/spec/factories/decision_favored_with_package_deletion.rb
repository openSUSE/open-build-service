FactoryBot.define do
  factory :decision_favored_with_package_deletion, class: 'DecisionFavoredWithPackageDeletion' do
    moderator factory: [:user]
    reason { Faker::Markdown.emphasis }

    after(:build) do |decision|
      decision.reports << create(:report, reportable: create(:package), reason: 'This is spam!') if decision.reports.empty?
    end
  end
end
