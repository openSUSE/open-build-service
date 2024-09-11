class NotificationComponent < ApplicationComponent
  NOTIFICATION_ICON = {
    'BsRequest' => 'fa-code-pull-request', 'Comment' => 'fa-comments',
    'Package' => 'fa-xmark text-danger',
    'Report' => 'fa-flag', 'Decision' => 'fa-clipboard-check',
    'Appeal' => 'fa-hand', 'WorkflowRun' => 'fa-book-open',
    'Group' => 'fa-people-group'
  }.freeze

  NOTIFICATION_TITLE = {
    'BsRequest' => 'Request notification', 'Comment' => 'Comment notification',
    'Package' => 'Package notification', 'Report' => 'Report notification',
    'Decision' => 'Report decision', 'Appeal' => 'Decision appeal',
    'WorkflowRun' => 'Workflow run', 'Group' => 'Group members changed'
  }.freeze

  def initialize(notification:, selected_filter:, page:)
    super

    @notification = notification
    @selected_filter = selected_filter
    @page = page
  end

  def notification_icon
    if @notification.event_type.in?(['Event::RelationshipCreate', 'Event::RelationshipDelete'])
      tag.i(class: %w[fas fa-user-tag], title: 'Relationship notification')
    elsif NOTIFICATION_ICON[@notification.notifiable_type].present?
      tag.i(class: ['fas', NOTIFICATION_ICON[@notification.notifiable_type]], title: NOTIFICATION_TITLE[@notification.notifiable_type])
    end
  end

  def description
    case @notification.event_type
    when 'Event::ReportForUser'
      description_for_user_report
    when 'Event::ReportForComment'
      description_for_comment_report
    else
      @notification.description
    end
  end

  private

  def description_for_user_report
    reporter = @notification.notifiable.user
    accused = @notification.notifiable.reportable
    reports_on_comments = count_reports_on_comments(accused) if accused
    reports_on_user = count_reports_on_user(accused) if accused

    generate_report_description(reporter, accused, reports_on_comments, reports_on_user)
  end

  def description_for_comment_report
    reporter = @notification.notifiable.user
    accused = @notification.notifiable.reportable&.user
    reports_on_user = count_reports_on_user(accused) if accused
    reports_on_comments = count_reports_on_comments(accused) if accused

    generate_report_description(reporter, accused, reports_on_comments, reports_on_user, comment: true)
  end

  def count_reports_on_comments(accused)
    Report.without_decision.where(reportable: accused.comments).count
  end

  def count_reports_on_user(accused)
    Report.without_decision.where(reportable: accused).count
  end

  def count_of_additional_reports_for_reportable
    return 0 unless @notification.notifiable.reportable

    @notification.notifiable.reportable.reports.without_decision.count - 1
  end

  def generate_report_description(reporter, accused, reports_on_comments, reports_on_user, comment: false)
    text = link_to(reporter, user_path(reporter, notification_id: @notification.id))
    text += ' created a report for '

    if comment
      text += 'a '
      text += 'deleted ' if !accused
      text += 'comment '
      text += 'from ' if accused
    end

    if accused
      text += link_to(accused, user_path(accused, notification_id: @notification.id))
      text += create_badge(state: accused.state)

      text += if comment && reports_on_user.positive?
                create_badge(number_of_reports: "+#{reports_on_user}", icon: 'user')
              elsif reports_on_comments.positive?
                create_badge(number_of_reports: "+#{reports_on_comments}", icon: 'comments')
              end
    end

    sanitize(text)
  end

  def create_badge(number_of_reports: nil, state: nil, icon: nil)
    content_tag(
      :span,
      state.presence || icon_tag(number_of_reports, icon),
      class: ['badge', 'mx-1', "#{state.present? ? 'text-bg-secondary' : 'text-bg-warning'}"]
    )
  end

  def icon_tag(number_of_reports, icon)
    sanitize(" #{number_of_reports} #{content_tag(:i, nil, class: "fa fa-#{icon}")} reported")
  end
end
