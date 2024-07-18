FactoryBot.define do
  factory :workflow_artifacts_per_step, aliases: [:workflow_artifacts_per_step_branch_package] do
    workflow_run
    step { 'Workflow::Step::BranchPackageStep' }

    transient do
      source_project_name { Faker::Lorem.word }
      target_project_name { Faker::Lorem.word }
      source_package_name { Faker::Lorem.word }
      target_package_name { source_package_name }
    end

    before(:create) do |workflow_artifacts_per_step, evaluator|
      source_project = Project.find_by(name: evaluator.source_project_name) || create(:project, name: evaluator.source_project_name)
      target_project = Project.find_by(name: evaluator.target_project_name) || create(:project, name: evaluator.target_project_name)

      create(:package, name: evaluator.source_package_name, project: source_project) unless Package.find_by_project_and_name(evaluator.source_project_name, evaluator.source_package_name)
      create(:package, name: evaluator.target_package_name, project: target_project) unless Package.find_by_project_and_name(evaluator.target_project_name, evaluator.target_package_name)

      workflow_artifacts_per_step.artifacts = { source_project: evaluator.source_project_name,
                                                source_package: evaluator.source_package_name,
                                                target_project: evaluator.target_project_name,
                                                target_package: evaluator.target_package_name }.to_json
    end

    factory :workflow_artifacts_per_step_link_package do
      step { 'Workflow::Step::LinkPackageStep' }

      before(:create) do |workflow_artifacts_per_step, evaluator|
        workflow_artifacts_per_step.artifacts = { source_project: evaluator.source_project_name,
                                                  source_package: evaluator.source_package_name,
                                                  target_project: evaluator.target_project_name,
                                                  target_package: evaluator.target_package_name }.to_json
      end
    end
    factory :workflow_artifacts_per_step_rebuild_package do
      step { 'Workflow::Step::RebuildPackage' }

      before(:create) do |workflow_artifacts_per_step, evaluator|
        workflow_artifacts_per_step.artifacts = { project: evaluator.source_project_name,
                                                  package: evaluator.source_package_name }.to_json
      end
    end
    factory :workflow_artifacts_per_step_trigger_services do
      step { 'Workflow::Step::TriggerServices' }

      before(:create) do |workflow_artifacts_per_step, evaluator|
        workflow_artifacts_per_step.artifacts = { project: evaluator.source_project_name,
                                                  package: evaluator.source_package_name }.to_json
      end
    end
    factory :workflow_artifacts_per_step_config_repositories do
      step { 'Workflow::Step::ConfigureRepositories' }
      before(:create) do |workflow_artifacts_per_step, evaluator|
        workflow_artifacts_per_step.artifacts = {
          project: evaluator.target_project_name,
          repositories: [
            {
              name: 'openSUSE_Tumbleweed',
              paths: [
                {
                  target_project: 'openSUSE:Factory',
                  target_repository: 'snapshot'
                }
              ],
              architectures: ['x86_64']
            }
          ]
        }.to_json
      end
    end
    factory :workflow_artifacts_per_step_set_flags do
      step { 'Workflow::Step::SetFlags' }
      before(:create) do |workflow_artifacts_per_step, evaluator|
        workflow_artifacts_per_step.artifacts = {
          flags: [
            type: 'build',
            status: 'enable',
            project: evaluator.source_project_name,
            package: evaluator.source_package_name,
            repository: 'openSUSE_Tumbleweed',
            architecture: 'x86_64'
          ]
        }.to_json
      end
    end
  end
end
