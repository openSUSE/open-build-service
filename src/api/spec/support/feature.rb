RSpec.configure do |config|
  config.after do
    # reset to default
    Feature.use_beta_features(false)
  end
end
