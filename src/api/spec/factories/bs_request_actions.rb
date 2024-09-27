FactoryBot.define do
  factory :bs_request_action do
    factory :bs_request_action_add_maintainer_role do
      type { 'add_role' }
      role { Role.find_by_title('maintainer') }
      person_name { create(:user).login }
    end
    factory :bs_request_action_add_bugowner_role do
      type { 'add_role' }
      role { Role.find_by_title('bugowner') }
      person_name { create(:user).login }
    end
    factory :bs_request_action_submit, class: 'BsRequestActionSubmit' do
      type { 'submit' }

      factory :bs_request_action_submit_with_diff, class: 'BsRequestActionSubmit' do
        transient do
          source_project_name { 'source_project' }
          source_package_name { 'source_package' }
          target_project_name { 'target_project' }
          target_package_name { 'target_package' }
          creator { association :confirmed_user }
        end

        source_project do |evaluator|
          Project.find_by_name(evaluator.source_project_name) ||
            create(:project, :as_submission_source, name: evaluator.source_project_name)
        end
        source_package do |evaluator|
          Package.find_by_project_and_name(source_project.name, evaluator.source_package_name) ||
            create(:package_with_file,
                   project: source_project,
                   name: evaluator.source_package_name,
                   file_name: 'somefile.txt',
                   file_content: '# This is the new text')
        end
        target_project do |evaluator|
          Project.find_by_name(evaluator.target_project_name) ||
            create(:project, name: target_project_name)
        end
        target_package do |evaluator|
          Package.find_by_project_and_name(target_project.name, evaluator.target_package_name) ||
            create(:package_with_file,
                   project: target_project,
                   name: target_package_name,
                   file_name: 'somefile.txt',
                   file_content: '# This will be replaced')
        end

        bs_request do |evaluator|
          evaluator.bs_request || create(:bs_request_with_submit_action)
        end
      end
    end
    factory :bs_request_action_delete, class: 'BsRequestActionDelete' do
      type { 'delete' }
    end
    factory :bs_request_action_maintenance_incident, class: 'BsRequestActionMaintenanceIncident' do
      type { 'maintenance_incident' }
    end
    factory :bs_request_action_maintenance_release, class: 'BsRequestActionMaintenanceRelease' do
      type { 'maintenance_release' }
    end
    factory :bs_request_action_set_bugowner, class: 'BsRequestActionSetBugowner' do
      type { :set_bugowner }
      person_name { create(:user).login }
    end

    factory :bs_request_action_change_devel, class: 'BsRequestActionChangeDevel' do
      type { :change_devel }

      transient do
        source_project_name { 'source_project' }
        target_project_name { 'target_project' }
        target_package_name { 'target_package' }
      end

      source_project do |evaluator|
        Project.find_by_name(evaluator.source_project_name) ||
          create(:project, name: evaluator.source_project_name)
      end
      source_package do |evaluator|
        Package.find_by_project_and_name(source_project.name, evaluator.target_package_name) ||
          create(:package_with_file,
                 project: source_project,
                 name: evaluator.target_package_name)
      end
      target_project do |evaluator|
        Project.find_by_name(evaluator.target_project_name) ||
          create(:project, name: target_project_name)
      end
      target_package do |evaluator|
        package = Package.find_by_project_and_name(target_project.name, evaluator.target_package_name) ||
                  create(:package_with_file, project: target_project, name: target_package_name)
        package.update(develpackage: Package.first) unless package.develpackage
        package
      end
    end
  end
end
