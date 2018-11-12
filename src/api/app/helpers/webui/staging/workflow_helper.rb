module Webui::Staging::WorkflowHelper
  def build_progress(staging_project)
    final = to_build = 0

    staging_project.building_repositories.each do |repository|
      to_build += repository[:tobuild]
      final += repository[:final]
    end

    total = to_build + final

    return 100 if total == 0
    # if we have building repositories, make sure we don't exceed 99
    [final * 100 / total, 99].min
  end

  def review_progress(staging_project)
    staged_requests_numbers = staging_project.staged_requests.pluck(:number)
    total = Review.where(bs_request: staging_project.staged_requests).size
    missing = staging_project.missing_reviews.count { |missing_review| staged_requests_numbers.include?(missing_review[:request]) }

    100 - missing * 100 / total
  end

  def testing_progress(staging_project)
    notdone = allchecks = 0

    # Note: The status_reports are defined via a has many through relation. Since within the
    #       status report context the bs request relation is polymorphic, we have to call
    #       includes with the polymorphic name ('checkable').
    staging_project.status_reports.includes(:checkable).each do |report|
      notdone += report.checks.where(state: 'pending').size
      allchecks += report.checks.size + report.missing_checks.size
    end

    return 100 if allchecks == 0
    100 - notdone * 100 / allchecks
  end

  def progress(staging_project)
    case staging_project.overall_state
    when :building
      link_to project_monitor_url(staging_project.name) do
        "#{build_progress(staging_project)} %"
      end
    when :review
      "#{review_progress(staging_project)} %"
    when :testing
      "#{testing_progress(staging_project)} %"
    end
  end
end
