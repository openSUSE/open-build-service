class FullTextIndexJob < ApplicationJob
  queue_as :quick

  def perform
    return unless Rails.env.production?

    # Ensure the connection
    ApplicationRecord.connection_pool.with_connection do |_|
      # Use the RakeInterface provided by ThinkingSphinx
      interface = ThinkingSphinx::RakeInterface.new

      begin
        interface.daemon.start
      rescue ThinkingSphinx::SphinxAlreadyRunning, RuntimeError => e
        # Most likely, this means that searchd is already running.
        # Nothing to worry about
        Rails.logger.info "Handled exception: #{e.message}"
      end

      interface.sql.index
    end
  end
end
