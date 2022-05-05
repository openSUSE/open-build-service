RSpec.configure do |config|
  config.before(:example, beta: true) do
    Flipper.enable(:trigger_workflow)
  end
end
