FactoryBot.define do
  factory :release_target do
    repository
    target_repository { association :repository }
    trigger { nil }
  end
end
