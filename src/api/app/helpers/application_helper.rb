# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  def render_diff(content)
    sanitize(CodeRay.scan(content, :diff).div(line_numbers: :inline, css: :class))
  end
end
