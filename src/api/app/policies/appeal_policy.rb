class AppealPolicy < ApplicationPolicy
  def new?
    create?
  end

  def show?
    return false unless Flipper.enabled?(:content_moderation, user)
    return true if record.appellant == user

    user.admin? || user.moderator? || user.staff?
  end

  # A user can create an appeal for a decision which is against them
  # A decision is against them if:
  # 1. They reported a project/package/etc, but a moderator took a decision which cleared the report
  #   OR
  # 2. They did something was reported (a spam comment, etc...) and a moderator took a decision which favored the report
  def create?
    return false unless Flipper.enabled?(:content_moderation, user)

    # Prevent appealing a decision for reports with a deleted reportable, since this wouldn't have any effect anyway.
    @report = record.decision.reports.first
    return false if @report.reportable_type.nil?

    decision_cleared_report_from_user? || decision_favored_report_of_action_from_user? ||
      user.admin? || user.staff?
  end

  private

  def decision_cleared_report_from_user?
    return false unless record.appellant == user

    record.decision.type == 'DecisionCleared' && record.decision.reports.pluck(:reporter_id).include?(user.id)
  end

  def decision_favored_report_of_action_from_user?
    return false unless record.appellant == user

    record.decision.type == 'DecisionFavored' && "#{@report.reportable_type}Policy".constantize.new(user, @report.reportable).update?
  end
end
