class Token
  class RebuildPolicy < ApplicationPolicy
    def initialize(_user, record)
      super(record.user, record)
    end

    def create?
      PackagePolicy.new(record.user, record.package_from_association_or_params).update?
    end
  end
end
