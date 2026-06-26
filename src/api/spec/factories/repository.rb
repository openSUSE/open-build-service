FactoryBot.define do
  factory :repository do
    project
    sequence(:name) { |n| "repository_#{n}" }
    required_checks { [] }

    transient do
      architectures { [] }
    end

    after(:create) do |repository, evaluator|
      evaluator.architectures.each do |arch|
        create(:repository_architecture, repository: repository,
                                         architecture: Architecture.find_or_create_by!(name: arch))
      end
    end

    factory :repository_with_release_target do
      release_targets { create_list(:release_target, 1) }
    end
  end
end
