FactoryBot.define do
  factory :repository do
    project
    sequence(:name) { |n| "repository_#{n}" }
    required_checks { [] }

    transient do
      architectures { [] }
      path_element_link { nil }
    end

    after(:create) do |repository, evaluator|
      evaluator.architectures.each do |arch|
        create(:repository_architecture, repository: repository,
                                         architecture: Architecture.find_or_create_by!(name: arch))
      end

      repository.path_elements.create(link: evaluator.path_element_link) if evaluator.path_element_link
    end

    factory :repository_with_release_target do
      release_targets { [create(:release_target)] }
    end
  end
end
