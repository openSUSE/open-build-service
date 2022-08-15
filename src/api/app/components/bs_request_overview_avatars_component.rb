class BsRequestOverviewAvatarsComponent < ApplicationComponent
  MAXIMUM_DISPLAYED_AVATARS = 2

  def initialize(review)
    super

    @review = review
  end

  private

  def avatar_objects
    @avatar_objects ||= if @review.for_user?
                          [@review.user]
                        elsif @review.for_group?
                          [@review.group.users, @review.group].flatten
                        elsif @review.for_package?
                          @review.package.project.users
                        elsif @review.for_project?
                          @review.project.users
                        end
  end

  def avatars_to_display
    avatar_objects.first(MAXIMUM_DISPLAYED_AVATARS).reverse
  end

  def number_of_hidden_avatars
    [0, avatar_objects.size - MAXIMUM_DISPLAYED_AVATARS].max
  end
end
