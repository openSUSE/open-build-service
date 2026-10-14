module Webui::DistroReleaseLifecycleHelper
  def lifecycle_status_class(lifecycle_status)
    case lifecycle_status
    when 'general_availability'
      'text-bg-success'
    when 'maintenance', 'extended_support'
      'text-bg-primary'
    when 'development', 'alpha', 'beta', 'release_candidate'
      'text-bg-info'
    when 'deprecated'
      'text-bg-warning'
    when 'end_of_life'
      'text-bg-danger'
    else
      'text-bg-secondary'
    end
  end

  def distro_release_timeline_groups(distro_releases)
    distro_releases.each_with_index.map do |distro_release, index|
      { id: distro_release.id, content: distro_release.name, order: index }
    end
  end

  def distro_release_timeline_items(distro_releases)
    open_end_date = distro_release_timeline_open_end_date(distro_releases)

    distro_releases.flat_map do |distro_release|
      build_items_for_distro_release(distro_release, open_end_date)
    end
  end

  def distro_release_timeline_legend(distro_releases)
    present_statuses = distro_releases.flat_map(&:distro_release_lifecycles).map(&:status).uniq

    DistroReleaseLifecycle.statuses.keys.map do |status|
      { status: status, label: DistroReleaseLifecycle.status_label_for(status),
        highlight_class: lifecycle_timeline_css_class(status), color_class: lifecycle_status_class(status),
        present: present_statuses.include?(status) }
    end
  end

  private

  def build_items_for_distro_release(distro_release, open_end_date)
    lifecycles = distro_release.distro_release_lifecycles.sort_by(&:date)

    lifecycles.each_with_index.map do |lifecycle, index|
      # The end of life is drawn as a marker at the end of the previous phase, not as a phase of its own
      next build_end_of_life_item(lifecycle, distro_release.id) if lifecycle.end_of_life? && index.positive?

      build_timeline_item(lifecycle, lifecycles[index + 1], distro_release.id, open_end_date)
    end
  end

  def build_end_of_life_item(lifecycle, group_id)
    {
      id: lifecycle.id,
      group: group_id,
      type: 'box',
      content: '',
      start: lifecycle.date,
      title: safe_join([tag.strong(lifecycle.name), lifecycle.status_label, l(lifecycle.date, format: :long)], tag.br).to_str,
      className: "distro-release-lifecycle-eol #{lifecycle_timeline_css_class(lifecycle.status)}",
      status: lifecycle.status
    }
  end

  def build_timeline_item(lifecycle, next_lifecycle, group_id, open_end_date)
    {
      id: lifecycle.id,
      group: group_id,
      content: lifecycle_content(lifecycle, next_lifecycle),
      start: lifecycle.date,
      end: next_lifecycle&.date || open_end_date,
      title: lifecycle_title(lifecycle, next_lifecycle),
      className: lifecycle_css_classes(lifecycle),
      status: lifecycle.status
    }
  end

  def lifecycle_content(lifecycle, next_lifecycle)
    safe_join([tag.div(lifecycle.name, class: 'fw-semibold'),
               tag.small(lifecycle_date_range(lifecycle, next_lifecycle, format: '%m.%Y'))]).to_str
  end

  def lifecycle_title(lifecycle, next_lifecycle)
    lines = [tag.strong(lifecycle.name), lifecycle.status_label, lifecycle_date_range(lifecycle, next_lifecycle, format: :long)]
    lines << "End of Life on #{l(next_lifecycle.date, format: :long)}" if next_lifecycle&.end_of_life?
    safe_join(lines, tag.br).to_str
  end

  def lifecycle_date_range(lifecycle, next_lifecycle, format:)
    return "since #{l(lifecycle.date, format: format)}" if next_lifecycle.nil?

    "#{l(lifecycle.date, format: format)} - #{l(next_lifecycle.date - 1.day, format: format)}"
  end

  def lifecycle_css_classes(lifecycle)
    [lifecycle_timeline_css_class(lifecycle.status), lifecycle_status_class(lifecycle.status)].join(' ')
  end

  def lifecycle_timeline_css_class(status)
    "distro-release-lifecycle-#{status.dasherize}"
  end

  def distro_release_timeline_open_end_date(distro_releases)
    latest_date = distro_releases.flat_map(&:distro_release_lifecycles).map(&:date).max
    [Date.current, latest_date].compact.max + 1.year
  end
end
