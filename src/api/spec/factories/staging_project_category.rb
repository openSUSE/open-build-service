FactoryBot.define do
  factory :staging_project_category, class: 'Staging::ProjectCategory' do
    staging_workflow
    title { Faker::Lorem.word }
  end
end
