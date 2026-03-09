# This component renders a comment thread
#
# It is used in the beta view of the request show page, under the Overview tab,
# merged with the BsRequestHistoryElementComponent.
class BsRequestCommentComponent < ApplicationComponent
  attr_reader :comment, :commentable, :level, :diff, :show_username

  def initialize(comment:, commentable:, level:, diff: nil, show_username: true)
    super()

    @comment = comment
    @commentable = commentable
    @level = level
    @diff = diff
    @show_username = show_username
  end

  def range
    line_index = @comment.diff_line_number - 1

    start = if @diff['old'].present?
              find_index_of_previous_line
            else # for new files just show the commented line
              line_index
            end
    start..line_index
  end

  # rubocop:disable Metrics/CyclomaticComplexity
  def find_index_of_previous_line
    context_lines = 4
    # If file has been removed then just show the 4 lines to provide context
    return @comment.diff_line_number - context_lines if @diff['state'] == 'deleted'

    lines = @diff.dig('diff', '_content').split("\n", -1)

    current_line_index = @comment.diff_line_number - 1
    search_start = current_line_index - 1

    lookup_until = search_start > context_lines ? search_start - context_lines : 0
    search_start.downto(lookup_until) do |i|
      line = lines[i].to_s.strip
      next if line.empty? || line.start_with?('+') || line.start_with?('\\') || line.include?('No newline at end of file')

      return i if line.start_with?('-')
    end
    current_line_index
  end
  # rubocop:enable Metrics/CyclomaticComplexity
end
