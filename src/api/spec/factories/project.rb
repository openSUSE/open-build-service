FactoryGirl.define do
  factory :project do
    sequence(:name) { |n| "project_#{n}" }
    title { Faker::Book.title }

    after(:create) do |project|
      # NOTE: Enable global write through when writing new VCR cassetes.
      # ensure the backend knows the project
      if CONFIG['global_write_through']
        Suse::Backend.put("/source/#{CGI.escape(project.name)}/_meta", project.to_axml)
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
    end

    factory :maintenance_incident_project do
      kind 'maintenance_incident'
    end

    factory :maintenance_project do
      kind 'maintenance'

      after(:create) do |project|
        create(:attrib, project_id: project.id, attrib_type: AttribType.find_by_namespace_and_name!('OBS', 'MaintenanceProject'))
      end
    end
  end
end
