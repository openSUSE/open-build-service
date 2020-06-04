module Webui::ProjectHelper
  protected

  def pulse_period(range)
    end_time = Time.zone.today

    start_time = if range == 'month'
                   end_time.prev_month
                 else
                   end_time.prev_week
                 end

    "#{start_time.strftime("%B, #{start_time.day.ordinalize} %Y")} – #{end_time.strftime("%B, #{end_time.day.ordinalize} %Y")}"
  end

  def format_seconds(secs)
    secs = Integer(secs)
    if secs < 3600
      format('0:%02d', (secs / 60))
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
    return false if @project.defines_remote_instance?
    return true unless @is_incident_project && @packages.present? &&
                       @has_patchinfo && @open_release_requests.empty?

    false
  end

  def can_be_released?(project, packages, open_release_requests, has_patchinfo)
    !project.defines_remote_instance? && project.is_maintenance_incident? && packages.present? && has_patchinfo && open_release_requests.blank?
  end
end
