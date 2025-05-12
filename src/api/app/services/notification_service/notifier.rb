module NotificationService
  class Notifier
    EVENTS_TO_NOTIFY = ['Event::BuildFail',
                        'Event::RequestStatechange',
                        'Event::RequestCreate',
                        'Event::ReviewWanted',
                        'Event::CommentForProject',
                        'Event::CommentForPackage',
                        'Event::CommentForRequest',
                        'Event::RelationshipCreate',
                        'Event::RelationshipDelete',
                        'Event::ReportForProject',
                        'Event::ReportForPackage',
                        'Event::ReportForComment',
                        'Event::ReportForUser',
                        'Event::ReportForRequest',
                        'Event::ClearedDecision',
                        'Event::FavoredDecision',
                        'Event::WorkflowRunFail',
                        'Event::AppealCreated',
                        'Event::AddedUserToGroup',
                        'Event::RemovedUserFromGroup',
                        'Event::AssignmentCreate',
                        'Event::AssignmentDelete'].freeze
    CHANNELS = %i[web rss].freeze
    ALLOWED_NOTIFIABLE_TYPES = {
      'BsRequest' => ::BsRequest,
      'Comment' => ::Comment,
      'Project' => ::Project,
      'Package' => ::Package,
      'Report' => ::Report,
      'Decision' => ::Decision,
      'WorkflowRun' => ::WorkflowRun,
      'Appeal' => ::Appeal,
      'Group' => ::Group
    }.freeze
    ALLOWED_CHANNELS = {
      web: NotificationService::WebChannel,
      rss: NotificationService::RSSChannel
    }.freeze
    REJECTED_FOR_RSS = ['Event::ReportForProject',
                        'Event::ReportForPackage',
                        'Event::ReportForComment',
                        'Event::ReportForUser',
                        'Event::ReportForRequest',
                        'Event::ClearedDecision',
                        'Event::FavoredDecision',
                        'Event::WorkflowRunFail',
                        'Event::AddedUserToGroup',
                        'Event::RemovedUserFromGroup'].freeze

    def initialize(event)
      @event = event
    end

    def call
      return unless @event.eventtype.in?(EVENTS_TO_NOTIFY)

      CHANNELS.each do |channel|
        next if channel == :rss && @event.eventtype.in?(REJECTED_FOR_RSS)

        @event.subscriptions(channel).each do |subscription|
          create_notification(subscription, channel)
        end
      end
    end

    private

    def create_notification(subscription, channel)
      return if subscription.subscriber.nil?
      return if subscription.subscriber.away?
      return if channel == :rss && subscription.subscriber.rss_secret.blank?
      return unless notifiable_exists?
      return if skip_report_notification?(event: @event, subscriber: subscription.subscriber)

      ALLOWED_CHANNELS[channel].new(subscription, @event).call
    end

    def skip_report_notification?(event:, subscriber:)
      return false unless event.is_a?(Event::Report)

      !ReportPolicy.new(subscriber, Report).notify?
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
