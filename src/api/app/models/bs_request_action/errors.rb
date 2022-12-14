module BsRequestAction::Errors
  # a diff error can have many reasons, but most likely something within us
  class DiffError < APIError; setup 404; end

  class RemoteSource < APIError
    setup 'remote_source', 400, 'No support for auto expanding from remote instance. You need to submit a full specified request in that case.'
  end

  class RemoteTarget < APIError; end

  class InvalidReleaseTarget < APIError
    setup 'invalid_release_target', 400, 'Can not release to a maintenance incident project'
  end

  class MultipleReleaseTargets < APIError; setup 'Multiple release target projects are not supported'; end

  class LackingMaintainership < APIError
    setup 'lacking_maintainership', 403, 'Creating a submit request action with options requires maintainership in source package'
  end

  class NoMaintenanceProject < APIError; end

  class UnknownAttribute < APIError; setup 404; end

  class IncidentHasNoMaintenanceProject < APIError; end

  class NotSupported < APIError; end

  class SubmitRequestRejected < APIError; end

  class RequestRejected < APIError; setup 403; end

  class UnknownProject < APIError; setup 404; end

  class UnknownRole < APIError; setup 404; end

  class IllegalRequest < APIError; end

  class BuildNotFinished < APIError; end

  class UnknownTargetProject < APIError
    setup 'unknown_target_project', 400
  end

  class UnknownTargetPackage < APIError; end

  class WrongLinkedPackageSource < APIError; end

  class MissingPatchinfo < APIError
    setup 'missing_patchinfo', 400, 'maintenance release request without patchinfo would release no binaries'
  end

  class VersionReleaseDiffers < APIError; end

  class LackingReleaseMaintainership < APIError; setup 'lacking_maintainership', 403; end

  class RepositoryWithoutReleaseTarget < APIError; setup 'repository_without_releasetarget'; end

  class RepositoryWithoutArchitecture < APIError; setup 'repository_without_architecture'; end

  class ArchitectureOrderMissmatch < APIError; setup 'architecture_order_missmatch'; end

  class OpenReleaseRequests < APIError; setup 'open_release_requests'; end
end
