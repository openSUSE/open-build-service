FactoryBot.define do
  factory :project do
    transient do
      link_to { nil }
      maintainer { nil }
      project_config { nil }
    end

    sequence(:name) { |n| "project_#{n}" }
    title { Faker::Book.title }

    after(:build) do |project, evaluator|
      project.commit_user ||= create(:confirmed_user)

      if evaluator.maintainer
        role = Role.find_by_title('maintainer')
        maintainers = Array(evaluator.maintainer)
        maintainers.each do |maintainer|
          case maintainer
          when User
            project.relationships.build(user: maintainer, role: role)
          when Group
            project.relationships.build(group: maintainer, role: role)
          end
        end
      end
    end

    after(:create) do |project, evaluator|
      LinkedProject.create(project: project, linked_db_project: evaluator.link_to) if evaluator.link_to

      project.config.save({ user: 'factory bot' }, evaluator.project_config) if evaluator.project_config

      project.write_to_backend
    end

    trait :as_submission_source do
      after(:create) do |project, _evaluator|
        project.commit_user.run_as do
          create(:approved_request_source_attrib, project: project)
        end
      end
    end

    # remote projects validate additional the description and remoteurl
    factory :remote_project do
      description { Faker::Lorem.sentence }
      remoteurl { Faker::Internet.url }
    end

    factory :project_with_package do
      transient do
        package_name { nil }
        create_patchinfo { false }
      end

      after(:create) do |project, evaluator|
        new_package = create(:package, { project: project, name: evaluator.package_name }.compact)
        project.packages << new_package
        Patchinfo.new.create_patchinfo(project.name, new_package.name, comment: 'Fake comment', force: true) if evaluator.create_patchinfo
      end
    end

    factory :project_with_packages do
      transient do
        package_name { nil }
        package_title { nil }
        package_description { nil }
        package_count { 2 }
        create_patchinfo { false }
      end

      after(:create) do |project, evaluator|
        evaluator.package_count.times do |index|
          package_title = nil
          package_title = "#{evaluator.package_title}_#{index}" if evaluator.package_title

          package_description = nil
          package_description = "#{evaluator.package_description}_#{index}" if evaluator.package_description

          package_name = nil
          package_name = "#{evaluator.package_name}_#{index}" if evaluator.package_name

          new_package = create(:package, {
            project: project,
            name: package_name,
            title: package_title,
            description: package_description
          }.compact)
          project.packages << new_package
          Patchinfo.new.create_patchinfo(project.name, new_package.name, comment: 'Fake comment', force: true) if evaluator.create_patchinfo
        end
      end
    end

    factory :forbidden_project do
      after(:create) do |project|
        create(:access_flag, status: 'disable', project: project)
      end
    end

    factory :locked_project do
      after(:create) do |project|
        create(:lock_flag, status: 'enable', project: project)
      end
    end

    factory :project_with_repository do
      after(:create) do |project|
        create(:repository, project: project, architectures: ['i586'])
      end
    end

    factory :maintenance_incident_project do
      kind { 'maintenance_incident' }

      transient do
        maintenance_project { create(:maintenance_project) }
      end

      before(:create) do |project, evaluator|
        if evaluator.maintenance_project
          evaluator.maintenance_project.relationships.each do |role|
            project.relationships.create(user: role.user, role: role.role, group: role.group)
          end
        end
      end
    end

    factory :maintenance_project do
      kind { 'maintenance' }

      transient do
        target_project { nil }
        create_patchinfo { false }
      end

      before(:create) do |project|
        create(:build_flag, project: project, status: 'disable')
      end

      after(:create) do |project, evaluator|
        create(:maintenance_project_attrib, project: project)
        if evaluator.target_project
          create(:maintained_project, project: evaluator.target_project, maintenance_project: project)
          CONFIG['global_write_through'] ? project.store : project.save!
        end
        if evaluator.create_patchinfo
          old_user = User.session
          User.session = evaluator.maintainer
          Patchinfo.new.create_patchinfo(project.name, nil, comment: 'Fake comment', force: true)
          User.session = old_user
        end
      end

      factory :maintenance_project_with_packages do
        packages { [create(:package_with_file)] }
      end
    end

    factory :update_project do
      kind { 'maintenance_release' }

      transient do
        target_project { create(:project_with_repository) }
      end

      after(:create) do |update_project, evaluator|
        create(:update_project_attrib, project: evaluator.target_project, update_project: update_project)
        if evaluator.target_project
          create(:build_flag, status: 'disable', project: evaluator.target_project)
          create(:publish_flag, status: 'disable', project: evaluator.target_project)
          update_project.projects_linking_to << evaluator.target_project
          CONFIG['global_write_through'] ? update_project.store : update_project.save!
          new_repository = create(:repository, project: update_project, architectures: ['i586'])
          create(:path_element, repository: new_repository, link: evaluator.target_project.repositories.first)
        end
      end
    end

    # rubocop:disable Style/ArrayCoercion
    factory :staging_project do
      # Staging workflows have 2 staging projects by default, *:Staging:A and *:Staging:B.
      sequence(:name, [*'C'..'Z'].cycle) { |letter| "#{staging_workflow.project.name}:Staging:#{letter}" }
    end
    # rubocop:enable Style/ArrayCoercion
  end
end
