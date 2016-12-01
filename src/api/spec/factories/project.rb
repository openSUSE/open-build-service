FactoryGirl.define do
  factory :project do
    sequence(:name) { |n| "project_#{n}" }
    title { Faker::Book.title }

    after(:create) do |project|
      # NOTE: Enable global write through when writing new VCR cassetes.
      # ensure the backend knows the project
      if CONFIG['global_write_through']
        Suse::Backend.put("/source/#{CGI.escape(project.name)}/_meta", project.to_axml)
        Suse::Backend.put("/source/#{CGI.escape(project.name)}/_config", Faker::Lorem.paragraph)
      end
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
        maintainer nil
      end

      after(:create) do |project, evaluator|
        new_package = create(:package, { project: project, name: evaluator.package_name }.compact)
        project.packages << new_package
        if evaluator.create_patchinfo
          create(:relationship_project_user, project: project, user: evaluator.maintainer)
          Patchinfo.new.create_patchinfo(project.name, new_package.name, comment: 'Fake comment', force: true)
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
        create(:build_flag, project: project, status: "disable")
        create(:publish_flag, project: project, status: "disable")

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
      end

      after(:create) do |project, evaluator|
        create(:maintainance_project_attrib, project: project)
        create(:maintained_project, project: evaluator.target_project, maintenance_project: project) if evaluator.target_project
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
          update_project.store
          new_repository = create(:repository, project: update_project, architectures: ['i586'])
          create(:path_element, repository: new_repository, link: evaluator.target_project.repositories.first)
        end
      end
    end
  end
end
