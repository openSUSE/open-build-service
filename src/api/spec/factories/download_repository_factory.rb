FactoryGirl.define do
  factory :download_repository do
    arch "x86_64"
    url "http://suse.com"
    repotype "rpmmd"
    repository

    before(:create) do |download_repository|
      RepositoryArchitecture.first_or_create!(
        repository:   download_repository.repository,
        architecture: Architecture.find_by_name("x86_64")
      )
    end
  end
end
