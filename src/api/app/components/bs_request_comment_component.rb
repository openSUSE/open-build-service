# This component renders a comment thread
#
# It is used in the beta view of the request show page, under the Overview tab,
# merged with the BsRequestHistoryElementComponent.
class BsRequestCommentComponent < ApplicationComponent
  attr_reader :comment, :commentable, :level, :diff

  def initialize(comment:, commentable:, level:, diff: nil)
    super

    @comment = comment
    @commentable = commentable
    @level = level
    @diff = diff
  end
end
