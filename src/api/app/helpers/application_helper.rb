# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  def render_diff(content, file_index:, action_id:)
    sanitize(CodeRay.scan(content, :diff).div(css: :class, line_numbers: :inline, line_number_anchors: "diff_#{action_id}_#{file_index}_n"))
  end
end
