FactoryGirl.define do
  factory :project do
    sequence(:name){|n| "#{Faker::Internet.domain_word}#{n}" }
    title { Faker::Book.title }

    # remote projects validate additional the description and remoteurl
    factory :remote_project do
      description { Faker::Lorem.sentence }
      remoteurl { Faker::Internet.url }
    end

    factory :project_with_package do
      after(:create) do |project|
        project.packages << create(:package, project_id: project.id)
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
  end
end
