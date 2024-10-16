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
    line_index = @comment.diff_ref.match(/diff_[0-9]+_n([0-9]+)/).captures.first
    ((line_index.to_i - 4).clamp(0..)..(line_index.to_i - 1))
  end

  def outdated?
    return false if @comment.diff_ref.blank?
    return false if @comment.source_rev.nil? && @comment.target_rev.nil?

    target_package = Package.find_by_project_and_name(@commentable.target_project, @commentable.target_package)
    return true unless target_package.dir_hash['srcmd5'] == @comment.target_rev

    source_package = Package.find_by_project_and_name(@commentable.source_project, @commentable.source_package)
    return true unless source_package.dir_hash({ rev: @commentable.source_rev }.compact)['srcmd5'] == @comment.source_rev

    false
  end
end
