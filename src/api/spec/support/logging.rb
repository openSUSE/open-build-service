# frozen_string_literal: true
RSpec.configure do |config|
  config.around do |example|
    Rails.logger.debug("\n\n\n===== #{example.full_description} =====\n\n")
    example.run
  end
end
