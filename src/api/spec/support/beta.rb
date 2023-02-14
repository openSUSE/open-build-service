RSpec.configure do |config|
  config.before(:example, beta: true) do
    # Add here the feature flags you want to enable on your beta features' tests
    # Example: Flipper.enable(:foo)
  end
end
