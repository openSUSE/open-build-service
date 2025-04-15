class ReportPolicy < ApplicationPolicy
  def show?
    return true if user.admin? || user.moderator? || user.staff?
    return true if record.reporter == user

    CommentPolicy.new(user, record.reportable).maintainer? if record.reportable_type == 'Comment'
  end

  # rubocop:disable Metrics/CyclomaticComplexity
  def create?
    return false unless Flipper.enabled?(:content_moderation, user)

    # We don't want reports twice...
    return false if user.submitted_reports.where(reportable: record.reportable).any?

    # We don't want reports for things you can change yourself nor for comment reports
    case record.reportable_type
    when 'Package'
      !PackagePolicy.new(user, record.reportable).update?
    when 'Project'
      !ProjectPolicy.new(user, record.reportable).update?
    when 'Comment'
      !CommentPolicy.new(user, record.reportable).update? &&
        !record.reportable.commentable.is_a?(Report)
    when 'User'
      !UserPolicy.new(user, record.reportable).update?
    when 'BsRequest'
      !BsRequestPolicy.new(user, record.reportable).report?
    end
  end
  # rubocop:enable Metrics/CyclomaticComplexity

  def notify?
    return false unless Flipper.enabled?(:content_moderation, user)
    return true if User.moderators.blank? && (user.admin? || user.staff?)
    return true if user.moderator?

    false
  end
end
