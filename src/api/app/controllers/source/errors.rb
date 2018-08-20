module Source::Errors
  extend ActiveSupport::Concern

  class IllegalRequest < APIError
    setup 404, 'Illegal request'
  end

  class NoPermissionForDeleted < APIError
    setup 403, 'only admins can see deleted projects'
  end

  class NoLocalPackage < APIError; end

  class ChangePackageProtectionLevelError < APIError
    setup 'change_package_protection_level',
          403,
          'admin rights are required to raise the protection level of a package'
  end

  class CmdExecutionNoPermission < APIError
    setup 403
  end

  class DeletePackageNoPermission < APIError
    setup 403
  end

  class ProjectExists < APIError
  end

  class PackageExists < APIError
  end

  class NoMatchingReleaseTarget < APIError
    setup 404, 'No defined or matching release target'
  end

  class ChangeProjectNoPermission < APIError
    setup 403
  end

  class InvalidProjectParameters < APIError
    setup 404
  end

  class ProjectNameMismatch < APIError
  end

  class RepositoryAccessFailure < APIError
    setup 404
  end

  class ProjectReadAccessFailure < APIError
    setup 404
  end

  class PutProjectConfigNoPermission < APIError
    setup 403
  end

  class DeleteProjectPubkeyNoPermission < APIError
    setup 403
  end

  class PutFileNoPermission < APIError
    setup 403
  end

  class WrongRouteForAttribute < APIError; end

  class AttributeNotFound < APIError
    setup 'not_found', 404
  end

  class ModifyProjectNoPermission < APIError
    setup 403
  end

  class RepoDependency < APIError
  end

  class RemoteProjectError < APIError
    setup 'remote_project', 404
  end

  class ProjectCopyNoPermission < APIError
    setup 403
  end

  class NotLocked < APIError; end

  class InvalidFlag < APIError; end
end
