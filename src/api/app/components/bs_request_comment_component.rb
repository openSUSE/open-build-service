# This component renders a comment thread
#
# It is used in the beta view of the request show page, under the Overview tab,
# merged with the BsRequestHistoryElementComponent.
class BsRequestCommentComponent < ApplicationComponent
  attr_reader :comment, :commentable, :level

  def initialize(comment:, commentable:, level:)
    super

    @comment = comment
    @commentable = commentable
    @level = level
  end
end
