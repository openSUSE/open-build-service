FactoryBot.define do
  factory :status_repository_publish, class: Status::RepositoryPublish do
    build_id { Faker::Lorem.characters(12) }
    repository
  end
end
