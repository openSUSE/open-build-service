RSpec.configure do |config|
  config.before do |example|
    Rails.logger.debug("\n\n\n===== #{example.full_description} =====\n\n")
  end
end
