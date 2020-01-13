FactoryBot.define do
  factory :project_log_entry do
    project
    datetime { Time.zone.today }
    event_type { 'commit' }

    factory :project_log_entry_comment_for_project do
      event_type { 'comment_for_project' }
      sequence(:user_name) { |n| "user_#{n}" }
    end
    factory :project_log_entry_comment_for_package do
      event_type { 'comment_for_package' }
      sequence(:user_name) { |n| "user_#{n}" }
      sequence(:package_name) { |n| "package_#{n}" }
      additional_info { '{ commenters: [97], comment_body: \'A comment\'}' }
    end

    factory :project_log_entry_staging_project_created do
      event_type { 'staging_project_created' }
      sequence(:user_name) { |n| "user_#{n}" }
    end

    factory :project_log_entry_staged_request do
      event_type { 'staged_request' }
      sequence(:user_name) { |n| "user_#{n}" }
      sequence(:package_name) { |n| "package_#{n}" }
      bs_request
    end

    factory :project_log_entry_unstaged_request do
      event_type { 'unstaged_request' }
      sequence(:user_name) { |n| "user_#{n}" }
      sequence(:package_name) { |n| "package_#{n}" }
      bs_request
    end
  end
end
