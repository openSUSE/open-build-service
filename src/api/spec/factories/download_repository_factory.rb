FactoryBot.define do
  factory :download_repository do
    arch 'x86_64'
    url 'http://suse.com'
    repotype 'rpmmd'
    repository { create(:repository, architectures: [arch]) }

    before(:create) do |download_repository|
      repo_arch = RepositoryArchitecture.find_by(
        repository:   download_repository.repository,
        architecture: Architecture.find_by_name(download_repository.arch)
      )
      # We need to find and create in two separate steps because for finding the position irrelevant but not for creating
      # We set the position explicit in the repository_architecture factory
      unless repo_arch
        create(:repository_architecture, repository: download_repository.repository,
               architecture: Architecture.find_or_create_by!(name: download_repository.arch))
      end
    end
  end
end
