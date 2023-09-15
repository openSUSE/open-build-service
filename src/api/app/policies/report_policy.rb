class ReportPolicy < ApplicationPolicy
  def show?
    user.is_admin? || record.user == user
  end

  def create?
    return false unless Flipper.enabled?(:content_moderation, user)

    # We don't want reports twice...
    return false if user.submitted_reports.where(reportable: record.reportable).any?

    # We don't want reports for things you can change yourself...
    case record.reportable_type
    when 'Package'
      !PackagePolicy.new(user, record.reportable).update?
    when 'Project'
      !ProjectPolicy.new(user, record.reportable).update?
    when 'Comment'
      !CommentPolicy.new(user, record.reportable).update?
    when 'User'
      !UserPolicy.new(user, record.reportable).update?
    end
  end
end
