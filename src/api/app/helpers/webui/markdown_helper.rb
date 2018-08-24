require 'obsapi/markdown_renderer'

module Webui::MarkdownHelper
  def render_as_markdown(content)
    # Initializes a Markdown parser, if needed
    @md_parser ||= Redcarpet::Markdown.new(OBSApi::MarkdownRenderer.new(no_styles: true),
                                           autolink: true,
                                           no_intra_emphasis: true,
                                           fenced_code_blocks: true, disable_indented_code_blocks: true)
    # rubocop:disable Rails/OutputSafety
    @md_parser.render(content.to_s).html_safe
    # rubocop:enable Rails/OutputSafety
  end
end
