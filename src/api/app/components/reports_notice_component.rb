class ReportsNoticeComponent < ApplicationComponent
  attr_reader :reportable, :reportable_name, :user, :reports

  def initialize(reportable:, user:)
    super

    @reportable = reportable
    @reportable_name = reportable.class.name.downcase
    @user = user
    @reports = reportable&.reports
  end

  def by_user?
    Report.exists?(user:, reportable:)
  end

  def report_amount
    pluralize(reports.count, 'report')
  end

  def render?
    Flipper.enabled?(:content_moderation, user) &&
      reports&.any? { |r| Pundit.policy(user, r).show? }
  end
end
