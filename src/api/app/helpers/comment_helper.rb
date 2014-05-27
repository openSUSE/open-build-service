require 'obsapi/markdown_renderer'

module CommentHelper
  def comment_body(comment)
    # Initializes a Markdown parser, if needed
    @md_parser ||= Redcarpet::Markdown.new(OBSApi::MarkdownRenderer, autolink: true)
    raw_comment = comment.is_a?(String) ? comment : comment[:body]
    @md_parser.render(raw_comment).html_safe
  end
end
