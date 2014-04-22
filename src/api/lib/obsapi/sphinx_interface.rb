# First of all, make sure that our Package model is properly
# autoloaded before starting (to avoid problems in clockwork)
require 'package'

module OBSApi
  class SphinxInterface

    @starting = false

    def self.restart
      @starting = true
      result = false

      ActiveRecord::Base.connection_pool.with_connection do |sql|
        interface = ThinkingSphinx::RakeInterface.new
        interface.stop
        interface.index
        result = interface.start
      end

      @starting = false
      result
    end

    def self.index
      if @starting
        Rails.logger.info "Skipping indexing since Sphinx is restarting"
        true
      else
        ThinkingSphinx::RakeInterface.new.index
      end
    end
  end
end
