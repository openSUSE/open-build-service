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
                          group_avatar_objects
                        elsif @review.for_package?
                          package_avatar_objects
                        elsif @review.for_project?
                          project_avatar_objects
                        end
  end

  def group_avatar_objects
    [@review.group.users, @review.group].flatten
  end

  def project_avatar_objects
    [@review.project&.users].flatten.compact
  end

  def avatars_to_display
    avatar_objects.first(MAXIMUM_DISPLAYED_AVATARS).reverse
  end

  def number_of_hidden_avatars
    [0, avatar_objects.size - MAXIMUM_DISPLAYED_AVATARS].max
  end

  def package_avatar_objects
    relationships = @review.package&.relationships.for_maintainer_and_reviewer_roles.includes(:user, :group)
    reviewers = relationships.map { |relation | relation.user_id.present? ? relation.user : relation.group.users }.flatten.uniq!
    # if the package explicitly has maintainer or reviewer assigned return them, otherwise
    # check the related project for responsible user
    return reviewers if reviewers.present?

    relationships = @review.package&.project&.relationships.for_maintainer_and_reviewer_roles.includes(:user, :group)
    relationships.map { |relation | relation.user_id.present? ? relation.user : relation.group.users }.flatten.uniq!
  end
end
