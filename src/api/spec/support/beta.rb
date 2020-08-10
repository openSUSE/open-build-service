RSpec.configure do |config|
  config.before(:example, beta: true) do
    Flipper.enable(:responsive_ux)
    Flipper.enable(:notifications_redesign)
  end
end
