# frozen_string_literal: true
module OBSApi
  class TestSphinx
    @started = false

    def self.ensure
      return true unless Rails.env.test?
      if @started
        Rails.logger.debug 'Skipping Sphinx indexing'
        true
      else
        Rails.logger.debug 'Indexing and starting Sphinx'
        # Ensure sphinx directories exist for the test environment
        ThinkingSphinx::Test.init
        ThinkingSphinx::Test.start
        # Index
        ThinkingSphinx::Test.index
        # Configure and start Sphinx
        ThinkingSphinx::Test.start_with_autostop
        Rails.logger.debug 'Sphinx is up and running'
        @started = true
      end
    end
  end
end
