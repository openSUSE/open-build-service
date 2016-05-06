FactoryGirl.define do
  factory :project do
    sequence(:name) { |n| "#{Faker::Internet.domain_word}#{n}" }
    title { Faker::Book.title }

    # remote projects validate additional the description and remoteurl
    factory :remote_project do
      description { Faker::Lorem.sentence }
      remoteurl { Faker::Internet.url }
    end

    factory :project_with_package do
      transient do
        package_name nil
      end

      after(:create) do |project, evaluator|
        new_package = if evaluator.package_name
                        create(:package, project_id: project.id, name: evaluator.package_name)
                      else
                        create(:package, project_id: project.id)
                      end
        project.packages << new_package
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
