# This job requests the source diff from the backend, which
# can take a long time depending on the differences. The next time a User views
# this BsRequest it's already available then. Kind of like warming up the diff
# 'cache' on the backend.
#
# triggered by RequestController#request_create when a BsRequest is created

class BsRequestActionWebuiInfosJob < ApplicationJob
  queue_as :quick

  def perform(bs_request_action)
    # We don't need to do an access check as this is only for warming the cache in the backend
    source_package_names = SourcePackageFinder.new(bs_request_action: bs_request_action, skip_access_check: true)
    ForSource.new(
      bs_request_action: bs_request_action,
      source_package_names: source_package_names,
    ).perform
  rescue DiffError, Project::UnknownObjectError, Package::UnknownObjectError
    # pass
  end
end
