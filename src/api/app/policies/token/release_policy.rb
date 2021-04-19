class Token
  class ReleasePolicy < ApplicationPolicy
    def initialize(_user, record)
      super(record.user, record)
    end

    def create?; end
  end
end
