module RuboCop
  module Cop
    module ViewComponent
      class ClassName < RuboCop::Cop::Base
        def on_class(node)
          return if node.loc.name.source.end_with?('Component')

          add_offense(node.loc.name, message: 'View component classes must end with `Component`')
        end
      end
    end
  end
end
