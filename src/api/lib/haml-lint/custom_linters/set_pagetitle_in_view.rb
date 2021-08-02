# This custom linter for haml-lint will report an offense if @pagetitle is not set in a Haml view. Partials aren't ignored by this linter.
module HamlLint
  class Linter::SetPagetitleInView < Linter
    include LinterRegistry

    # Report an offense if the instance variable @pagetitle is not set in a Haml view. Partials aren't ignored by this linter.
    #
    # @param [HamlLint::Tree::RootNode] the root of a syntax tree
    def visit_root(root_node)
      # Do not proceed if the view isn't under the directory 'app/views/webui/' and doesn't end with the extension '.html.haml'
      return unless root_node.file.match?(%r{^app/views/webui/.*\.html\.haml$})

      # Do not proceed if the view is a partial (only partials start with an underscore)
      return if File.basename(root_node.file).start_with?('_')

      # Do not proceed if the view defines the instance variable @pagetitle, then this rule is respected. Yay!
      return if instance_variable_pagetitle_is_defined?(document)

      record_lint(root_node, 'Set the instance variable @pagetitle to have a page title when the view is rendered.')
    end

    private

    # @param [HamlLint::Document] a parsed Haml document and its associated metadata
    def instance_variable_pagetitle_is_defined?(document)
      parsed_ruby = HamlLint::RubyParser.new.parse(HamlLint::RubyExtractor.new.extract(document).source)

      parsed_ruby.each_descendant.find do |descendant_node|
        # Details on Abstract Syntax Tree from Parser gem: https://github.com/whitequark/parser/blob/11c7644365fe554217bb4670a4cbc905ab8504cd/doc/AST_FORMAT.md#to-instance-variable
        # Are we assigning an instance variable? Is it called @pagetitle?
        descendant_node.ivasgn_type? && descendant_node.children.first == :@pagetitle
      end
    end
  end
end
