module RuboCop
  module Cop
    module ViewComponent
      class AvoidGlobalState < RuboCop::Cop::Base
        # https://docs.rubocop.org/rubocop-ast/node_pattern.html#using-node-matcher-macros
        def_node_search :params, <<~PATTERN
          (send (send nil? :params) :[] (:sym ...)) # nil? -> https://docs.rubocop.org/rubocop-ast/node_pattern.html#nil-or-nil
        PATTERN

        MSG = 'View components should not rely on global state by using params. Instead, pass the required data to the initialize method.'.freeze

        # Add an offense for every line using params
        #
        # @param [RuboCop::AST::ClassNode]
        def on_class(node)
          return unless view_component?(node)

          params(node).each do |param|
            add_offense(param)
          end
        end

        private

        # We can safely assume a class node is a view component if its name ends with Component
        def view_component?(node)
          node.identifier.short_name.to_s.end_with?('Component')
        end
      end
    end
  end
end
