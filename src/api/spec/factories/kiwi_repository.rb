FactoryBot.define do
  factory :kiwi_repository, class: Kiwi::Repository do
    association :image, factory: :kiwi_image

    source_path { 'http://example.com/' }
    order { 1 }
    repo_type { Kiwi::Repository::REPO_TYPES.first }
    replaceable { false }
  end
end
