class NotificationActionDescriptionComponent < ApplicationComponent
  def initialize(notification)
    super

    @notification = notification
  end

  def call
    tag.div(class: ['smart-overflow']) do
      case @notification.event_type
      when 'Event::RequestStatechange', 'Event::RequestCreate', 'Event::ReviewWanted', 'Event::CommentForRequest'
        source_and_target
      when 'Event::CommentForProject'
        "#{@notification.notifiable.commentable.name}"
      when 'Event::CommentForPackage'
        commentable = @notification.notifiable.commentable
        "#{commentable.project.name} / #{commentable.name}"
      end
    end
  end

  private

  def source_and_target
    capture do
      if source.present?
        concat(tag.span(source))
        concat(tag.i(nil, class: 'fas fa-long-arrow-alt-right text-info mx-2'))
      end
      concat(tag.span(target))
    end
  end

  def source
    @source ||= if number_of_bs_request_actions > 1
                  ''
                else
                  [bs_request_action.source_project, bs_request_action.source_package].compact.join(' / ')
                end
  end

  def target
    return bs_request_action.target_project if number_of_bs_request_actions > 1

    [bs_request_action.target_project, bs_request_action.target_package].compact.join(' / ')
  end

  def bs_request
    @bs_request ||= @notification.notifiable_type == 'BsRequest' ? @notification.notifiable : @notification.notifiable.commentable
  end

  def bs_request_action
    @bs_request_action ||= bs_request.bs_request_actions.first
  end

  def number_of_bs_request_actions
    @number_of_bs_request_actions ||= bs_request.bs_request_actions.size
  end
end
