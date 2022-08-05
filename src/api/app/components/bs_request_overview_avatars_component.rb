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
                          [@review.group.users.first(MAXIMUM_DISPLAYED_AVATARS), @review.group].flatten
                        elsif @review.for_package?
                          @review.package.project.users.first(MAXIMUM_DISPLAYED_AVATARS)
                        elsif @review.for_project?
                          @review.project.users.first(MAXIMUM_DISPLAYED_AVATARS)
                        end
  end
end
