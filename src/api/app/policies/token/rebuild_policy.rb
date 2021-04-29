class Token
  class RebuildPolicy < ApplicationPolicy
    def initialize(_user, record)
      super(record.user, record)
    end

    def create?
      return false unless record.user.is_active?

      return PackagePolicy.new(record.user, record.object_to_authorize).update? if record.object_to_authorize.is_a?(Package)
      return ProjectPolicy.new(record.user, record.object_to_authorize).update? if record.object_to_authorize.is_a?(Project)
    end
  end
end
