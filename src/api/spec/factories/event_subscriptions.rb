FactoryBot.define do
  factory :event_subscription do
    enabled { true }

    factory :event_subscription_comment_for_project do
      eventtype { 'Event::CommentForProject' }
      receiver_role { 'commenter' }
      channel { :instant_email }
      user
      group { nil }
    end

    factory :event_subscription_comment_for_project_without_subscriber do
      eventtype { 'Event::CommentForProject' }
      receiver_role { 'commenter' }
      channel { :instant_email }
    end

    factory :event_subscription_comment_for_package do
      eventtype { 'Event::CommentForPackage' }
      receiver_role { 'commenter' }
      channel { :instant_email }
      user
      group { nil }
    end

    factory :event_subscription_comment_for_request do
      eventtype { 'Event::CommentForRequest' }
      receiver_role { 'commenter' }
      channel { :instant_email }
      user
      group { nil }
    end

    factory :event_subscription_comment_for_request_without_subscriber do
      eventtype { 'Event::CommentForRequest' }
      receiver_role { 'commenter' }
      channel { :instant_email }
    end

    factory :event_subscription_request_created do
      eventtype { 'Event::RequestCreate' }
      receiver_role { 'target_maintainer' }
      channel { :instant_email }
      user
      group { nil }
    end

    factory :event_subscription_request_statechange do
      eventtype { 'Event::RequestStatechange' }
      receiver_role { 'target_maintainer' }
      channel { :instant_email }
      user
      group { nil }
    end

    factory :event_subscription_review_wanted do
      eventtype { 'Event::ReviewWanted' }
      receiver_role { 'reviewer' }
      channel { :instant_email }
      user
      group { nil }
    end

    factory :event_subscription_relationship_create do
      eventtype { 'Event::RelationshipCreate' }
      receiver_role { 'any_role' }
      channel { :instant_email }
      user
      group { nil }
    end

    factory :event_subscription_relationship_delete do
      eventtype { 'Event::RelationshipDelete' }
      receiver_role { 'any_role' }
      channel { :instant_email }
      user
      group { nil }
    end

    # TODO: Remove `Event::CreateReport` after all existing records are migrated to the new STI classes
    factory :event_subscription_create_report do
      eventtype { 'Event::CreateReport' }
      receiver_role { 'moderator' }
      channel { :instant_email }
      user
      group { nil }
    end

    factory :event_subscription_report_for_project do
      eventtype { 'Event::ReportForProject' }
      receiver_role { 'moderator' }
      channel { :instant_email }
      user
      group { nil }
    end

    factory :event_subscription_report_for_package do
      eventtype { 'Event::ReportForPackage' }
      receiver_role { 'moderator' }
      channel { :instant_email }
      user
      group { nil }
    end

    factory :event_subscription_report_for_comment do
      eventtype { 'Event::ReportForComment' }
      receiver_role { 'moderator' }
      channel { :instant_email }
      user
      group { nil }
    end

    factory :event_subscription_report_for_user do
      eventtype { 'Event::ReportForUser' }
      receiver_role { 'moderator' }
      channel { :instant_email }
      user
      group { nil }
    end

    factory :event_subscription_cleared_decision do
      eventtype { 'Event::ClearedDecision' }
      receiver_role { 'reporter' }
      channel { :instant_email }
      user
      group { nil }
    end

    factory :event_subscription_favored_decision do
      eventtype { 'Event::FavoredDecision' }
      receiver_role { 'reporter' } # or 'offender'
      channel { :instant_email }
      user
      group { nil }
    end

    factory :event_subscription_appeal_created do
      eventtype { 'Event::AppealCreated' }
      receiver_role { 'moderator' }
      channel { :instant_email }
      user
      group { nil }
    end

    factory :event_subscription_workflow_run_fail do
      eventtype { 'Event::WorkflowRunFail' }
      receiver_role { 'token_executor' }
      channel { :instant_email }
      user
      group { nil }
    end
  end
end
