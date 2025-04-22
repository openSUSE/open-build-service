module Webui::ProjectHelper
  protected

  def pulse_period(date_range)
    start_time = date_range.first
    end_time = date_range.last

    "#{start_time.strftime("%B, #{start_time.day.ordinalize} %Y")} – #{end_time.strftime("%B, #{end_time.day.ordinalize} %Y")}"
  end

  def format_seconds(secs)
    secs = Integer(secs)
    if secs < 3600
      format('0:%02d', secs / 60)
    else
      hours = secs / 3600
      secs -= hours * 3600
      format('%d:%02d', hours, secs / 60)
    end
  end

  def rebuild_time_col(package)
    return '' if package.blank?

    btime = @timings[package][0]
    link_to(h(package), controller: '/webui/package', action: :show, project: @project, package: package) + ' ' + format_seconds(btime)
  end

  def show_package_actions?
    return false if @is_maintenance_project
    return false if @project.scmsync.present?
    return false if @project.defines_remote_instance?
    return false if @is_incident_project && @packages.present? &&
                    @project.patchinfos.exists? && @open_release_requests.empty?

    true
  end

  def project_labels(project, &)
    project.label_templates.includes([:labels]).find_each do |label_template|
      label_template.labels.each(&)
    end
  end
end
