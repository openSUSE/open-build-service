module ActiveRecord
  module Scoping
    class ScopeRegistry # :nodoc:

      def self.value_for(scope_type, variable_name)
        instance.value_for(scope_type, variable_name)
      end

      def self.set_value_for(scope_type, variable_name, value)
        instance.set_value_for(scope_type, variable_name, value)
      end

    end
  end
end
