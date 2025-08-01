class ReportsNoticeComponent < ApplicationComponent
  attr_reader :reportable, :reportable_name, :user, :reports

  def initialize(reportable:, user:)
    super

    @reportable = reportable
    @reportable_name = if reportable.instance_of?(::BsRequest)
                         'request'
                       else
                         reportable.class.name.downcase
                       end
    @user = user
    @reports = reportable&.reports&.without_decision
  end

  def by_user?
    Report.exists?(reporter: user, reportable:)
  end

  def report_amount
    pluralize(reports.count, 'report')
  end

  def render?
    Flipper.enabled?(:content_moderation, user) &&
      reports&.any? { |r| Pundit.policy(user, r).show? }
  end
end
