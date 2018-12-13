module Webui::Staging::ProjectHelper
  def icon_for_checks(checks, missing_checks)
    return 'fa-eye text-info' if missing_checks.present?
    return 'fa-check-circle text-primary' if checks.blank?
    return 'fa-eye text-info' if checks.any?(&:pending?)
    return 'fa-check-circle text-primary' if checks.all?(&:success?)
    'fa-exclamation-circle text-danger'
  end
end
