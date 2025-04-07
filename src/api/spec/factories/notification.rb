FactoryBot.define do
  # Notification-wide defined traits so we can use them in whatever factory we want
  trait :rss_notification do
    rss { true }
  end

  trait :web_notification do
    web { true }
  end

  factory :notification do
    event_type { 'Event::RequestStatechange' }
    event_payload { { fake: 'payload' } }
    subscription_receiver_role { 'owner' }
    title { Faker::Lorem.sentence }
    delivered { false }

    transient do
      originator { nil } # User login
      recipient_group { nil } # Group title
      role { nil } # Role title
    end

    after(:build) do |notification, evaluator|
      notification.event_payload['who'] ||= evaluator.originator unless evaluator.originator.nil?
      notification.event_payload['group'] ||= evaluator.recipient_group unless evaluator.recipient_group.nil?
      notification.event_payload['role'] ||= evaluator.role unless evaluator.role.nil?
      notification.event_payload['project'] ||= notification.notifiable.to_s if notification.notifiable.is_a?(Project)
    end

    trait :stale do
      created_at { 13.months.ago }
    end

    factory :notification_for_request, class: 'NotificationBsRequest' do
      trait :request_state_change do
        event_type { 'Event::RequestStatechange' }
        notifiable factory: [:bs_request_with_submit_action]
        bs_request_oldstate { :new }
      end

      trait :request_created do
        event_type { 'Event::RequestCreate' }
        notifiable factory: [:bs_request_with_submit_action]
      end

      trait :review_wanted do
        event_type { 'Event::ReviewWanted' }
        notifiable factory: [:bs_request_with_submit_action]
      end
    end

    factory :notification_for_comment, class: 'NotificationComment' do
      trait :comment_for_project do
        event_type { 'Event::CommentForProject' }
        notifiable factory: [:comment_project]
      end

      trait :comment_for_package do
        event_type { 'Event::CommentForPackage' }
        notifiable factory: [:comment_package]
      end

      trait :comment_for_request do
        event_type { 'Event::CommentForRequest' }
        notifiable factory: [:comment_request]
      end
    end

    factory :notification_for_project, class: 'NotificationProject' do
      trait :relationship_create_for_project do
        event_type { 'Event::RelationshipCreate' }
        notifiable factory: [:project]
      end

      trait :relationship_delete_for_project do
        event_type { 'Event::RelationshipDelete' }
        notifiable factory: [:project]
      end
    end

    factory :notification_for_package, class: 'NotificationPackage' do
      trait :relationship_create_for_package do
        event_type { 'Event::RelationshipCreate' }
        notifiable factory: [:package]
      end

      trait :relationship_delete_for_package do
        event_type { 'Event::RelationshipDelete' }
        notifiable factory: [:package]
      end

      trait :build_failure do
        event_type { 'Event::BuildFail' }
        notifiable factory: [:package]
      end
    end

    factory :notification_for_report, class: 'NotificationReport' do
      trait :report_for_user do
        event_type { 'Event::ReportForUser' }
        notifiable factory: [:report]

        transient do
          reason { nil }
        end

        after(:build) do |notification, evaluator|
          notification.event_payload['reportable_type'] ||= notification.notifiable.reportable.class.to_s
          notification.event_payload['reason'] ||= evaluator.reason
        end
      end

      trait :cleared_decision do
        event_type { 'Event::ClearedDecision' }
        notifiable { association(:decision_cleared) }

        after(:build) do |notification|
          notification.event_payload['reportable_type'] ||= notification.notifiable.reports.first.reportable.class.to_s
        end
      end

      trait :favored_decision do
        event_type { 'Event::FavoredDecision' }
        notifiable { association(:decision_favored) }

        after(:build) do |notification|
          notification.event_payload['reportable_type'] ||= notification.notifiable.reports.first.reportable.class.to_s
        end
      end

      trait :appeal do
        event_type { 'Event::AppealCreated' }
        notifiable { association(:appeal) }
      end
    end
  end
end
