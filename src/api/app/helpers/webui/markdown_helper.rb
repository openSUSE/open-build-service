require 'obsapi/markdown_renderer'
require 'redcarpet/render_strip'

module Webui::MarkdownHelper
  def render_as_markdown(content)
    # Initializes a Markdown parser, if needed
    @md_parser ||= Redcarpet::Markdown.new(OBSApi::MarkdownRenderer.new(no_styles: true),
                                           autolink: true,
                                           no_intra_emphasis: true,
                                           fenced_code_blocks: true)
    ActionController::Base.helpers.sanitize(@md_parser.render(content.dup.to_s), scrubber: Loofah::Scrubbers::NoFollow.new)
  end

  def render_without_markdown(content)
    @remove_markdown_parser ||= Redcarpet::Markdown.new(Redcarpet::Render::StripDown)
    ActionController::Base.helpers.sanitize(@remove_markdown_parser.render(content.to_s))
  end
end
