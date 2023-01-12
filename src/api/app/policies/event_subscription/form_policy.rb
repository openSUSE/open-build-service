class EventSubscription
  class FormPolicy < ApplicationPolicy
    def initialize(user, record, opts = {})
      super(user, record, { ensure_logged_in: true }.merge(opts))
    end

    def index?
      user_is_subscriber?
    end

    def update?
      user_is_subscriber?
    end

    private

    def user_is_subscriber?
      return true unless record.subscriber

      user == record.subscriber
    end
  end
end
