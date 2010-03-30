# https://rails.lighthouseapp.com/projects/8994/tickets/2860

module ActiveSupport
  module Cache
    class MemoryStore < Store

      def write(name, value, options = nil)
        super
        @data[name] = (value.duplicable? ? value.dup : value).freeze
      end

    end
  end
end