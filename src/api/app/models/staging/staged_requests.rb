class Staging::StagedRequests
  include ActiveModel::Model
  attr_accessor :request_numbers, :staging_project, :staging_workflow, :user_login

  def create
    add_request_not_found_errors
    requests.each do |request|
      bs_request_action = request.bs_request_actions.first
      if bs_request_action.is_submit?
        branch_package(bs_request_action)
      elsif bs_request_action.is_delete?
        # TODO: implement delete requests
      end
    end

    result.each { |request| add_review_for_staged_request(request) }

    self
  end

  def destroy
    requests = staging_workflow.target_of_bs_requests.where(number: request_numbers).joins(:bs_request_actions)
    requests.each do |request|
      staging_project = request.staging_project
      next unless unstageable?(request, staging_project)

      remove_packages(request, staging_project)

      ProjectLogEntry.create!(
        project: staging_project,
        user_name: user_login,
        bs_request: request,
        event_type: :unstaged_request,
        datetime: Time.now,
        package_name: request.first_target_package
      )

      add_review_for_unstaged_request(request, staging_project) if request.state.in?([:new, :review])
      staging_project.staged_requests.delete(request)
    end

    missing_packages
    missing_requests(requests)

    self
  end

  def errors
    @errors ||= []
  end

  def valid?
    errors.empty?
  end

  private

  def result
    @result ||= []
  end

  def not_removed_packages
    @not_removed_packages ||= {}
  end

  def add_request_not_found_errors
    not_found_requests.each do |request_number|
      errors << if BsRequest.exists?(number: request_number)
                  "Request #{request_number} not found in Staging for project #{request_target_project}"
                else
                  "Request #{request_number} doesn't exist"
                end
    end
  end

  def request_target_project
    staging_workflow.project
  end

  def not_found_requests
    request_numbers - requests.pluck(:number).map(&:to_s)
  end

  def requests
    staging_workflow.unassigned_requests.where(number: request_numbers)
  end

  def branch_package(bs_request_action)
    request = bs_request_action.bs_request
    BranchPackage.new(
      target_project: staging_project.name,
      target_package: bs_request_action.target_package,
      project: bs_request_action.source_project,
      package: bs_request_action.source_package,
      extend_package_names: false
    ).branch
    ProjectLogEntry.create!(
      project: staging_project,
      user_name: user_login,
      bs_request: request,
      event_type: :staged_request,
      datetime: Time.now,
      package_name: bs_request_action.target_package
    )
    staging_project.staged_requests << request
    result << request
  rescue BranchPackage::DoubleBranchPackageError
    # we leave the package there and do not report as success
    # because packages might differ
    errors << "Request '#{request.number}' already branched into '#{staging_project.name}'"
  rescue APIError, Backend::Error => e
    errors << "Request '#{request.number}' branching failed: '#{e.message}'"
    Airbrake.notify(e, bs_request: request.number)
  end

  def add_review_for_staged_request(request)
    request.addreview(by_project: staging_project.name, comment: "Being evaluated by staging project \"#{staging_project}\"")
    request.change_review_state('accepted', by_group: staging_workflow.managers_group.title, comment: "Picked \"#{staging_project}\"")
  end

  def add_review_for_unstaged_request(request, staging_project)
    request.addreview(by_group: staging_workflow.managers_group.title, comment: "Being evaluated by group \"#{staging_workflow.managers_group}\"")
    request.change_review_state('accepted', by_project: staging_project.name, comment: "Moved back to project \"#{staging_workflow.project}\"")
  end

  def remove_packages(request, staging_project)
    package_names = request.bs_request_actions.pluck(:target_package)
    staging_project_packages = staging_project.packages.where(name: package_names)
    staging_project_packages.each do |package|
      next if package.destroy

      not_removed_packages[staging_project.name] ||= []
      not_removed_packages[staging_project.name] << package
    end
  end

  def unstageable?(request, staging_project)
    return true if staging_project && staging_project.overall_state != :accepting
    errors << if staging_project.nil?
                "Request '#{request.number}' is not staged"
              else
                "Can't change staged requests '#{request.number}': Project '#{staging_project}' is being accepted."
              end
    return false
  end

  def missing_packages
    return if not_removed_packages.empty?

    message = not_removed_packages.map do |staging_project, packages|
      reasons = packages.map { |package| "'#{package}' \"#{package.errors.full_messages.to_sentence}\"" }
      "from #{staging_project}: #{reasons.to_sentence}"
    end
    errors << "The next packages couldn't be removed #{message.to_sentence}"
  end

  def missing_requests(requests)
    not_unassigned_requests = request_numbers - requests.pluck(:number).map(&:to_s)
    return if not_unassigned_requests.empty?

    requests_found = BsRequest.where(number: not_unassigned_requests).pluck(:number).map(&:to_s)
    requests_not_found = not_unassigned_requests - requests_found

    errors << "Requests with number: #{requests_found.to_sentence} don't belong to Staging: #{staging_workflow.project}" if requests_found.present?
    errors << "Requests with number: #{requests_not_found.to_sentence} don't exist" if requests_not_found.present?
  end
end
