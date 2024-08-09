module Webui::NotificationHelper
  TRUNCATION_LENGTH = 100
  TRUNCATION_ELLIPSIS_LENGTH = 3 # `...` is the default ellipsis for String#truncate

  MAXIMUM_DISPLAYED_AVATARS = 6

  def truncate_to_first_new_line(text)
    return '' if text.blank?

    first_new_line_index = text.index("\n")
    truncation_index = !first_new_line_index.nil? && first_new_line_index < TRUNCATION_LENGTH ? first_new_line_index + TRUNCATION_ELLIPSIS_LENGTH : TRUNCATION_LENGTH
    text.truncate(truncation_index)
  end

  def avatars(avatar_object)
    case avatar_object.class.name
    when 'User', 'Group'
      render(AvatarComponent.new(name: avatar_object.name, email: avatar_object.email, size: 23, shape: :circle))
    when 'Package'
      tag.span(class: 'fa fa-archive text-warning rounded-circle bg-body-secondary border simulated-avatar', title: "Package #{avatar_object.project}/#{avatar_object}")
    when 'Project'
      tag.span(class: 'fa fa-cubes text-secondary rounded-circle bg-body-secondary border simulated-avatar', title: "Project #{avatar_object}")
    end
  end

  def hidden_avatars(notification)
    return unless number_of_hidden_avatars(notification.avatar_objects).positive?

    concat(
      tag.li(class: 'list-inline-item') do
        tag.span("#{number_of_hidden_avatars(notification.avatar_objects)}",
                 class: 'rounded-circle bg-body-secondary border avatars-counter',
                 title: "#{number_of_hidden_avatars(notification.avatar_objects)} more users involved")
      end
    )
  end

  def avatars_to_display(avatar_objects)
    avatar_objects.first(MAXIMUM_DISPLAYED_AVATARS).reverse
  end

  private

  def number_of_hidden_avatars(avatar_objects)
    [0, avatar_objects.size - MAXIMUM_DISPLAYED_AVATARS].max
  end
end
