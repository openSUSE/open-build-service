RSpec.configure do |config|
  config.include Devise::Test::IntegrationHelpers, type: :controller
  config.include Devise::Test::IntegrationHelpers, type: :job
  config.include Devise::Test::IntegrationHelpers, type: :mailer
  config.include Devise::Test::IntegrationHelpers, type: :model
end
