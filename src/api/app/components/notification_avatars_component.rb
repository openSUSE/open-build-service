class NotificationAvatarsComponent < ApplicationComponent
  MAXIMUM_DISPLAYED_AVATARS = 6

  def initialize(notification)
    super

    @notification = notification
  end

  private

  def avatar_objects
    @avatar_objects ||= if @notification.notifiable_type == 'Comment'
                          commenters
                        else
                          @notification.notifiable.reviews.in_state_new.map(&:reviewed_by) + User.where(login: @notification.notifiable.creator)
                        end
  end

  def avatars_to_display
    avatar_objects.first(MAXIMUM_DISPLAYED_AVATARS).reverse
  end

  def number_of_hidden_users
    [0, avatar_objects.size - MAXIMUM_DISPLAYED_AVATARS].max
  end

  def commenters
    commentable = @notification.notifiable.commentable
    commentable.comments.where('updated_at >= ?', @notification.unread_date).map(&:user).uniq
  end

  def package_title(package)
    "Package #{package.project}/#{package}"
  end

  def project_title(project)
    "Project #{project}"
  end
end
