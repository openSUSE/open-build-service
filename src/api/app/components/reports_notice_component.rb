class ReportsNoticeComponent < ApplicationComponent
  attr_reader :reportable, :user

  def initialize(reportable:, user:)
    super

    @reportable = reportable
    @user = user
  end

  def by_user
    !!Report.find_by(user:, reportable:)
  end

  def reports
    reportable&.reports
  end

  def render?
    Flipper.enabled?(:content_moderation, user) &&
      reports&.any? { |r| Pundit.policy(user, r).show? }
  end
end
