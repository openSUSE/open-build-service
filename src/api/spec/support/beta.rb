RSpec.configure do |config|
  config.before(:example, beta: true) do
    Flipper.enable(:notifications_redesign)
  end
end
