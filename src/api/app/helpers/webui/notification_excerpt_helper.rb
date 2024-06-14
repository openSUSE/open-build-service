module Webui::NotificationExcerptHelper
  TRUNCATION_LENGTH = 100
  TRUNCATION_ELLIPSIS_LENGTH = 3 # `...` is the default ellipsis for String#truncate

  # TODO: Content of ViewComponent. Move to sub-classes once STI is set.
  def excerpt(notification)
    text = case notification.notifiable.class.name
           when 'BsRequest'
             notification.notifiable.description
           when 'Comment'
             notification.notifiable.body
           when 'Report', 'Decision', 'Appeal', 'DecisionFavoredWithDeleteRequest', 'DecisionFavoredWithUserCommentingRestrictions', 'DecisionFavoredWithCommentModeration', 'DecisionFavoredWithUserDeletion'
             notification.notifiable.reason
           when 'WorkflowRun'
             "In repository #{notification.notifiable.repository_full_name}"
           else
             ''
           end

    truncate_to_first_new_line(text)
  end

  private

  def truncate_to_first_new_line(text)
    first_new_line_index = text.to_s.index("\n") # sometimes text can be nil
    truncation_index = !first_new_line_index.nil? && first_new_line_index < TRUNCATION_LENGTH ? first_new_line_index + TRUNCATION_ELLIPSIS_LENGTH : TRUNCATION_LENGTH
    text.truncate(truncation_index)
  end
end
