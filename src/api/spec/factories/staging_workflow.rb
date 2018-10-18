FactoryBot.define do
  factory :staging_workflow do
    factory :staging_workflow_with_staging_projects do
      transient do
        staging_project_count { 2 }
      end

      after(:create) do |staging_workflow, evaluator|
        evaluator.staging_project_count.times do
          staging_workflow.staging_projects << create(:staging_project, workflow_project_name: staging_workflow.project.name)
        end
      end
    end
  end
end
