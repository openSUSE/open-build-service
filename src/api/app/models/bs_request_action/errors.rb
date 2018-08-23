module BsRequestAction::Errors
  extend ActiveSupport::Concern

  # a diff error can have many reasons, but most likely something within us
  class DiffError < APIError; setup 404; end
  class RemoteSource < APIError; end
  class RemoteTarget < APIError; end
  class InvalidReleaseTarget < APIError; end
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
  class UnknownTargetProject < APIError; end
  class UnknownTargetPackage < APIError; end
  class WrongLinkedPackageSource < APIError; end
  class MissingPatchinfo < APIError; end
  class VersionReleaseDiffers < APIError; end
  class LackingReleaseMaintainership < APIError; setup 'lacking_maintainership', 403; end
  class RepositoryWithoutReleaseTarget < APIError; setup 'repository_without_releasetarget'; end
  class RepositoryWithoutArchitecture < APIError; setup 'repository_without_architecture'; end
  class ArchitectureOrderMissmatch < APIError; setup 'architecture_order_missmatch'; end
  class OpenReleaseRequests < APIError; setup 'open_release_requests'; end
end
