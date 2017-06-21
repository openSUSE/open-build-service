FactoryGirl.define do
  factory :kiwi_repository, class: Kiwi::Repository do
    association :image, factory: :kiwi_image

    source_path 'http://example.com/'
    order 1
    repo_type { Kiwi::Repository::REPO_TYPES.first }
    replaceable false

    factory :kiwi_repository_with_package do
      after(:create) do |repository|
        repository.image.package = create(:package)
        repository.image.save
      end
    end
  end
end
