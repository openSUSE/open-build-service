# This component renders a comment thread
#
# It is used in the beta view of the request show page, under the Overview tab,
# merged with the BsRequestHistoryElementComponent.
class BsRequestCommentComponent < ApplicationComponent
  attr_reader :comment, :commentable, :level, :diff, :show_username

  def initialize(comment:, commentable:, level:, diff: nil, show_username: true)
    super

    @comment = comment
    @commentable = commentable
    @level = level
    @diff = diff
    @show_username = show_username
  end

  def range
    line_index = @comment.diff_line_number
    ((line_index - 4).clamp(0..)..(line_index - 1))
  end
end
