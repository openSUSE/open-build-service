module Webui::DistroReleaseLifecycleHelper
  def lifecycle_status_class(lifecycle)
    case lifecycle.status
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
    distro_releases.map { |distro_release| { id: distro_release.id, content: distro_release.name } }
  end

  def distro_release_timeline_items(distro_releases)
    open_end_date = distro_release_timeline_open_end_date(distro_releases)

    distro_releases.flat_map do |distro_release|
      build_items_for_distro_release(distro_release, open_end_date)
    end
  end

  private

  def build_items_for_distro_release(distro_release, open_end_date)
    distro_release.distro_release_lifecycles.sort_by(&:date).then { |list| list + [nil] }
                  .each_cons(2)
                  .map do |lifecycle, next_lifecycle|
      build_timeline_item(lifecycle, next_lifecycle, distro_release.id, open_end_date)
    end
  end

  def build_timeline_item(lifecycle, next_lifecycle, group_id, open_end_date)
    ongoing = next_lifecycle.nil?

    {
      id: lifecycle.id,
      group: group_id,
      content: lifecycle_content(lifecycle, ongoing: ongoing),
      start: lifecycle.date,
      end: next_lifecycle&.date || open_end_date,
      title: lifecycle.name,
      className: lifecycle_css_classes(lifecycle, ongoing: ongoing)
    }
  end

  def lifecycle_content(lifecycle, ongoing:)
    ongoing ? "#{lifecycle.status_label} (ongoing)" : lifecycle.status_label
  end

  def lifecycle_css_classes(lifecycle, ongoing:)
    classes = [lifecycle_status_class(lifecycle)]
    classes << 'distro-release-lifecycle-ongoing' if ongoing
    classes.join(' ')
  end

  def distro_release_timeline_open_end_date(distro_releases)
    latest_date = distro_releases.flat_map(&:distro_release_lifecycles).map(&:date).max
    [Date.current, latest_date].compact.max + 1.year
  end
end
