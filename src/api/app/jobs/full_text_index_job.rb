class ThinkingSphinx::GuardfileExistsError < StandardError
  def message
    "Guardfile #{File.join(ThinkingSphinx::Configuration.instance.indices_location, 'ts---all.tmp')} exists already"
  end
end

class FullTextIndexJob < ApplicationJob
  queue_as :quick

  def perform
    return unless Rails.env.production?
    # From time to time, ThinkingSphinx aborts keeping the guard file there
    # making impossible to rebuild the index. We want to have the exception on errbit
    raise ThinkingSphinx::GuardfileExistsError if ThinkingSphinx::Guard::File.new('--all').locked?
    # Ensure the connection
    ApplicationRecord.connection_pool.with_connection do |_|
      # Use the RakeInterface provided by ThinkingSphinx
      interface = ThinkingSphinx::RakeInterface.new

      interface.sql.index
    end
  end
end
