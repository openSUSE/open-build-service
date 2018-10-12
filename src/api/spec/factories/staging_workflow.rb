FactoryBot.define do
  factory :staging_workflow do
    project { nil }

    factory :staging_workflow_with_staging_projects do
      transient do
        staging_project_count { 2 }
      end

      after(:create) do |staging_workflow, evaluator|
        evaluator.staging_project_count.times do
          new_staging_project = create(:staging_project)
          staging_workflow.staging_projects << new_staging_project
        end
      end
    end
  end
end
