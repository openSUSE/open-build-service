module NotificationService
  class Notifier
    # TODO: Remove `Event::CreateReport` after all existing records are migrated to the new STI classes
    EVENTS_TO_NOTIFY = ['Event::BuildFail',
                        'Event::RequestStatechange',
                        'Event::RequestCreate',
                        'Event::ReviewWanted',
                        'Event::CommentForProject',
                        'Event::CommentForPackage',
                        'Event::CommentForRequest',
                        'Event::RelationshipCreate',
                        'Event::RelationshipDelete',
                        'Event::CreateReport',
                        'Event::ReportForProject',
                        'Event::ReportForPackage',
                        'Event::ReportForComment',
                        'Event::ReportForUser',
                        'Event::ReportForRequest',
                        'Event::ClearedDecision',
                        'Event::FavoredDecision',
                        'Event::WorkflowRunFail',
                        'Event::AppealCreated'].freeze
    CHANNELS = %i[web rss].freeze
    ALLOWED_NOTIFIABLE_TYPES = {
      'BsRequest' => ::BsRequest,
      'Comment' => ::Comment,
      'Project' => ::Project,
      'Package' => ::Package,
      'Report' => ::Report,
      'Decision' => ::Decision,
      'WorkflowRun' => ::WorkflowRun,
      'Appeal' => ::Appeal
    }.freeze
    ALLOWED_CHANNELS = {
      web: NotificationService::WebChannel,
      rss: NotificationService::RSSChannel
    }.freeze
    # TODO: Remove `Event::CreateReport` after all existing records are migrated to the new STI classes
    REJECTED_FOR_RSS = ['Event::CreateReport',
                        'Event::ReportForProject',
                        'Event::ReportForPackage',
                        'Event::ReportForComment',
                        'Event::ReportForUser',
                        'Event::ReportForRequest',
                        'Event::ClearedDecision',
                        'Event::FavoredDecision',
                        'Event::WorkflowRunFail'].freeze

    def initialize(event)
      @event = event
    end

    def call
      return unless @event.eventtype.in?(EVENTS_TO_NOTIFY)

      CHANNELS.each do |channel|
        next if channel == :rss && @event.eventtype.in?(REJECTED_FOR_RSS)

        @event.subscriptions(channel).each do |subscription|
          create_notification_per_subscription(subscription, channel)
        end
      end
    end

    private

    def create_notification_per_subscription(subscription, channel)
      return unless create_notification?(subscription.subscriber, channel)

      ALLOWED_CHANNELS[channel].new(subscription, @event).call
    end

    def create_notification?(subscriber, channel)
      return false if subscriber.nil? || subscriber.away? || (channel == :rss && subscriber.rss_secret.blank?)
      return false unless notifiable_exists?
      return false unless create_report_notification?(event: @event, subscriber: subscriber)

      true
    end

    def create_report_notification?(event:, subscriber:)
      # TODO: Remove `Event::CreateReport` after all existing records are migrated to the new STI classes
      return false if (event.is_a?(Event::CreateReport) || event.is_a?(Event::Report)) && !ReportPolicy.new(subscriber, Report).notify?

      true
    end

    def notifiable_exists?
      # We need this check because the notification is created in a delayed job.
      # So the notifiable object could have been removed in the meantime.
      notifiable_type = ALLOWED_NOTIFIABLE_TYPES[@event.parameters_for_notification[:notifiable_type]]
      return false unless notifiable_type

      notifiable_id = @event.parameters_for_notification[:notifiable_id]
      notifiable_type.exists?(notifiable_id)
    end
  end
end
