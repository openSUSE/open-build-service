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
      create(:linked_project, project: project, linked_db_project: evaluator.link_to) if evaluator.link_to.is_a?(Project)
      create(:linked_project, project: project, linked_remote_project_name: evaluator.link_to) if evaluator.link_to.is_a?(String)

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
      end

      after(:create) do |project, evaluator|
        new_package = create(:package, { project: project, name: evaluator.package_name }.compact)
        project.packages << new_package
      end
    end

    factory :project_with_packages do
      transient do
        package_name { nil }
        package_title { nil }
        package_description { nil }
        package_count { 2 }
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

    # FIXME: Repository.name and architecture should be transient
    factory :project_with_repository do
      after(:create) do |project|
        create(:repository, project: project, architectures: ['i586'])
        project.store if CONFIG['global_write_through']
      end
    end

    factory :maintenance_incident_project do
      kind { 'maintenance_incident' }

      transient do
        maintenance_project { create(:maintenance_project) } # rubocop:disable FactoryBot/FactoryAssociationWithStrategy
      end

      before(:create) do |project, evaluator|
        if evaluator.maintenance_project
          evaluator.maintenance_project.relationships.each do |role|
            project.relationships.create(user: role.user, role: role.role, group: role.group)
          end
        end
      end
    end

    factory :maintenance_project do # openSUSE:Maintenance
      kind { 'maintenance' }

      transient do
        target_project { nil }      # maintains -> update projects (for example: openSUSE:Leap:15.4:Update)
        create_patchinfo { false }
      end

      before(:create) do |project|
        create(:build_flag, project: project, status: 'disable')
      end

      after(:create) do |project, evaluator|
        create(:maintenance_project_attrib, project: project)
        if evaluator.target_project
          target_projects = if evaluator.target_project.is_a?(Array)
                              evaluator.target_project
                            else
                              [evaluator.target_project]
                            end
          CONFIG['global_write_through'] ? project.store : project.save!
          target_projects.each do |tp|
            create(:maintained_project, project: tp, maintenance_project: project)
          end
        end

        evaluator.maintainer.run_as { create(:patchinfo, project_name: project.name, comment: 'Fake comment', force: true) } if evaluator.create_patchinfo
      end

      factory :maintenance_project_with_packages do
        packages { create_list(:package_with_file, 1) }
      end
    end

    factory :update_project do
      kind { 'maintenance_release' }

      transient do
        maintained_project { association :project_with_repository }
        maintenance_project { nil }
      end

      after(:create) do |update_project, evaluator|
        # i.e. Set OBS:Maintained attribute on the openSUSE:Leap:15.4
        create(:maintained_attrib, project: update_project)

        # i.e. Set OBS:UpdateProject attribute with value openSUSE:Leap:15.4:Update on openSUSE:Leap:15.4
        create(:update_project_attrib, project: evaluator.maintained_project, update_project: update_project)

        # Set the relationship between the update project and the maintenance project
        create(:maintained_project, project: update_project, maintenance_project: evaluator.maintenance_project) if evaluator.maintenance_project

        create(:build_flag, status: 'disable', project: evaluator.maintained_project)
        create(:publish_flag, status: 'disable', project: evaluator.maintained_project)
        update_project.projects_linking_to << evaluator.maintained_project
        CONFIG['global_write_through'] ? update_project.store : update_project.save!
        new_repository = create(:repository, project: update_project, architectures: ['i586'])
        create(:path_element, repository: new_repository, link: evaluator.maintained_project.repositories.first)
      end
    end

    factory :staging_project do
      # Staging workflows have 2 staging projects by default, *:Staging:A and *:Staging:B.
      sequence(:name, [*'C'..'Z'].cycle) { |letter| "#{staging_workflow.project.name}:Staging:#{letter}" }
    end
  end
end
