class Staging::StagedRequests
  include ActiveModel::Model
  attr_accessor :request_numbers, :staging_project, :staging_workflow, :user_login

  def create
    add_requests_excluded_errors
    add_request_not_found_errors
    requests.each { |request| stage_request(request) }

    self
  end

  def create!
    create

    return if valid?

    raise Staging::ExcludedRequestNotFound, errors.to_sentence
  end

  def destroy
    requests = staging_workflow.target_of_bs_requests.where(number: request_numbers).joins(:bs_request_actions)
    requests.each do |request|
      staging_project = request.staging_project
      next unless unstageable?(request, staging_project)

      packages_with_errors = remove_packages(staged_packages(staging_project, request))

      not_removed_packages[staging_project.name] = packages_with_errors unless packages_with_errors.empty?

      ProjectLogEntry.create!(
        project: staging_project,
        user_name: user_login,
        bs_request: request,
        event_type: :unstaged_request,
        datetime: Time.now,
        package_name: request.first_target_package
      )

      add_review_for_unstaged_request(request, staging_project) if request.state.in?(%i[new review])
      add_review_for_unstaged_declined_request(request, staging_project) if request.state == :declined
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

  def not_removed_packages
    @not_removed_packages ||= {}
  end

  def add_requests_excluded_errors
    excluded_request_numbers.map do |request_number|
      errors << "Request #{request_number} currently excluded from project #{request_target_project}. Use --remove-exclusion if you want to force this action."
    end
  end

  def add_request_not_found_errors
    not_found_request_numbers.each do |request_number|
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

  def not_found_request_numbers
    request_numbers - requests.pluck(:number)
  end

  def excluded_request_numbers
    staging_workflow.request_exclusions.where(number: @request_numbers).pluck(:number)
  end

  def requests
    staging_workflow.unassigned_requests.where(number: request_numbers)
  end

  def link_package(bs_request_action)
    query_options = { expand: 1, project: bs_request_action.source_project, package: bs_request_action.source_package }
    query_options[:rev] = bs_request_action.source_rev if bs_request_action.source_rev

    backend_package_information = Directory.hashed(query_options)

    source_vrev = backend_package_information['vrev']

    package_rev = backend_package_information['srcmd5']

    link_package = Package.create!(project: staging_project, name: bs_request_action.target_package)

    create_link(staging_project.name, link_package.name, User.session!, project: bs_request_action.source_project,
                                                                        package: bs_request_action.source_package, rev: package_rev,
                                                                        vrev: source_vrev)
  end

  def add_review_for_staged_request(request)
    request.addreview(by_project: staging_project.name, comment: "Being evaluated by staging project \"#{staging_project}\"")
    request.change_review_state('accepted', by_group: staging_workflow.managers_group.title, comment: "Picked \"#{staging_project}\"")
  end

  def add_review_for_unstaged_request(request, staging_project)
    request.addreview(by_group: staging_workflow.managers_group.title, comment: "Being evaluated by group \"#{staging_workflow.managers_group}\"")
    request.change_review_state('accepted', by_project: staging_project.name, comment: "Unstaged from project \"#{staging_project}\"")
  end

  def add_review_for_unstaged_declined_request(request, staging_project)
    request.addreview(by_group: staging_workflow.managers_group.title, comment: "Being evaluated by group \"#{staging_workflow.managers_group}\"", relaxed_state_check: 1)
    request.change_review_state('declined', by_project: staging_project.name, comment: "Unstaged from project \"#{staging_project}\"")
  end

  def remove_packages(staging_project_packages)
    staging_project_packages.collect do |package|
      (package.find_project_local_linking_packages | [package]).collect { |pkg| pkg unless pkg.destroy }
    end.flatten.compact
  end

  def staged_packages(staging_project, request)
    package_names = request.bs_request_actions.pluck(:target_package)
    staging_project.packages.where(name: package_names)
  end

  def unstageable?(request, staging_project)
    return true if staging_project && staging_project.overall_state != :accepting

    errors << if staging_project.nil?
                "Request '#{request.number}' is not staged"
              else
                "Can't change staged requests '#{request.number}': Project '#{staging_project}' is being accepted."
              end
    false
  end

  def missing_packages
    return if not_removed_packages.empty?

    message = not_removed_packages.map do |staging_project, packages|
      reasons = packages.map { |package| "'#{package}' \"#{package.errors.full_messages.to_sentence}\"" }
      "from #{staging_project}: #{reasons.to_sentence}"
    end
    errors << "The following packages couldn't be removed #{message.to_sentence}"
  end

  def missing_requests(requests)
    not_unassigned_requests = request_numbers - requests.pluck(:number)
    return if not_unassigned_requests.empty?

    requests_found = BsRequest.where(number: not_unassigned_requests).pluck(:number)
    requests_not_found = not_unassigned_requests - requests_found

    errors << "Requests with number: #{requests_found.to_sentence} don't belong to Staging: #{staging_workflow.project}" if requests_found.present?
    errors << "Requests with number: #{requests_not_found.to_sentence} don't exist" if requests_not_found.present?
  end

  def create_link(staging_project_name, target_package_name, user, opts = {})
    Backend::Api::Sources::Package.write_link(staging_project_name,
                                              target_package_name,
                                              user,
                                              link_xml(opts))
  end

  def link_xml(opts = {})
    # "<link package=\"foo\" project=\"bar\" rev=\"XXX\" cicount=\"copy\"/>"
    Nokogiri::XML::Builder.new { |x| x.link(opts) }.doc.root.to_s
  end

  def stage_request(request)
    bs_request_action = request.bs_request_actions.first
    if bs_request_action.submit?
      if Package.find_by(project: staging_project, name: bs_request_action.target_package)
        errors << "Can't stage request '#{request.number}': package '#{bs_request_action.target_package}' already exists in '#{staging_project}'."
        return
      end

      link_package(bs_request_action)
    end
    # TODO: implement delete requests
    ProjectLogEntry.create!(
      project: staging_project,
      user_name: user_login,
      bs_request: request,
      event_type: :staged_request,
      datetime: Time.now,
      package_name: bs_request_action.target_package
    )
    staging_project.staged_requests << request
    add_review_for_staged_request(request)
  end
end
