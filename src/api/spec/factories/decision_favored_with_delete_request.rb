FactoryBot.define do
  factory :decision_favored_with_delete_request_for_package, class: 'DecisionFavoredWithDeleteRequest' do
    moderator factory: [:user]
    reason { Faker::Markdown.emphasis }

    after(:build) do |decision|
      decision.reports << create(:report, reportable: create(:package), reason: 'This is spam!') if decision.reports.empty?
    end
  end

  factory :decision_favored_with_delete_request_for_project, class: 'DecisionFavoredWithDeleteRequest' do
    moderator factory: [:user]
    reason { Faker::Markdown.emphasis }

    after(:build) do |decision|
      decision.reports << create(:report, reportable: create(:project_with_package), reason: 'This is spam!') if decision.reports.empty?
    end
  end
end
