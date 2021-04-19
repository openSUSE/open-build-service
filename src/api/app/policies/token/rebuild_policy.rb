class Token
  class RebuildPolicy < ApplicationPolicy

    # When are people allowed to rebuild?
    #  - the token's user has access to the package

    def initialize(user, record, opts = {})
      super(user, record)
    end

    def create?
      user.can_modify?(record)
    end
  end
end

# authorization needs to check:
# use_source => ends up checking sourceaccess (package.check_source_access?)
# follow_multibuild => already handled by backend (packages names with '*:' in the name)
# follow_project_links => only rebuild can follow the links, the inherited packages can also be rebuilt

# if not rebuilt then don't follow project links
#  opts = { use_source: false,
#           follow_project_links: true,
#           follow_multibuild: true }
# Package.get_by_project_and_name(params[:project].to_s, params[:package].to_s, opts)

