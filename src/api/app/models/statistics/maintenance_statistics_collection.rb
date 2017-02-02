module Statistics
  class MaintenanceStatisticsCollection
    attr_reader :project

    def initialize(project)
      @project = project
    end

    def build
      result = []
      result << project_created_statistic

      if request
        result << release_request_created_statistic
        result += history_element_statistics
        result += unassigned_review_statistics
      end

      result += issue_statistics
      result.sort_by(&:when).reverse
    end

    private

    def request
      @request ||=
        BsRequest.joins(:bs_request_actions).find_by(
          bs_request_actions: { source_project: project.name, type: 'maintenance_release' }
        )
    end

    def project_created_statistic
      MaintenanceStatistic.new(type: :project_created, when: project.created_at)
    end

    def release_request_created_statistic
      MaintenanceStatistic.new(type: :release_request_created, when: request.created_at)
    end

    def history_element_statistics
      request.request_history_elements.map do |history_element|
        history_element_type = history_element.class.name.demodulize.underscore

        MaintenanceStatistic.new(
          type: "release_request_#{history_element_type}",
          when: history_element.created_at
        )
      end
    end

    def unassigned_review_statistics
      unassigned_review_statistics = []

      request.reviews.unassigned.each do |review|
        unassigned_review_statistics << MaintenanceStatistic.new(
          type: :review_opened,
          who: review.assigned_reviewer,
          id: review.id,
          when: review.created_at
        )

        if review.accepted_at
          unassigned_review_statistics << MaintenanceStatistic.new(
            type: :review_accepted,
            who: review.assigned_reviewer,
            id: review.id,
            when: review.accepted_at
          )
        end

        if review.declined_at
          unassigned_review_statistics << MaintenanceStatistic.new(
            type: :review_declined,
            who: review.assigned_reviewer,
            id: review.id,
            when: review.declined_at
          )
        end
      end
      unassigned_review_statistics
    end

    def issue_statistics
      project.issues.map do |issue|
        MaintenanceStatistic.new(
          type: :issue_created,
          name: issue.name,
          tracker: issue.issue_tracker.name,
          when: issue.created_at
        )
      end
    end
  end
end
