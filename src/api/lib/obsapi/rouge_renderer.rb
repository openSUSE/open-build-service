require "#{Rails.root}/lib/obsapi/markdown_renderer"

module OBSApi
  class RougeRenderer < OBSApi::MarkdownRenderer
    include Rouge::Plugins::Redcarpet
  end
end