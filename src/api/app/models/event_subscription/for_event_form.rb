class EventSubscription
  class ForEventForm
    attr_reader :event_class, :subscriber, :roles

    def initialize(event, subscriber)
      @subscriber = subscriber
      @event_class = event
      @roles = []
    end

    def call
      @roles = receiver_roles.map { |role| EventSubscription::ForRoleForm.new(role, event_class, subscriber).call }
      self
    end

    private

    def receiver_roles
      event_class.receiver_roles & EventSubscription.receiver_roles_to_display(@subscriber)
    end
  end
end
