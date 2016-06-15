FactoryGirl.define do
  factory :repository do
    project
    name { Faker::Internet.domain_word }

    transient do
      architectures []
    end

    after(:create) do |repository, evaluator|
      evaluator.architectures.each do |arch|
        create(:repository_architecture, {
          repository:   repository,
          architecture: Architecture.find_or_create_by!(name: arch)
        })
      end
    end
  end
end
