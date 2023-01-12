module Users
  class PatchinfosPolicy < ApplicationPolicy
    def initialize(user, record, opts = {})
      super(user, record, { ensure_logged_in: true }.merge(opts))
    end

    def index?
      true
    end
  end
end
