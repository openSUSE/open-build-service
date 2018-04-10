# frozen_string_literal: true

FactoryBot.define do
  factory :project_log_entry do
    project
    datetime { Time.zone.today }
    event_type 'commit'

    factory :project_log_entry_comment_for_project do
      event_type 'comment_for_project'
      sequence(:user_name) { |n| "user_#{n}" }
    end
    factory :project_log_entry_comment_for_package do
      event_type 'comment_for_package'
      sequence(:user_name) { |n| "user_#{n}" }
      sequence(:package_name) { |n| "package_#{n}" }
      additional_info '{ commenters: [97], comment_body: \'A comment\'}'
    end
  end
end
