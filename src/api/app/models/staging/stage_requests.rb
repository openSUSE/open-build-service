class Staging::StageRequests
  include ActiveModel::Model
  attr_accessor :requests, :staging_project_name

  def perform
    self.result = []
    requests.each do |request|
      bs_request_action = request.bs_request_actions.first
      if bs_request_action.is_submit?
        branch_package(bs_request_action)
      elsif bs_request_action.is_delete?
        # TODO: implement delete requests
      end
      result
    end
  end

  private

  attr_accessor :result

  def branch_package(bs_request_action)
    request = bs_request_action.bs_request
    BranchPackage.new(
      target_project: staging_project_name,
      target_package: bs_request_action.target_package,
      project: bs_request_action.source_project,
      package: bs_request_action.source_package,
      extend_package_names: false
    ).branch
    result << request
  rescue BranchPackage::DoubleBranchPackageError
    # we leave the package there and do not report as success
    # because packages might differ
  rescue APIError, Backend::Error => e
    Airbrake.notify(e, bs_request: request.number)
  end
end
