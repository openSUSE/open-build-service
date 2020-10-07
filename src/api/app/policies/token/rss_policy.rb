class Token
  class RssPolicy < ApplicationPolicy
    def initialize(user, record, opts = {})
      super(user, record, opts.merge(ensure_logged_in: true))
    end

    def create?
      user == record.user
    end
  end
end
