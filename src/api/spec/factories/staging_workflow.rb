FactoryBot.define do
  factory :staging_workflow, class: 'Staging::Workflow' do
    project
    association :managers_group, factory: :group_with_user

    after(:build) do |workflow|
      workflow.commit_user ||= build(:confirmed_user)
    end

    factory :staging_workflow_with_staging_projects do
      initialize_with { new(attributes) }

      transient do
        staging_project_count { 2 }
      end

      after(:create) do |staging_workflow, evaluator|
        # StagingWorkflow have some staging projects already after initialize
        new_staging_projects_count = evaluator.staging_project_count - staging_workflow.staging_projects.count
        letters = Array('A'..'Z')
        new_staging_projects_count.times do |index|
          letter = letters[index + staging_workflow.staging_projects.count]
          staging_workflow.staging_projects << create(:staging_project, name: "#{staging_workflow.project.name}:Staging:#{letter}", maintainer: staging_workflow.managers_group)
        end
      end

      factory :staging_workflow_with_sources do
        transient do
          bs_request_count { 10 }
        end

        after(:create) do |staging_workflow, evaluator|
          target_packages = create_list(:package, evaluator.bs_request_count, project: staging_workflow.project)
          source_project = create(:project)
          target_packages.each do |package|
            create(:package_with_file, name: package.name, project: source_project)
          end
          target_packages.each do |target_package|
            create(:bs_request_with_submit_action, target_project: staging_workflow.project,
                                                   target_package: target_package,
                                                   source_package: source_project.packages.find_by(name: target_package.name))
          end
          staging_workflow.managers_group.users.first.run_as do
            target_packages.each do |package|
              Staging::StagedRequests.new(
                request_numbers: [package.target_of_bs_requests.first.number],
                staging_workflow: staging_workflow,
                staging_project: staging_workflow.staging_projects.sample,
                user_login: staging_workflow.managers_group.users.first
              ).create!
            end
          end
        end
      end
    end
  end
end
