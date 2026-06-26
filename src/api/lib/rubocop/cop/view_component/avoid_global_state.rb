module RuboCop
  module Cop
    module ViewComponent
      class AvoidGlobalState < RuboCop::Cop::Base
        # General documentation on `def_node_matcher`
        # https://docs.rubocop.org/rubocop-ast/1.12/node_pattern.html#using-node-matcher-macros
        #
        # Documentation for node types (There is a `on_*` method for every Node type, so like `on_send`)
        # https://docs.rubocop.org/rubocop-ast/1.12/node_types.html#node-types
        #
        # Documentation for the predicate nil?
        # https://docs.rubocop.org/rubocop-ast/1.12/node_pattern.html#nil-or-nil
        #
        # Documentation for ... to match several subsequent nodes
        # https://docs.rubocop.org/rubocop-ast/1.12/node_pattern.html#for-several-subsequent-nodes
        def_node_matcher :params?, <<~PATTERN
          (send (send nil? :params) :[] (:sym ...))
        PATTERN

        def_node_matcher :user_model?, <<~PATTERN
          (send (const nil? :User) ...)
        PATTERN

        MESSAGE = 'View components should not rely on global state by %<content>s. Instead, pass the required data to the initialize method.'.freeze

        # Add an offense for using params or class methods from the User model
        #
        # @param [RuboCop::AST::ClassNode]
        def on_send(node)
          case
          when params?(node)
            # node.source is the code which the AST pattern matched, so as an example `params[:abc]`
            add_offense(node, message: format(MESSAGE, content: "using #{node.source}"))
          when user_model?(node)
            # node.source is the code which the AST pattern matched, so as an example `User.session`
            add_offense(node, message: format(MESSAGE, content: "calling #{node.source}"))
          end
        end
      end
    end
  end
end
