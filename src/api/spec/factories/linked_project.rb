FactoryBot.define do
  factory :linked_project do
    sequence(:position) { |n| n }
    project

    trait :local do
      linked_db_project { association :project }
    end

    trait :remote do
      linked_remote_project_name { 'openSUSE.org:home:hennevogel:myfirstproject' }
    end
  end
end
