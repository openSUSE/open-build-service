class ReportsModalComponentPreview < ViewComponent::Preview
  # Preview at http://HOST:PORT/rails/view_components/reports_notice_component/user_reportable_as_admin
  def user_reportable_as_admin
    reportable = User.last
    User.where.not(id: User.admins).take(3).each do |user|
      Report.new(reportable:, user:).save!
    end
    render(ReportsNoticeComponent.new(reportable:, user: User.admins.first))
  end

  # Preview at http://HOST:PORT/rails/view_components/reports_notice_component/comment_reportable_as_admin
  def comment_reportable_as_admin
    reportable = Comment.last
    User.where.not(id: User.admins).take(3).each do |user|
      Report.new(reportable:, user:).save!
    end
    render(ReportsNoticeComponent.new(reportable:, user: User.admins.first))
  end
end
