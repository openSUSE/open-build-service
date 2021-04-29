class Token
  class RebuildPolicy < ApplicationPolicy
    def initialize(_user, record)
      super(record.user, record)
    end

    def create?
      return false unless record.user.is_active?

      if record.package_from_association_or_params.try(:project) == record.project_from_association_or_params
        PackagePolicy.new(record.user, record.package_from_association_or_params).update?
      else
        # We authorize a package that comes via a project link
        ProjectPolicy.new(record.user, record.project_from_association_or_params).update?
      end
    end
  end
end
