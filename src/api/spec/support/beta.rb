RSpec.configure do |config|
  config.before(:example, beta: true) do
    Flipper.enable(:responsive_ux)
  end
end
