FactoryBot.define do
  factory :linked_project do
    sequence(:position) { |n| n }
    project

    # linked_db_project: belongs_to association, used to store the local project

    # linked_remote_project_name: string field, used to store the remote project
  end
end
