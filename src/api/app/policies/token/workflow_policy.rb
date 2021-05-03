class Token
  class WorkflowPolicy < ApplicationPolicy
    def initialize(_user, record)
      super(record.user, record)
    end

    def create?
      record.user.is_active?
    end
  end
end
