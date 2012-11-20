HoptoadNotifier.configure do |config|
  # Change this to some sensible data for your errbit instance
  config.api_key = 'YOUR_ERRBIT_API_KEY'
  config.host    = 'YOUR_ERRBIT_HOST'
  # Remove production from this option to enable the notification
  config.development_environments = "production development test"
end
