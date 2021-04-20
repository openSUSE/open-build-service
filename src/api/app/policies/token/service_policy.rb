class Token
  class ServicePolicy < ApplicationPolicy
    def initialize(_user, record)
      super(record.user, record)
    end

    def create?
      return false unless record.user.is_active?

      PackagePolicy.new(record.user, record.package_from_association_or_params).update?
    end
  end
end
