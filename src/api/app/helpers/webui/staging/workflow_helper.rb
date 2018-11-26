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
    notdone = staging_project.checks.pending.size
    allchecks = staging_project.checks.size + staging_project.missing_checks.size

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

  def requests(staging_project)
    number_of_requests = staging_project.classified_requests.size

    return 'None' if number_of_requests == 0

    requests_visible_by_default = 10
    requests_links = staging_project.classified_requests.map do |request|
      css = 'ready'
      css = 'review' if request[:missing_reviews].present?
      css = 'obsolete' if request[:state].in?(BsRequest::OBSOLETE_STATES)

      link_to(request_show_path(request[:number]), class: 'request') do
        content_tag(:span, request[:package], class: "badge state-#{css}")
      end
    end

    if number_of_requests <= requests_visible_by_default
      return safe_join(requests_links)
    end

    output = safe_join(requests_links[0, requests_visible_by_default])

    output += link_to('#', class: 'collapsed', 'data-toggle': 'collapse', href: ".collapse-#{staging_project.id}",
                           role: 'button', aria: { expanded: 'false', controls: "collapse-#{staging_project.id}" }) do
      safe_join([
                  content_tag(:i, nil, class: 'fas fa-chevron-up collapser text-secondary ml-1 mr-1'),
                  content_tag(:i, nil, class: 'fas fa-chevron-down expander text-secondary ml-1 mr-1')
                ])
    end
    output + content_tag(:div, class: "collapse collapse-#{staging_project.id}") do
      safe_join(requests_links[requests_visible_by_default..-1])
    end
  end
end
