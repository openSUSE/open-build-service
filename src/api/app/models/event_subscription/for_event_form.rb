class EventSubscription
  class ForEventForm
    # TODO: Remove this line on a following step of the renaming.
    OBSOLETE_RECEIVER_ROLES = %i[watcher source_watcher target_watcher].freeze

    attr_reader :event_class, :subscriber, :roles

    def initialize(event, subscriber)
      @subscriber = subscriber
      @event_class = event
      @roles = []
    end

    def call
      @roles = event_class.receiver_roles
                          .reject { |role| OBSOLETE_RECEIVER_ROLES.include?(role) } # TODO: Remove this line on a following step of the renaming.
                          .map { |role| EventSubscription::ForRoleForm.new(role, event_class, subscriber).call }
      self
    end
  end
end
