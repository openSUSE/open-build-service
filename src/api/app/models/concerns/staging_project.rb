# rubocop:disable Metrics/ModuleLength
module StagingProject
  extend ActiveSupport::Concern

  included do
    has_many :staged_requests, class_name: 'BsRequest', foreign_key: :staging_project_id, dependent: :nullify
    belongs_to :staging_workflow, class_name: 'Staging::Workflow', optional: true

    after_save :update_staging_workflow_on_backend, if: :staging_project?
    after_destroy :update_staging_workflow_on_backend, if: :staging_project?
    before_create :add_managers_group, if: :staging_project?
    before_update :add_managers_group, if: proc { |project| project.staging_workflow_id_changed? && project.staging_workflow_id_was.nil? }

    scope :staging_projects, -> { where.not(staging_workflow: nil) }
  end

  HISTORY_EVENT_TYPES = %i[staging_project_created staged_request unstaged_request].freeze
  FORCEABLE_STATES = %i[building failed testing acceptable].freeze

  def accept
    # Disabling build for all repositories and architectures.
    build_flag = flags.find_or_initialize_by(flag: 'build', repo: nil, architecture_id: nil)
    build_flag.update(status: 'disable')

    # Remove all the build flags enabled by the user.
    flags.where(flag: 'build', status: 'enable').destroy_all

    # Tell the backend
    commit_opts[:login] = User.session!
    store

    # Accept reviews/requests
    staged_requests.each do |staged_request|
      staged_request.change_review_state(:accepted, by_project: name, comment: "Staging Project #{name} got accepted.") if staged_request.reviews.exists?(by_project: name)
      staged_request.change_state(newstate: 'accepted', comment: "Staging Project #{name} got accepted.") unless staged_request.approver
    end

    # Reset history
    project_log_entries.staging_history.delete_all

    true
  end

  def copy(new_project_name)
    transaction do
      new_project = deep_clone(include: [:flags], skip_missing_associations: true)
      new_project.name = new_project_name
      new_project.save!

      repositories.each { |repository| repository.copy_to(new_project) }
      new_project.update_self_referencing_repositories!(self)

      # We can't use deep_clone here because of an exception raised in Relationship#add_group
      relationships.each do |relationship|
        new_project.relationships.find_or_create_by!(relationship.slice(:role_id, :user_id, :group_id))
      end

      new_project.store
      project_config = config.content
      new_project.config.save!({ user: User.session!, comment: "Copying project #{name}" }, project_config) if project_config.present?

      new_project
    end
  end

  # Some staging projects contain repositories that refer to themself. In such
  # cases we create a new self-referencing repository path.
  def update_self_referencing_repositories!(old_project)
    repositories.includes(:path_elements).find_each do |repository|
      repository.path_elements.where(repository_id: old_project.repositories).find_each do |path|
        new_linked_repo = repositories.find_by(name: path.link.name)
        path.update!(repository_id: new_linked_repo.id)

        # Update repository name by replacing project related part with new project name.
        new_link_name = path.link.name.sub(/#{old_project.name.tr(':', '.*')}/, name)
        new_linked_repo.update!(name: new_link_name.tr(':', '_'))
      end
    end
  end

  def classified_requests
    requests = (requests_to_review | staged_requests.includes(:not_accepted_reviews, :bs_request_actions)).map do |request|
      {
        number: request.number,
        state: request.state,
        package: request.first_target_package,
        request_type: request.bs_request_actions.first.type,
        missing_reviews: missing_reviews_for_classified_requests(request, request.not_accepted_reviews)
      }
    end
    requests.sort_by { |request| request_weight(request) }
  end

  def untracked_requests
    @untracked_requests ||= requests_to_review - staged_requests
  end

  # The difference between staged requests and requests to review is that staged requests are assigned to the staging project.
  # The requests to review are requests which are not related to the staging project (unless they are also staged).
  # They simply need a review from the maintainers of the staging project.
  def requests_to_review
    @requests_to_review ||= BsRequest.with_actions_and_reviews.where(state: :review, reviews: { by_project: name, state: :new })
  end

  def building_repositories
    set_buildinfo unless @building_repositories
    @building_repositories
  end

  def broken_packages
    set_buildinfo unless @broken_packages
    @broken_packages
  end

  def missing_reviews_for_classified_requests(request, reviews)
    @missing_reviews_of_st_project ||= []

    reviews.each_with_object([]) do |review, collected|
      next if review.by_project == name

      extracted = extract_missing_reviews(request, review)
      collected << extracted
      @missing_reviews_of_st_project << extracted
      collected
    end
  end

  def missing_reviews
    return @missing_reviews_of_st_project if @missing_reviews_of_st_project

    @missing_reviews_of_st_project = []
    base_query = Review.includes(bs_request: [:bs_request_actions]).where(bs_request_id: staged_requests.select(:id)).where.not(state: :accepted)
    # We skip reviews for the staging project since these reviews are used
    # by the openSUSE release tools _after_ the overall_state switched to
    # 'accepted'.
    base_query.where.not(by_project: name).or(base_query.where(by_project: nil)).find_each do |review|
      @missing_reviews_of_st_project << extract_missing_reviews(review.bs_request, review)
    end
    @missing_reviews_of_st_project
  end

  def overall_state
    @overall_state ||= state
  end

  def assign_managers_group(managers)
    role = Role.find_by_title!('maintainer')
    return if relationships.find_by(group: managers, role: role)

    Relationship.add_group(self, managers, role, nil, true)
  end

  def unassign_managers_group(managers)
    role = Role.find_by_title!('maintainer')
    relationships.find_by(group: managers, role: role).try(:destroy!)
  end

  def staging_project?
    staging_workflow_id.present?
  end

  def create_project_log_entry(user)
    project_log_entry = ProjectLogEntry.find_or_initialize_by(
      project: self,
      user_name: user.login,
      event_type: :staging_project_created
    )

    return unless project_log_entry.new_record?

    project_log_entry.datetime = Time.now
    project_log_entry.save!
  end

  private

  def state
    # FIXME: We should use a better way to check if we are in :accepting state. Could be a state machine or storing the state locally.
    return :accepting if Delayed::Job.where("handler LIKE '%job_class: StagingProjectAcceptJob% project_id: #{id}%'").exists?
    return :empty if staged_requests.blank?
    return :unacceptable if untracked_requests.present? || staged_requests.obsolete.exists?

    bc_state = build_or_check_state
    return bc_state if bc_state
    return :review if missing_reviews.present?

    :acceptable
  end

  def build_or_check_state
    # build_state
    return :building if building_repositories.present?
    return :failed if broken_packages.present?
    # check_state
    return :testing if missing_checks.present? || checks.pending.exists?

    :failed if checks.failed.exists?
  end

  def set_buildinfo
    buildresult = Xmlhash.parse(Backend::Api::BuildResults::Status.failed_results(name))

    @broken_packages = []
    @building_repositories = []

    buildresult.elements('result') do |result|
      building = %w[published unpublished].exclude?(result['state']) || result['dirty'] == 'true'
      add_broken_packages(result)
      add_building_repositories(result) if building
    end

    @broken_packages.reject! { |package| package[:state] == 'unresolvable' } if @building_repositories.present?
  end

  def add_broken_packages(result)
    result.elements('status') do |status|
      code = status.get('code')

      next unless code.in?(%w[broken failed unresolvable])

      @broken_packages << { package: status['package'],
                            project: name,
                            state: code,
                            details: status['details'],
                            repository: result['repository'],
                            arch: result['arch'] }
    end
  end

  def add_building_repositories(result)
    current_repo = result.slice('repository', 'arch', 'code', 'state', 'dirty')
    current_repo[:tobuild] = 0
    current_repo[:final] = 0

    buildresult = Buildresult.find_hashed(project: name, view: 'summary', repository: current_repo['repository'], arch: current_repo['arch'])
    buildresult = buildresult.get('result').get('summary')
    buildresult.elements('statuscount') do |status_count|
      if status_count['code'].in?(%w[excluded broken failed unresolvable succeeded excluded disabled])
        current_repo[:final] += status_count['count'].to_i
      else
        current_repo[:tobuild] += status_count['count'].to_i
      end
    end
    @building_repositories << current_repo
  end

  def update_staging_workflow_on_backend
    staging_workflow.reload.write_to_backend
  end

  def add_managers_group
    assign_managers_group(staging_workflow.managers_group)
  end

  def extract_missing_reviews(request, review)
    # FIXME: this loop (and the inner if) would not be needed
    # if every review only has one valid by_xxx.
    # I'm keeping it to mimic the python implementation.
    # Instead, we could have something like
    # who = review.by_group || review.by_user || review.by_project || review.by_package

    %i[by_group by_user by_package by_project].each_with_object({}) do |review_by, extracted|
      who = review.send(review_by)
      next unless who

      extracted.merge!(id: review.id, request: request.number, state: review.state.to_s, creator: review.creator,
                       package: request.first_target_package, by: who, review_type: review_by.to_s)
      # No need to duplicate reviews
      break extracted
    end
  end

  def request_weight(request)
    weight = if request[:state].in?(BsRequest::OBSOLETE_STATES) # obsolete
               '0'
             elsif request[:missing_reviews].present? # in review
               '1'
             else
               '2' # ready
             end
    [weight, request[:package]]
  end
end
# rubocop:enable Metrics/ModuleLength
