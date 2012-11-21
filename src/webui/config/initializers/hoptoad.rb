HoptoadNotifier.configure do |config|
  # Change this to some sensible data for your errbit instance
  config.api_key = 'YOUR_ERRBIT_API_KEY'
  config.host    = 'YOUR_ERRBIT_HOST'
  # Remove production from this option to enable the notification
  config.development_environments = "production development test"
  # We don't want to know about timeout errors, the api will tell us the real reason 
  config.ignore << Timeout::Error
  # The api sometimes sends responses without a proper "Status:..." line (when it restarts?)
  config.ignore << Net::HTTPBadResponse 
end
