class NotificationExcerptComponent < ApplicationComponent
  TRUNCATION_LENGTH = 100
  TRUNCATION_ELLIPSIS_LENGTH = 3 # `...` is the default ellipsis for String#truncate

  def initialize(notification)
    super

    @notification = notification
  end

  def call
    text = case @notification.notifiable_type
           when 'BsRequest'
             @notification.notifiable.description.to_s # description can be nil
           when 'Comment'
             helpers.render_without_markdown(@notification.notifiable.body)
           else
             ''
           end

    tag.p(truncate_to_first_new_line(text), class: ['mt-3', 'mb-0'])
  end

  private

  def truncate_to_first_new_line(text)
    first_new_line_index = text.index("\n")
    truncation_index = !first_new_line_index.nil? && first_new_line_index < TRUNCATION_LENGTH ? first_new_line_index + TRUNCATION_ELLIPSIS_LENGTH : TRUNCATION_LENGTH
    text.truncate(truncation_index)
  end
end
