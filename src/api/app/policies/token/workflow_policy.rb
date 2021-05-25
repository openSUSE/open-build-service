class Token
  class WorkflowPolicy < ApplicationPolicy
    def initialize(_user, record)
      super(record.user, record)
    end

    # TODO: remove the second half of the condition when `trigger_workflow` feature is rolled out
    def create?
      record.user.is_active? && Flipper.enabled?(:trigger_workflow, record.user)
    end
  end
end
