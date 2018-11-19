FactoryBot.define do
  factory :staging_workflow, class: 'Staging::Workflow' do
    project
    association :managers_group, factory: :group, title: 'staging-workflow-managers'

    factory :staging_workflow_with_staging_projects do
      initialize_with { new(attributes) }

      transient do
        staging_project_count { 2 }
      end

      after(:create) do |staging_workflow, evaluator|
        # StagingWorkflow have some staging projects already after initialize
        new_staging_projects_count = evaluator.staging_project_count - staging_workflow.staging_projects.count
        letters = [*'A'..'Z']
        new_staging_projects_count.times do |index|
          letter = letters[index + staging_workflow.staging_projects.count]
          staging_workflow.staging_projects << create(:staging_project, name: "#{project.name}:Staging:#{letter}")
        end
      end
    end
  end
end
