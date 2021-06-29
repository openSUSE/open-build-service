module Users
  class PatchinfosPolicy < ApplicationPolicy
    def initialize(user, record, opts = {})
      super(user, record, opts.merge(ensure_logged_in: true))
    end

    def index?
      true
    end
  end
end
