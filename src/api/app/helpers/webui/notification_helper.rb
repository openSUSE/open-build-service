module Webui::NotificationHelper
  TRUNCATION_LENGTH = 100
  TRUNCATION_ELLIPSIS_LENGTH = 3 # `...` is the default ellipsis for String#truncate

  def link_to_show_less_or_more
    parameters = params.slice(:show_more, :state, :project).permit!
    less_or_more = parameters[:show_more] ? 'less' : 'more'
    parameters[:show_more] = parameters[:show_more] ? nil : '1'
    link_to("Show #{less_or_more}", my_notifications_path(parameters))
  end

  def notification_excerpt(notifiable)
    text = case notifiable.class.name
           when 'BsRequest'
             notifiable.description.to_s # description can be nil
           when 'Comment'
             render_without_markdown(notifiable.body)
           when 'Report', 'Decision', 'Appeal', 'DecisionFavoredWithDeleteRequest', 'DecisionFavoredWithUserCommentingRestrictions', 'DecisionFavoredWithCommentModeration', 'DecisionFavoredWithUserDeletion'
             notifiable.reason
           when 'WorkflowRun'
             "In repository #{notifiable.repository_full_name}"
           else
             ''
           end

    first_new_line_index = text.index("\n")
    truncation_index = if !first_new_line_index.nil? && first_new_line_index < TRUNCATION_LENGTH
                         first_new_line_index + TRUNCATION_ELLIPSIS_LENGTH
                       else
                         TRUNCATION_LENGTH
                       end

    tag.p(text.truncate(truncation_index), class: %w[mt-3 mb-0])
  end

  private

  def mark_as_read_or_unread_button(notification)
    state = notification.unread? ? 'unread' : 'read'
    update_path = my_notifications_path(notification_ids: [notification.id], state: state)
    title, icon = notification.unread? ? ['Mark as read', 'fa-check'] : ['Mark as unread', 'fa-undo']
    link_to(update_path, id: dom_id(notification, :update), method: :put,
                         class: 'btn btn-sm btn-outline-success', title: title) do
      concat(tag.i(class: "#{icon} fas"))
      concat(" #{title}")
    end
  end
end
