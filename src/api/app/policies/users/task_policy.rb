module Users
  class TaskPolicy < ApplicationPolicy
    def initialize(user, record, opts = {})
      super(user, record, { ensure_logged_in: true }.merge(opts))
    end

    def index?
      true
    end
  end
end
