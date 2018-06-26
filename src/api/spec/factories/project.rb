FactoryBot.define do
  factory :project do
    transient do
      link_to nil
      maintainer nil
    end

    sequence(:name) { |n| "project_#{n}" }
    title { Faker::Book.title }

    after(:create) do |project, evaluator|
      if evaluator.link_to
        LinkedProject.create(project: project, linked_db_project: evaluator.link_to)
      end

      if evaluator.maintainer
        maintainers = [*evaluator.maintainer]
        maintainers.each do |maintainer|
          if maintainer.is_a? User
            create(:relationship_project_user, project: project, user: maintainer)
          elsif maintainer.is_a? Group
            create(:relationship_project_group, project: project, group: maintainer)
          end
        end
      end

      project.write_to_backend
    end

    # remote projects validate additional the description and remoteurl
    factory :remote_project do
      description { Faker::Lorem.sentence }
      remoteurl { Faker::Internet.url }
    end

    factory :project_with_package do
      transient do
        package_name nil
        create_patchinfo false
      end

      after(:create) do |project, evaluator|
        new_package = create(:package, { project: project, name: evaluator.package_name }.compact)
        project.packages << new_package
        if evaluator.create_patchinfo
          Patchinfo.new.create_patchinfo(project.name, new_package.name, comment: 'Fake comment', force: true)
        end
      end
    end

    factory :project_with_packages do
      transient do
        package_name nil
        package_title nil
        package_description nil
        package_count 2
        create_patchinfo false
      end

      after(:create) do |project, evaluator|
        evaluator.package_count.times do |index|
          package_title = nil
          if evaluator.package_title
            package_title = "#{evaluator.package_title}_#{index}"
          end

          package_description = nil
          if evaluator.package_description
            package_description = "#{evaluator.package_description}_#{index}"
          end

          package_name = nil
          if evaluator.package_name
            package_name = "#{evaluator.package_name}_#{index}"
          end

          new_package = create(:package, {
            project:     project,
            name:        package_name,
            title:       package_title,
            description: package_description
          }.compact)
          project.packages << new_package
          if evaluator.create_patchinfo
            Patchinfo.new.create_patchinfo(project.name, new_package.name, comment: 'Fake comment', force: true)
          end
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

      factory :project_with_repository do
        after(:create) do |project|
          create(:repository, project: project, architectures: ['i586'])
        end
      end
    end

    factory :maintenance_incident_project do
      kind 'maintenance_incident'

      transient do
        maintenance_project { create(:maintenance_project) }
      end

      before(:create) do |project, evaluator|
        create(:build_flag, project: project, status: 'disable')
        create(:publish_flag, project: project, status: 'disable')

        if evaluator.maintenance_project
          evaluator.maintenance_project.relationships.each do |role|
            project.relationships.create(user: role.user, role: role.role, group: role.group)
          end
        end
      end
    end

    factory :maintenance_project do
      kind 'maintenance'

      transient do
        target_project nil
        create_patchinfo false
      end

      after(:create) do |project, evaluator|
        create(:maintenance_project_attrib, project: project)
        if evaluator.target_project
          create(:maintained_project, project: evaluator.target_project, maintenance_project: project)
          CONFIG['global_write_through'] ? project.store : project.save!
        end
        if evaluator.create_patchinfo
          old_user = User.current
          User.current = evaluator.maintainer
          Patchinfo.new.create_patchinfo(project.name, nil, comment: 'Fake comment', force: true)
          User.current = old_user
        end
      end

      factory :maintenance_project_with_packages do
        packages { [create(:package_with_file)] }
      end
    end

    factory :update_project do
      kind 'maintenance_release'

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
  end
end
