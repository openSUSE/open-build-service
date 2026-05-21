FactoryBot.define do
  factory :download_repository do
    arch { 'x86_64' }
    url { 'http://suse.com' }
    repotype { 'rpmmd' }
    repository { association :repository, architectures: [arch] }

    before(:create) do |download_repository|
      RepositoryArchitecture.find_or_create_by!(
        repository: download_repository.repository,
        architecture: Architecture.find_by_name(download_repository.arch)
      )
    end
  end
end
