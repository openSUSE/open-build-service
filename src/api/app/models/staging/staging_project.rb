module Staging
  class StagingProject < Project
    has_many :staged_requests, class_name: 'BsRequest', foreign_key: :staging_project_id, dependent: :nullify
    has_many :status_reports, through: :repositories, inverse_of: :checkable
    belongs_to :staging_workflow, class_name: 'Staging::Workflow'

    def staging_identifier
      name[/.*:Staging:(.*)/, 1]
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
      attribs = [:by_group, :by_user, :by_package, :by_project]

      staged_requests.includes(:reviews).find_each do |request|
        request.reviews.where.not(state: :accepted).find_each do |review|
          # We skip reviews for the staging project since these reviews are used
          # by the openSUSE release tools _after_ the overall_state switched to
          # 'accepted'.
          next if review.by_project == name
          # FIXME: this loop (and the inner if) would not be needed
          # if every review only has one valid by_xxx.
          # I'm keeping it to mimic the python implementation.
          # Instead, we could have something like
          # who = review.by_group || review.by_user || review.by_project || review.by_package
          attribs.each do |att|
            who = review.send(att)
            next unless who

            @missing_reviews << { id: review.id, request: request.number, state: review.state.to_s, package: request.first_target_package, by: who }
            # No need to duplicate reviews
            break
          end
        end
      end

      @missing_reviews
    end

    def overall_state
      @overall_state ||= state
    end

    private

    def state
      return :empty unless staged_requests.exists?
      return :unacceptable if untracked_requests.present? || staged_requests.obsolete.present?

      overall_state = build_state
      overall_state = check_state if overall_state == :acceptable

      return :review if overall_state == :acceptable && missing_reviews.present?

      overall_state
    end

    def build_state
      set_buildinfo

      return :building if building_repositories.present?
      return :failed if broken_packages.present?

      :acceptable
    end

    def relevant_status_reports
      @relevant_status_reports ||= status_reports.where(uuid: repositories.map(&:build_id))
    end

    def missing_checks?
      relevant_status_reports.any? { |report| report.missing_checks.present? }
    end

    def check_state
      status_checks = Status::Check.where(status_reports_id: relevant_status_reports)
      return :testing if missing_checks? || status_checks.pending.exists?
      return :failed if status_checks.failed.exists?
      return :acceptable
    end

    def set_buildinfo
      buildresult = Xmlhash.parse(Backend::Api::BuildResults::Status.failed_results(name))

      @broken_packages = []
      @building_repositories = []

      buildresult.elements('result') do |result|
        building = ['published', 'unpublished'].exclude?(result['state']) || result['dirty'] == 'true'

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

        if building
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
      end

      @broken_packages.reject! { |package| package['state'] == 'unresolvable' } if @building_repositories.present?
    end
  end
end
