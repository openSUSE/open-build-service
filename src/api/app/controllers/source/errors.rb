module Source::Errors
  class IllegalRequest < APIError
    setup 404, 'Illegal request'
  end

  class InvalidProjectNameError < APIError
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

  class RepositoryAccessFailure < APIError
    setup 404
  end

  class ProjectReadAccessFailure < APIError
    setup 404
  end

  class DeleteProjectPubkeyNoPermission < APIError
    setup 403
  end

  class PutFileNoPermission < APIError
    setup 403
  end

  class WrongRouteForAttribute < APIError; end

  class WrongRouteForStagingWorkflow < APIError
    setup 403, 'Staging workflows can not be changed through the API'
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

  class ScmsyncReadOnly < APIError
    setup 403
  end
end
