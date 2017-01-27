class MaintenanceStatistic
  include ActiveModel::Model
  attr_accessor :type, :when, :who, :name, :tracker, :id

  def self.find_by_project(project)
    request = BsRequest.
              joins(:bs_request_actions).
              find_by(bs_request_actions: { source_project: project.name, type: 'maintenance_release' })

    create_objects(project, request)
  end

  def self.create_objects(project, request)
    result = []

    result << MaintenanceStatistic.new(type: :project_created, when: project.created_at)

    if request
      result << MaintenanceStatistic.new(type: :release_request_created, when: request.created_at)

      # TODO: This is to reflect also :decline, :reopen etc.
      # However, we need to adapt the view src/api/app/views/statistics/maintenance_incidents/show.xml.builder
      # because it only reflects :accepted state atm
      request.request_history_elements.each do |history_element|
        # history_element.type is untested and probably doesn't work -> should result in sth like release_request_accepted
        result << MaintenanceStatistic.new(type: "release_request_#{history_element.type}", when: history_element.created_at)
      end

      request.reviews.unassigned.each do |review|
        if review.accepted_at
          result << MaintenanceStatistic.new(type: :review_accepted, who: review.assigned_reviewer, id: review.id, when: review.accepted_at)
        end

        result << MaintenanceStatistic.new(type: :review_opened, who: review.assigned_reviewer, id: review.id, when: review.created_at)
      end
    end

    project.issues.each do |issue|
      result << MaintenanceStatistic.new(type: :issue_created, name: issue.name, tracker: issue.issue_tracker.name, when: issue.created_at)
    end
    result.sort_by(&:when).reverse
  end
end
