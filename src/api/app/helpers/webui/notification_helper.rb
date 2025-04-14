module Webui::NotificationHelper
  TRUNCATION_LENGTH = 100
  TRUNCATION_ELLIPSIS_LENGTH = 3 # `...` is the default ellipsis for String#truncate

  MAXIMUM_DISPLAYED_AVATARS = 6

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

  def truncate_to_first_new_line(text)
    return '' if text.blank?

    first_new_line_index = text.index("\n")
    truncation_index = !first_new_line_index.nil? && first_new_line_index < TRUNCATION_LENGTH ? first_new_line_index + TRUNCATION_ELLIPSIS_LENGTH : TRUNCATION_LENGTH
    text.truncate(truncation_index)
  end

  def avatars(notification)
    capture do
      tag.ul(class: 'list-inline d-flex flex-row-reverse avatars m-0') do
        hidden_avatars(notification)

        avatars_to_display(notification.avatar_objects).each do |avatar_object|
          concat(
            tag.li(class: 'list-inline-item') do
              case avatar_object.class.name
              when 'User', 'Group'
                render(AvatarComponent.new(name: avatar_object.name, email: avatar_object.email, size: 23, shape: :circle))
              when 'Package'
                tag.span(class: 'fa fa-archive text-warning rounded-circle bg-body-secondary border simulated-avatar', title: "Package #{avatar_object.project}/#{avatar_object}")
              when 'Project'
                tag.span(class: 'fa fa-cubes text-secondary rounded-circle bg-body-secondary border simulated-avatar', title: "Project #{avatar_object}")
              end
            end
          )
        end
      end
    end
  end

  def notification_icon(notification)
    if notification.event_type.in?(['Event::RelationshipCreate', 'Event::RelationshipDelete'])
      tag.i(class: %w[fas fa-user-tag], title: 'Relationship notification')
    elsif NOTIFICATION_ICON[notification.notifiable_type].present?
      tag.i(class: ['fas', NOTIFICATION_ICON[notification.notifiable_type]], title: NOTIFICATION_TITLE[notification.notifiable_type])
    end
  end

  def description(notification)
    case notification.event_type
    when 'Event::ReportForUser'
      description_for_user_report(notification)
    when 'Event::ReportForComment'
      description_for_comment_report(notification)
    else
      notification.description
    end
  end

  private

  def number_of_hidden_avatars(avatar_objects)
    [0, avatar_objects.size - MAXIMUM_DISPLAYED_AVATARS].max
  end

  def hidden_avatars(notification)
    return unless number_of_hidden_avatars(notification.avatar_objects).positive?

    concat(
      tag.li(class: 'list-inline-item') do
        tag.span(number_of_hidden_avatars(notification.avatar_objects).to_s,
                 class: 'rounded-circle bg-body-secondary border avatars-counter',
                 title: "#{number_of_hidden_avatars(notification.avatar_objects)} more users involved")
      end
    )
  end

  def avatars_to_display(avatar_objects)
    avatar_objects.first(MAXIMUM_DISPLAYED_AVATARS).reverse
  end

  def description_for_user_report(notification)
    reporter = notification.notifiable.reporter
    accused = notification.notifiable.reportable
    reports_on_comments = count_reports_on_comments(accused) if accused
    reports_on_user = count_reports_on_user(accused) if accused

    generate_report_description(notification, reporter, accused, reports_on_comments, reports_on_user)
  end

  def description_for_comment_report(notification)
    reporter = notification.notifiable.reporter
    accused = notification.notifiable.reportable&.user
    reports_on_user = count_reports_on_user(accused) if accused
    reports_on_comments = count_reports_on_comments(accused) if accused

    generate_report_description(notification, reporter, accused, reports_on_comments, reports_on_user, comment: true)
  end

  def count_reports_on_comments(accused)
    Report.without_decision.where(reportable: accused.comments).count
  end

  def count_reports_on_user(accused)
    Report.without_decision.where(reportable: accused).count
  end

  def count_of_additional_reports_for_reportable(notification)
    return 0 unless notification.notifiable.reportable

    notification.notifiable.reportable.reports.without_decision.count - 1
  end

  def generate_report_description(notification, reporter, accused, reports_on_comments, reports_on_user, comment: false)
    text = link_to(reporter, user_path(reporter, notification_id: notification.id))
    text += ' created a report for '
    text += 'comment from ' if comment
    if accused
      text += link_to(accused, user_path(accused, notification_id: notification.id))
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
      class: ['badge', 'mx-1', (state.present? ? 'text-bg-secondary' : 'text-bg-warning').to_s]
    )
  end

  def icon_tag(number_of_reports, icon)
    sanitize(" #{number_of_reports} #{content_tag(:i, nil, class: "fa fa-#{icon}")} reported")
  end
end
