class NotificationAvatarsComponent < ApplicationComponent
  MAXIMUM_DISPLAYED_AVATARS = 6

  def initialize(notification)
    super

    @notification = notification
  end

  private

  def avatar_objects
    @notification.decorator.avatar_objects
  end

  def avatars_to_display
    avatar_objects.first(MAXIMUM_DISPLAYED_AVATARS).reverse
  end

  def number_of_hidden_users
    [0, avatar_objects.size - MAXIMUM_DISPLAYED_AVATARS].max
  end

  def commenters
    comments = @notification.notifiable.commentable.comments
    comments.select { |comment| comment.updated_at >= @notification.unread_date }.map(&:user).uniq
  end

  def package_title(package)
    "Package #{package.project}/#{package}"
  end

  def project_title(project)
    "Project #{project}"
  end
end
