# frozen_string_literal: true
class FullTextIndexJob < ApplicationJob
  queue_as :quick

  def perform
    return unless Rails.env.production?

    # Ensure the connection
    ApplicationRecord.connection_pool.with_connection do |_|
      # Use the RakeInterface provided by ThinkingSphinx
      interface = ThinkingSphinx::RakeInterface.new

      interface.sql.index
    end
  end
end
