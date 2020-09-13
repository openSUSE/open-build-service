module Webui::RougeHelper
  require 'redcarpet'
  require 'rouge'
  require 'rouge/plugins/redcarpet'
  require 'obsapi/markdown_renderer'
  require 'obsapi/rouge_renderer'

  def rouge_markdown(text)
    render_options = {
        filter_html: true,
        hard_wrap: true,
        link_attributes: {rel: 'nofollow'},
        no_styles: true
    }
    renderer = OBSApi::RougeRenderer.new(render_options)

    extensions = {
        autolink: true,
        no_intra_emphasis: true,
        fenced_code_blocks: true,
        disable_indented_code_blocks: true,
    }

    markdown = Redcarpet::Markdown.new(renderer, extensions)
    markdown.render(text).html_safe
  end
end
