# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  def render_diff(content, file_index:)
    sanitize(CodeRay.scan(content, :diff).div(css: :class, line_numbers: :inline, line_number_anchors: "diff_#{file_index}_n"))
  end

  # Render diff with inline CSS for HTML emails (email clients don't support external stylesheets)
  def render_email_diff(content)
    return '' if content.blank?

    # Use CodeRay with inline styles for email compatibility
    sanitize(CodeRay.scan(content, :diff).div(css: :style, line_numbers: false))
  end
end
