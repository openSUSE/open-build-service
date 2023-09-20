class ReportsNoticeComponentPreview < ViewComponent::Preview
  # Preview at http://HOST:PORT/rails/view_components/reports_notice_component/user_reportable_as_admin
  def user_reportable_as_admin
    reportable = User.last
    User.take(3).each do |reporter|
      Report.new(reportable:, user: reporter).save!
    end
    render(ReportsNoticeComponent.new(reportable:, user: User.admins.first))
  end

  # Preview at http://HOST:PORT/rails/view_components/reports_notice_component/user_reportable_as_reporter
  def user_reportable_as_reporter
    reportable = User.last
    reporters = User.take(3)
    reporters.each do |reporter|
      Report.new(reportable:, user: reporter).save!
    end
    render(ReportsNoticeComponent.new(reportable:, user: reporters.last))
  end
end
