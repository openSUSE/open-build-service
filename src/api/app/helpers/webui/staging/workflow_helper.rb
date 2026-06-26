module Webui::Staging::WorkflowHelper
  def build_progress(staging_project)
    final = to_build = 0

    staging_project.building_repositories.each do |repository|
      to_build += repository[:tobuild]
      final += repository[:final]
    end

    total = to_build + final

    return 100 if total.zero?

    # if we have building repositories, make sure we don't exceed 99
    [final * 100 / total, 99].min
  end

  def review_progress(staging_project)
    staged_requests_numbers = staging_project.staged_requests.pluck(:number)
    total = Review.where(bs_request: staging_project.staged_requests).size
    missing = staging_project.missing_reviews.count { |missing_review| staged_requests_numbers.include?(missing_review[:request]) }
    return 100 if total.zero?

    100 - (missing * 100 / total)
  end

  def testing_progress(staging_project)
    return 0 if staging_project.checks.empty?

    not_done = staging_project.checks.pending.size + staging_project.missing_checks.size
    all_checks = staging_project.checks.size + staging_project.missing_checks.size

    100 - (not_done * 100 / all_checks)
  end

  def progress(staging_project)
    case staging_project.overall_state
    when :building
      link_to(project_monitor_url(staging_project.name)) do
        "#{build_progress(staging_project)} %"
      end
    when :review
      "#{review_progress(staging_project)} %"
    when :testing
      "#{testing_progress(staging_project)} %"
    end
  end

  def reviewers_icon(request, users_hash, groups_hash)
    missing_reviews = request[:missing_reviews]
    tags = []
    missing_reviews.each do |review|
      case review[:review_type]
      when 'by_group'
        tags << image_tag_for(groups_hash[review[:by]], size: 20)
      when 'by_user'
        tags << image_tag_for(users_hash[review[:by]], size: 20)
      when 'by_project'
        tags << tag.i(nil, class: 'fa fa-cubes', title: review[:by])
      when 'by_package'
        tags << tag.i(nil, class: 'fa fa-archive', title: review[:by])
      end
    end
    tags
  end

  def create_request_links(request, users_hash, groups_hash)
    css = 'ready'
    css = 'review' if request[:missing_reviews].present?
    css = 'obsolete' if request[:state].in?(BsRequest::OBSOLETE_STATES)
    css += ' delete' if request[:request_type] == 'delete'
    link_content = [request[:package].match?(/patchinfo\.\d+\.\d+/) ? 'patchinfo' : request[:package]]
    link_content << reviewers_icon(request, users_hash, groups_hash) if request[:missing_reviews].present?
    tag.span(class: "badge state-#{css}") do
      link_to(request_show_path(request[:number]), class: 'request') do
        safe_join(link_content)
      end
    end
  end

  def requests(staging_project, users_hash, groups_hash)
    classified_requests = staging_project.classified_requests
    number_of_requests = classified_requests.size

    return 'None' if number_of_requests.zero?

    requests_visible_by_default = 10
    requests_links = classified_requests.map do |request|
      create_request_links(request, users_hash, groups_hash)
    end

    return safe_join(requests_links) if number_of_requests <= requests_visible_by_default

    output = safe_join(requests_links[0, requests_visible_by_default])

    output += link_to('#', class: 'collapsed', 'data-bs-toggle': 'collapse', href: ".collapse-#{staging_project.id}",
                           role: 'button', aria: { expanded: 'false', controls: "collapse-#{staging_project.id}" }) do
      safe_join([
                  tag.i(nil, class: 'fas fa-chevron-up collapser text-secondary ms-1 me-1'),
                  tag.i(nil, class: 'fas fa-chevron-down expander text-secondary ms-1 me-1')
                ])
    end
    output + tag.div(class: "collapse collapse-#{staging_project.id}") do
      safe_join(requests_links[requests_visible_by_default..])
    end
  end

  def info_link(request, excluded: false)
    if excluded
      options = { data: { 'bs-content': request.request_exclusion.description,
                          'bs-placement': 'top', 'bs-toggle': 'popover' } }
    end
    link_to(elide(request.first_target_package, 19), request_show_path(request.number), options)
  end
end
