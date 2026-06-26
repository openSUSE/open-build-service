module Webui::Staging::ProjectHelper
  def icon_for_checks(checks, missing_checks)
    return 'fa-eye text-info' if missing_checks.present?
    return 'fa-check-circle text-primary' if checks.blank?
    return 'fa-eye text-info' if checks.any?(&:pending?)
    return 'fa-check-circle text-primary' if checks.all?(&:success?)

    'fa-exclamation-circle text-danger'
  end

  def icon_for_check(check)
    return 'fa-check-circle text-primary' if check.success?
    return 'fa-eye text-info' if check.pending?

    'fa-exclamation-circle text-danger'
  end

  def merge_broken_packages(packages)
    problems = {}
    packages.each do |package|
      problems[package[:package]] ||= {}
      problems[package[:package]][package[:state]] ||= []
      problems[package[:package]][package[:state]] << { repository: package[:repository], arch: package[:arch] }
    end
    problems.sort
  end
end
