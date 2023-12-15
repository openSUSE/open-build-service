class ReportPolicy < ApplicationPolicy
  def show?
    return true if user.is_admin? || user.is_moderator? || user.is_staff?
    return true if record.user == user

    CommentPolicy.new(user, record.reportable).maintainer? if record.reportable_type == 'Comment'
  end

  # rubocop:disable Metrics/CyclomaticComplexity
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
    when 'BsRequest'
      !BsRequestPolicy.new(user, record.reportable).report?
    end
  end
  # rubocop:enable Metrics/CyclomaticComplexity

  def notify?
    return false unless Flipper.enabled?(:content_moderation, user)
    return true if User.moderators.blank? && (user.is_admin? || user.is_staff?)
    return true if user.is_moderator?

    false
  end
end
