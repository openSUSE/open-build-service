# frozen_string_literal: true

require 'obsapi/markdown_renderer'

module CommentHelper
  def comment_body(comment)
    # Initializes a Markdown parser, if needed
    @md_parser ||= Redcarpet::Markdown.new(OBSApi::MarkdownRenderer.new(no_styles: true),
                                           autolink: true,
                                           no_intra_emphasis: true,
                                           fenced_code_blocks: true, disable_indented_code_blocks: true)
    @md_parser.render(comment.to_s).html_safe
  end
end
