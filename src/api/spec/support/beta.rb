RSpec.configure do |config|
  config.before(:example, beta: true) do
    Flipper.enable(:notifications_redesign)
    Flipper.enable(:user_profile_redesign)
    Flipper.enable(:trigger_workflow)
  end
end
