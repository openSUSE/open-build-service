# rubocop:disable Metrics/ModuleLength
module StagingProject
  extend ActiveSupport::Concern

  included do
    has_many :staged_requests, class_name: 'BsRequest', foreign_key: :staging_project_id, dependent: :nullify
    belongs_to :staging_workflow, class_name: 'Staging::Workflow'

    after_save :update_staging_workflow_on_backend, if: :staging_project?
    after_destroy :update_staging_workflow_on_backend, if: :staging_project?
    before_create :add_managers_group, if: :staging_project?
    before_update :add_managers_group, if: proc { |project| project.staging_workflow_id_changed? && project.staging_workflow_id_was.nil? }

    scope :staging_projects, -> { where.not(staging_workflow: nil) }
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
      new_project.config.save!({ user: User.current, comment: "Copying project #{name}" }, project_config) if project_config.present?

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
    requests = (requests_to_review | staged_requests.includes(:reviews)).map do |request|
      {
        number: request.number,
        state: request.state,
        package: request.first_target_package,
        request_type: request.bs_request_actions.first.type,
        missing_reviews: missing_reviews.select { |review| review[:request] == request.number },
        tracked: requests_to_review.include?(request)
      }
    end

    requests.sort_by { |request| request[:package] }
  end

  def untracked_requests
    requests_to_review - staged_requests
  end

  # The difference between staged requests and requests to review is that staged requests are assigned to the staging project.
  # The requests to review are requests which are not related to the staging project (unless they are also staged).
  # They simply need a review from the maintainers of the staging project.
  def requests_to_review
    @requests_to_review ||= BsRequest.with_open_reviews_for(by_project: name)
  end

  def disabled_repositories
    repositories.select { |repository| disabled_for?('build', repository.name, nil) }
  end

  def building_repositories
    set_buildinfo unless @building_repositories
    @building_repositories
  end

  def broken_packages
    set_buildinfo unless @broken_packages
    @broken_packages
  end

  def missing_reviews
    return @missing_reviews if @missing_reviews

    @missing_reviews = []

    Review.includes(:bs_request).where(bs_request_id: staged_requests.select(:id)).where.not(state: :accepted).find_each do |review|
      # We skip reviews for the staging project since these reviews are used
      # by the openSUSE release tools _after_ the overall_state switched to
      # 'accepted'.
      next if review.by_project == name
      extract_missing_reviews(review.bs_request, review)
    end
    @missing_reviews
  end

  def overall_state
    @overall_state ||= state
  end

  def problems
    @problems ||= cache_problems
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

  def accept_staged_requests
    clear_memoized_data
    return unless overall_state == :acceptable

    accepted_packages = []
    staged_requests.each do |staged_request|
      if staged_request.reviews.where(by_project: name).exists?
        staged_request.change_review_state(:accepted, by_project: name, comment: "Staging Project #{name} got accepted.")
      end
      staged_request.change_state(newstate: 'accepted', comment: "Staging Project #{name} got accepted.")
      accepted_packages.concat(staged_request.bs_request_actions.map(&:target_package))
    end

    packages.where(name: accepted_packages).find_each(&:destroy)
    staged_requests.delete_all
  ensure
    clear_memoized_data
  end

  private

  def clear_memoized_data
    @broken_packages = []
    @building_repositories = []
    @requests_to_review = nil
    @problems = nil
    @overall_state = nil
  end

  def cache_problems
    problems = {}
    broken_packages.each do |package|
      problems[package[:package]] ||= {}
      problems[package[:package]][package[:state]] ||= []
      problems[package[:package]][package[:state]] << { repository: package[:repository], arch: package[:arch] }
    end
    problems.sort
  end

  def state
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
    return :building if building_repositories.present? || disabled_repositories.present?
    return :failed if broken_packages.present?
    # check_state
    return :testing if missing_checks.present? || checks.pending.exists?
    :failed if checks.failed.exists?
  end

  def set_buildinfo
    buildresult = Backend::Api::BuildResults::Status.failed_results(name)

    @broken_packages = []
    @building_repositories = []

    buildresult.elements('result') do |result|
      building = ['published', 'unpublished'].exclude?(result['state']) || result['dirty'] == 'true'
      add_broken_packages(result, building)
      add_building_repositories(result) if building
    end

    @broken_packages.reject! { |package| package['state'] == 'unresolvable' } if @building_repositories.present?
  end

  def add_broken_packages(result, building)
    result.elements('status') do |status|
      code = status.get('code')

      if code.in?(['broken', 'failed']) || (code == 'unresolvable' && !building)
        @broken_packages << { package: status['package'],
                              project: name,
                              state: code,
                              details: status['details'],
                              repository: result['repository'],
                              arch: result['arch'] }
      end
    end
  end

  def add_building_repositories(result)
    current_repo = result.slice('repository', 'arch', 'code', 'state', 'dirty')
    current_repo[:tobuild] = 0
    current_repo[:final] = 0

    buildresult = Buildresult.find_hashed(project: name, view: 'summary', repository: current_repo['repository'], arch: current_repo['arch'])
    buildresult = buildresult.get('result').get('summary')
    buildresult.elements('statuscount') do |status_count|
      if status_count['code'].in?(['excluded', 'broken', 'failed', 'unresolvable', 'succeeded', 'excluded', 'disabled'])
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

    [:by_group, :by_user, :by_package, :by_project].each do |review_by|
      who = review.send(review_by)
      next unless who

      @missing_reviews << { id: review.id, request: request.number, state: review.state.to_s, package: request.first_target_package, by: who, review_type: review_by.to_s }
      # No need to duplicate reviews
      break
    end
  end
end
# rubocop:enable Metrics/ModuleLength
