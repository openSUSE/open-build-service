module BsRequestActionMaintenanceRelease::Errors
  extend ActiveSupport::Concern
  class LackingReleaseMaintainership < APIError; setup 'lacking_maintainership', 403; end
  class RepositoryWithoutReleaseTarget < APIError; setup 'repository_without_releasetarget'; end
  class RepositoryWithoutArchitecture < APIError; setup 'repository_without_architecture'; end
  class ArchitectureOrderMissmatch < APIError; setup 'architecture_order_missmatch'; end
  class OpenReleaseRequests < APIError; setup 'open_release_requests'; end
end
