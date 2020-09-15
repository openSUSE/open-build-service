require "#{Rails.root}/lib/obsapi/markdown_renderer"

module OBSApi
  class RougeRenderer < OBSApi::MarkdownRenderer
    # This module includes a block_code definition
    # That overrides the Coderay one from the parent class
    include Rouge::Plugins::Redcarpet
  end
end