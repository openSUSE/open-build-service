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
    source_package_names = BsRequestAction::Differ::SourcePackageFinder.new(
      bs_request_action: bs_request_action,
      options: { skip_access_check: true }
    ).all
    for_superseded_requests(bs_request_action, source_package_names)
    for_target_package(bs_request_action, source_package_names)
  end

  private

  def silent
    yield
  rescue BsRequestAction::Errors::DiffError, Project::UnknownObjectError, Package::UnknownObjectError
    # as this is only for caching, we can ignore these errors
  end

  def for_target_package(bs_request_action, source_package_names)
    silent do
      BsRequestAction::Differ::ForSource.new(
        bs_request_action: bs_request_action,
        source_package_names: source_package_names
      ).perform
    end
  end

  def for_superseded_requests(bs_request_action, source_package_names)
    superseded_requests = bs_request_action.bs_request.superseding
    superseded_requests.each do |superseded_request|
      for_a_superseded_request(superseded_request, bs_request_action, source_package_names)
    end
  end

  def for_a_superseded_request(superseded_request, bs_request_action, source_package_names)
    silent do
      superseded_bs_request_action = bs_request_action.find_action_with_same_target(superseded_request)
      BsRequestAction::Differ::ForSource.new(
        bs_request_action: bs_request_action,
        source_package_names: source_package_names,
        options: { superseded_bs_request_action: superseded_bs_request_action }
      ).perform
    end
  end
end
