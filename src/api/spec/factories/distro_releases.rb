FactoryBot.define do
  factory :distro_release do
    sequence(:name) { |n| "Release #{n}" }
    description { Faker::Lorem.sentence }
    url { Faker::Internet.url }
    distro

    transient do
      architectures { [] }
      repositories { [] }
    end

    after(:create) do |distro_release, evaluator|
      evaluator.repositories.each do |repo|
        evaluator.architectures.each do |arch|
          repo_arch = RepositoryArchitecture.find_or_create_by(repository: repo, architecture: arch)
          DistroReleaseRepositoryArchitecture.find_or_create_by(distro_release: distro_release, repository_architecture: repo_arch)
        end
      end
    end
  end
end
