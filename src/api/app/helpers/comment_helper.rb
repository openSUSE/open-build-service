require 'obsapi/markdown_renderer'

module CommentHelper
  def comment_body(comment)
    # Initializes a Markdown parser, if needed
    @md_parser ||= Redcarpet::Markdown.new(OBSApi::MarkdownRenderer, autolink: true)
    @md_parser.render(comment.to_s).html_safe
  end
end
