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
end
