# This component renders a comment thread
#
# It is used in the beta view of the request show page, under the Overview tab,
# merged with the BsRequestHistoryElementComponent.
class BsRequestCommentComponent < ApplicationComponent
  attr_reader :comment, :commentable, :level, :diff

  def initialize(comment:, commentable:, level:, diff: nil, nodecoration: false)
    super

    @comment = comment
    @commentable = commentable
    @level = level
    @diff = diff
    @nodecoration = nodecoration
  end

  def range
    line_index = @comment.diff_ref.match(/diff_[0-9]+_n([0-9]+)/).captures.first
    ((line_index.to_i - 4).clamp(0..)..(line_index.to_i - 1))
  end

  def link_to_comment(comment)
    helpers.link_to(helpers.commentable_path(comment: comment),
                    title: l(comment.created_at.utc),
                    name: "comment-#{comment.id}") do
      render TimeComponent.new(time: comment.created_at)
    end
  end
end
