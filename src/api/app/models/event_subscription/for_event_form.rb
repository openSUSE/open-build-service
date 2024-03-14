class EventSubscription
  class ForEventForm
    attr_reader :event_class, :subscriber, :roles

    def initialize(event, subscriber)
      @subscriber = subscriber
      @event_class = event
      @roles = []
    end

    def call
      @roles = event_class.receiver_roles.map do |role|
        EventSubscription::ForRoleForm.new(role, event_class, subscriber).call
      end
      self
    end
  end
end
