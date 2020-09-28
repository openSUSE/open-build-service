require 'redcarpet/render_strip'

class NotificationPresenter < SimpleDelegator
  TRUNCATION_LENGTH = 100
  TRUNCATION_ELLIPSIS_LENGTH = 3 # `...` is the default ellipsis for String#truncate

  def initialize(model)
    @model = model
    super(@model)
  end

  def notifiable_link
    case @model.event_type
    when 'Event::RequestStatechange', 'Event::RequestCreate', 'Event::ReviewWanted'
      { text: "#{type_of_action(@model.notifiable)} Request ##{@model.notifiable.number}",
        path: Rails.application.routes.url_helpers.request_show_path(@model.notifiable.number, notification_id: @model.id) }
    when 'Event::CommentForRequest'
      { text: "Comment on #{type_of_action(@model.notifiable.commentable)} Request",
        path: Rails.application.routes.url_helpers.request_show_path(@model.notifiable.commentable.number, notification_id: @model.id, anchor: 'comments-list') }
    when 'Event::CommentForProject'
      { text: 'Comment on Project',
        path: Rails.application.routes.url_helpers.project_show_path(@model.notifiable.commentable, notification_id: @model.id, anchor: 'comments-list') }
    when 'Event::CommentForPackage'
      { text: 'Comment on Package',
        path: Rails.application.routes.url_helpers.package_show_path(package: @model.notifiable.commentable,
                                                                     project: @model.notifiable.commentable.project,
                                                                     notification_id: @model.id,
                                                                     anchor: 'comments-list') }
    else
      {}
    end
  end

  def truncate_to_first_new_line(text)
    first_new_line_index = text.index("\n")
    truncation_index = !first_new_line_index.nil? && first_new_line_index < TRUNCATION_LENGTH ? first_new_line_index + TRUNCATION_ELLIPSIS_LENGTH : TRUNCATION_LENGTH
    text.truncate(truncation_index)
  end

  def excerpt
    text =  case @model.notifiable_type
            when 'BsRequest'
              @model.notifiable.description
            when 'Comment'
              render_without_markdown(@model.notifiable.body)
            else
              ''
            end
    truncate_to_first_new_line(text.to_s)
  end

  def commenters
    commentable = @model.notifiable.commentable
    commentable.comments.where('updated_at >= ?', @model.unread_date).map(&:user).uniq
  end

  def avatar_objects
    if @model.notifiable_type == 'Comment'
      commenters
    else
      @model.notifiable.reviews.in_state_new.map(&:reviewed_by) + User.where(login: @model.notifiable.creator)
    end
  end

  def source
    bs_request = @model.notifiable_type == 'BsRequest' ? @model.notifiable : @model.notifiable.commentable
    bs_request_action = bs_request.bs_request_actions.first
    return nil if bs_request.bs_request_actions.size > 1

    [bs_request_action.source_project, bs_request_action.source_package].compact.join(' / ')
  end

  def target
    bs_request = @model.notifiable_type == 'BsRequest' ? @model.notifiable : @model.notifiable.commentable
    bs_request_action = bs_request.bs_request_actions.first
    return "#{bs_request_action.target_project}" if bs_request.bs_request_actions.size > 1

    [bs_request_action.target_project, bs_request_action.target_package].compact.join(' / ')
  end

  private

  def render_without_markdown(content)
    # Initializes a Markdown parser, if needed
    @remove_markdown_parser ||= Redcarpet::Markdown.new(Redcarpet::Render::StripDown)
    ActionController::Base.helpers.sanitize(@remove_markdown_parser.render(content.to_s))
  end

  # Returns strings like "Add Role", "Submit", etc.
  def type_of_action(bs_request)
    return 'Multiple Actions\'' if bs_request.bs_request_actions.size > 1

    bs_request.bs_request_actions.first.type.titleize
  end
end
